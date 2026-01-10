import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show Platform;
import '../res/utils/photo_url_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _deviceTokenKey = 'device_login_token';

  // Phone verification state - stored for auto-retrieval timeout handling
  // ignore: unused_field
  String? _verificationId;
  int? _resendToken;

  User? get currentUser => _auth.currentUser;

  /// Get auth state changes stream - properly broadcasts to all listeners
  Stream<User?> get authStateChanges {
    // Use userChanges() which is more reliable for logout detection
    // It emits on both auth state changes AND ID token changes
    return _auth.userChanges();
  }

  /// Direct access to Firebase auth for emergency sign-out
  FirebaseAuth get firebaseAuth => _auth;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate and save device token FIRST (needed for logoutFromOtherDevices)
      String? deviceToken;
      if (result.user != null) {
        deviceToken = _generateDeviceToken();
        await _saveLocalDeviceToken(deviceToken);
        print(
          '[AuthService] Device token generated & saved: ${deviceToken.substring(0, 8)}...',
        );
      }

      // Check for existing session on another device
      if (result.user != null) {
        final sessionCheck = await _checkExistingSession(result.user!.uid);
        if (sessionCheck['exists'] == true) {
          print(
            '[AuthService] Existing session detected, throwing ALREADY_LOGGED_IN',
          );
          // IMPORTANT: Save the UID BEFORE signing out Device B!
          final userIdToPass = result.user!.uid;

          // IMPORTANT: Sign out Device B immediately so it stays on login screen
          // Device B's device token is saved in SharedPreferences, that's enough for logoutFromOtherDevices
          await _auth.signOut();
          print('[AuthService] Device B signed out to keep it on login screen - token saved in SharedPreferences');

          final deviceInfo =
              sessionCheck['deviceInfo'] as Map<String, dynamic>?;
          throw Exception(
            'ALREADY_LOGGED_IN:${deviceInfo?['deviceName'] ?? 'Another Device'}:$userIdToPass',
          );
        }
      }

      // Only save to Firestore AFTER session check passes (no existing session)
      if (result.user != null && deviceToken != null) {
        // Update user profile
        await _updateUserProfileOnLoginAsync(result.user!, email);
        await _saveDeviceSession(result.user!.uid, deviceToken);

        // Initialize forceLogout flag
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .update({'forceLogout': false})
            .catchError((e) {
              // Ignore errors - this is just initialization
            });
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign in.';
      }
      throw Exception(message);
    }
  }

  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? accountType,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create initial Firestore profile for email signup
      if (result.user != null) {
        final user = result.user!;

        // Determine account type and status
        final accType = _parseAccountType(accountType);
        final needsVerification = accType != 'personal';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': email.split('@')[0], // Use email prefix as initial name
          'email': user.email ?? email,
          'profileImageUrl': null,
          'photoUrl': null, // Keep for backward compatibility
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'discoveryModeEnabled':
              true, // Enable Live Connect discovery by default
          'interests': [], // Initialize empty interests
          'connections': [], // Initialize empty connections
          'connectionCount': 0,
          'blockedUsers': [], // Initialize empty blocked users
          'connectionTypes': [], // Initialize empty connection types
          'activities': [], // Initialize empty activities
          // Account type fields
          'accountType': accType,
          'accountStatus': needsVerification ? 'pendingVerification' : 'active',
          'verification': {'status': needsVerification ? 'pending' : 'none'},
        }, SetOptions(merge: true));
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign up.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<User?> signInWithGoogle({String? accountType}) async {
    try {
      // Check if already signed in
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // Error signing out previous session
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      // Generate and save device token FIRST (needed for logoutFromOtherDevices)
      String? deviceToken;
      if (result.user != null) {
        deviceToken = _generateDeviceToken();
        await _saveLocalDeviceToken(deviceToken);
      }

      // Check for existing session on another device
      if (result.user != null) {
        final sessionCheck = await _checkExistingSession(result.user!.uid);
        if (sessionCheck['exists'] == true) {
          // IMPORTANT: Save UID BEFORE signing out!
          final userIdToPass = result.user!.uid;

          // Sign out Device B immediately so it stays on login screen
          // Device B's device token is saved in SharedPreferences, that's enough for logoutFromOtherDevices
          await _auth.signOut();
          print('[AuthService] Device B signed out to keep it on login screen - token saved in SharedPreferences');

          final deviceInfo =
              sessionCheck['deviceInfo'] as Map<String, dynamic>?;
          throw Exception(
            'ALREADY_LOGGED_IN:${deviceInfo?['deviceName'] ?? 'Another Device'}:$userIdToPass',
          );
        }
      }

      // Only proceed with Firestore updates AFTER session check passes
      if (result.user != null && deviceToken != null) {
        final user = result.user!;

        // Fix Google photo URL to get higher quality version
        String? photoUrl = user.photoURL ?? googleUser.photoUrl;
        photoUrl = PhotoUrlHelper.getHighQualityGooglePhoto(photoUrl);

        // Check if this is a new user or existing user
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final isNewUser = !doc.exists;

        // Determine account type and status for new users
        final accType = _parseAccountType(accountType);
        final needsVerification = accType != 'personal';

        // Get email and normalize it
        final userEmail = (user.email ?? googleUser.email).toLowerCase().trim();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? googleUser.displayName ?? '',
          'email': userEmail, // Store lowercase email for consistent matching
          'profileImageUrl': photoUrl,
          'photoUrl': photoUrl, // Keep for backward compatibility
          'lastSeen': FieldValue.serverTimestamp(),
          if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          // Only set these for new users to avoid overwriting existing values
          if (isNewUser) ...{
            'discoveryModeEnabled':
                true, // Enable Live Connect discovery by default
            'interests': [], // Initialize empty interests
            'connections': [], // Initialize empty connections
            'connectionCount': 0,
            'blockedUsers': [], // Initialize empty blocked users
            'connectionTypes': [], // Initialize empty connection types
            'activities': [], // Initialize empty activities
            // Account type fields
            'accountType': accType,
            'accountStatus': needsVerification
                ? 'pendingVerification'
                : 'active',
            'verification': {'status': needsVerification ? 'pending' : 'none'},
          },
        }, SetOptions(merge: true));

        // Also update the auth profile with fixed URL
        if (photoUrl != null && photoUrl != user.photoURL) {
          try {
            await user.updatePhotoURL(photoUrl);
          } catch (e) {
            // Could not update auth photo URL
          }
        }

        // Save device session with the token we generated earlier
        await _saveDeviceSession(user.uid, deviceToken);

        // Initialize forceLogout flag
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'forceLogout': false})
            .catchError((e) {
              // Ignore errors - this is just initialization
            });
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'An account already exists with the same email address.';
          break;
        case 'invalid-credential':
          message = 'The credential is invalid or has expired.';
          break;
        case 'operation-not-allowed':
          message = 'Google sign-in is not enabled.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = e.message ?? 'An error occurred during Google sign-in.';
      }
      throw Exception(message);
    }
  }

  Future<void> signOut() async {
    try {
      // Update user status and clear device token
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
                'activeDeviceToken': FieldValue.delete(),
              });
        } catch (e) {
          // Continue with logout even if Firestore update fails
        }
      }

      // Clear local device token
      await _clearLocalDeviceToken();

      // Sign out from Firebase and Google
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut().catchError((e) => null),
      ]);
    } catch (e) {
      // Even if there's an error, try to force sign out from Firebase
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  /// Send OTP to phone number
  /// Returns a Map with 'success' and optionally 'error' message
  Future<Map<String, dynamic>> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'Invalid phone number format. Please use +91XXXXXXXXXX';
              break;
            case 'too-many-requests':
              message = 'Too many requests. Please try again later.';
              break;
            case 'quota-exceeded':
              message = 'SMS quota exceeded. Please try again tomorrow.';
              break;
            case 'app-not-authorized':
              message =
                  'App not authorized. Please check Firebase configuration.';
              break;
            case 'captcha-check-failed':
              message = 'reCAPTCHA verification failed. Please try again.';
              break;
            case 'missing-client-identifier':
              message = 'Missing app identifier. Please reinstall the app.';
              break;
            default:
              message =
                  e.message ?? 'Phone verification failed. Please try again.';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
      return {'success': true};
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify OTP and sign in
  Future<User?> verifyPhoneOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      // Generate and save device token FIRST (needed for logoutFromOtherDevices)
      String? deviceToken;
      if (result.user != null) {
        deviceToken = _generateDeviceToken();
        await _saveLocalDeviceToken(deviceToken);
      }

      // Check for existing session on another device
      if (result.user != null) {
        final sessionCheck = await _checkExistingSession(result.user!.uid);
        if (sessionCheck['exists'] == true) {
          // IMPORTANT: Save UID BEFORE signing out!
          final userIdToPass = result.user!.uid;

          // Sign out Device B immediately so it stays on login screen
          // Device B's device token is saved in SharedPreferences, that's enough for logoutFromOtherDevices
          await _auth.signOut();
          print('[AuthService] Device B signed out to keep it on login screen - token saved in SharedPreferences');

          final deviceInfo =
              sessionCheck['deviceInfo'] as Map<String, dynamic>?;
          throw Exception(
            'ALREADY_LOGGED_IN:${deviceInfo?['deviceName'] ?? 'Another Device'}:$userIdToPass',
          );
        }
      }

      // Only proceed with Firestore updates AFTER session check passes
      if (result.user != null && deviceToken != null) {
        // Update user profile
        await _updateUserProfileOnPhoneLoginAsync(result.user!);
        await _saveDeviceSession(result.user!.uid, deviceToken);

        // Initialize forceLogout flag
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .update({'forceLogout': false})
            .catchError((e) {
              // Ignore errors - this is just initialization
            });
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
          message = 'Invalid OTP. Please check and try again.';
          break;
        case 'invalid-verification-id':
          message = 'Verification expired. Please request a new OTP.';
          break;
        case 'session-expired':
          message = 'Session expired. Please request a new OTP.';
          break;
        case 'credential-already-in-use':
          message = 'This phone number is already linked to another account.';
          break;
        default:
          message = e.message ?? 'OTP verification failed.';
      }
      throw Exception(message);
    }
  }

  /// Link phone number to existing account
  Future<void> linkPhoneNumber({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await currentUser?.linkWithCredential(credential);

      // Update phone in Firestore
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'phone': currentUser!.phoneNumber});
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'provider-already-linked':
          message = 'A phone number is already linked to this account.';
          break;
        case 'invalid-verification-code':
          message = 'Invalid OTP. Please check and try again.';
          break;
        case 'credential-already-in-use':
          message = 'This phone number is already used by another account.';
          break;
        default:
          message = e.message ?? 'Failed to link phone number.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to link phone number: ${e.toString()}');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        default:
          message = e.message ?? 'An error occurred sending password reset.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'requires-recent-login':
          message = 'Please sign in again before deleting your account.';
          break;
        default:
          message = e.message ?? 'An error occurred deleting account.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      await currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'email-already-in-use':
          message = 'This email is already in use by another account.';
          break;
        case 'requires-recent-login':
          message = 'Please sign in again before updating your email.';
          break;
        default:
          message = e.message ?? 'An error occurred updating email.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Email update failed: ${e.toString()}');
    }
  }

  /// Check if the current user has email/password authentication
  bool hasPasswordProvider() {
    final user = currentUser;
    if (user == null) return false;

    // Check if user has password provider
    for (var provider in user.providerData) {
      if (provider.providerId == 'password') {
        return true;
      }
    }
    return false;
  }

  /// Get the primary sign-in method for the current user
  String? getPrimarySignInMethod() {
    final user = currentUser;
    if (user == null || user.providerData.isEmpty) return null;
    return user.providerData.first.providerId;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user is currently signed in');
      }

      // Check if user has password authentication
      if (!hasPasswordProvider()) {
        final provider = getPrimarySignInMethod();
        if (provider == 'google.com') {
          throw Exception(
            'You signed in with Google. Please use Google to manage your password.',
          );
        } else {
          throw Exception(
            'Password change is only available for email/password accounts.',
          );
        }
      }

      // Validate password length
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);

      // Store password change metadata in Firestore
      await _recordPasswordChange(user.uid);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'The new password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please log out and log in again to change password';
          break;
        default:
          message = e.message ?? 'An error occurred changing password';
      }
      throw Exception(message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Password change failed: ${e.toString()}');
    }
  }

  /// Parse account type string to standardized format
  String _parseAccountType(String? accountType) {
    if (accountType == null) return 'personal';
    final lower = accountType.toLowerCase();
    if (lower.contains('professional')) return 'professional';
    if (lower.contains('business')) return 'business';
    return 'personal';
  }

  // Store account type for phone login (set before OTP verification)
  String? _pendingAccountType;

  // Store password for phone signup (used after OTP verification)
  String? _pendingPassword;

  /// Set the account type for pending phone registration
  void setPendingAccountType(String? accountType) {
    _pendingAccountType = accountType;
  }

  /// Set the password for pending phone registration (for signup with password)
  void setPendingPassword(String? password) {
    _pendingPassword = password;
  }

  /// Get the pending password for phone signup
  String? get pendingPassword => _pendingPassword;

  /// Clear pending password after use
  void clearPendingPassword() {
    _pendingPassword = null;
  }

  /// Update user profile on phone login (awaitable version)
  Future<void> _updateUserProfileOnPhoneLoginAsync(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isNewUser = !doc.exists;

      // Determine account type and status for new users
      final accType = _parseAccountType(_pendingAccountType);
      final needsVerification = accType != 'personal';

      // Use phone number as name if displayName is not available
      final displayName = user.displayName ?? user.phoneNumber ?? 'User';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phone': user.phoneNumber,
        'name': displayName,
        'lastSeen': FieldValue.serverTimestamp(),
        if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        if (isNewUser) ...{
          'discoveryModeEnabled': true,
          'interests': [],
          'connections': [],
          'connectionCount': 0,
          'blockedUsers': [],
          'connectionTypes': [],
          'activities': [],
          // Account type fields
          'accountType': accType,
          'accountStatus': needsVerification ? 'pendingVerification' : 'active',
          'verification': {'status': needsVerification ? 'pending' : 'none'},
        },
      }, SetOptions(merge: true));

      // Clear pending data after use
      _pendingAccountType = null;
      _pendingPassword = null;
    } catch (e) {
      // Error updating profile on phone login
    }
  }

  /// Fire-and-forget: Update user profile on email login (runs in background)
  Future<void> _updateUserProfileOnLoginAsync(User user, String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isNewUser = !doc.exists;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? email,
        'lastSeen': FieldValue.serverTimestamp(),
        if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        if (isNewUser) ...{
          'name': email.split('@')[0],
          'discoveryModeEnabled': true,
          'interests': [],
          'connections': [],
          'connectionCount': 0,
          'blockedUsers': [],
          'connectionTypes': [],
          'activities': [],
        },
      }, SetOptions(merge: true));
    } catch (e) {
      // Error updating profile on login
    }
  }

  /// Record password change event in Firestore for security tracking
  Future<void> _recordPasswordChange(String userId) async {
    try {
      final now = FieldValue.serverTimestamp();

      // Update user document with last password change
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastPasswordChange': now,
        'passwordChangeCount': FieldValue.increment(1),
      });

      // Record security event
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('securityEvents')
          .add({'type': 'password_change', 'timestamp': now, 'success': true});
    } catch (e) {
      // Don't fail the password change if logging fails
    }
  }

  // ============= DEVICE SESSION MANAGEMENT =============

  /// Generate a unique device token using UUID
  String _generateDeviceToken() {
    return const Uuid().v4();
  }

  /// Get the local device token from SharedPreferences
  Future<String?> getLocalDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Get the local device token (use async version for reliability)
  /// This is kept as a placeholder - UI should use getLocalDeviceToken() instead
  String? getLocalDeviceTokenSync() {
    // Note: SharedPreferences.getInstance() is async, so we return null here
    // The UI should call getLocalDeviceToken() for actual token retrieval
    return null;
  }

  /// Save device token to SharedPreferences
  Future<void> _saveLocalDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceTokenKey, token);
    } catch (e) {
      // Silent fail - not critical
    }
  }

  /// Clear device token from SharedPreferences
  Future<void> _clearLocalDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceTokenKey);
    } catch (e) {
      // Silent fail - not critical
    }
  }

  /// Get device information (name, model, platform, OS version)
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      String deviceName = 'Unknown Device';
      String deviceModel = 'Unknown';
      String platform = 'Unknown';
      String osVersion = 'Unknown';

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        deviceModel = androidInfo.model;
        platform = 'Android';
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceName = iosInfo.model;
        deviceModel = iosInfo.model;
        platform = 'iOS';
        osVersion = iosInfo.systemVersion;
      }

      return {
        'deviceName': deviceName,
        'deviceModel': deviceModel,
        'platform': platform,
        'osVersion': osVersion,
        'appVersion': '1.0.0+1',
      };
    } catch (e) {
      return {
        'deviceName': 'Device',
        'deviceModel': 'Unknown',
        'platform': 'Unknown',
        'osVersion': 'Unknown',
        'appVersion': '1.0.0+1',
      };
    }
  }

  /// Check if user is already logged in on another device
  /// Returns {exists: bool, deviceInfo: Map, loginDate: DateTime?}
  Future<Map<String, dynamic>> _checkExistingSession(String uid) async {
    try {
      // Get user document from server (no cache)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      final serverToken = doc.data()?['activeDeviceToken'] as String?;
      final deviceInfo = doc.data()?['deviceInfo'] as Map<String, dynamic>?;
      final lastSessionUpdate = doc.data()?['lastSessionUpdate'] as Timestamp?;

      // Get local device token
      final localToken = await getLocalDeviceToken();

      // If server has a token and it doesn't match local token, session exists on another device
      if (serverToken != null &&
          serverToken.isNotEmpty &&
          (localToken == null || serverToken != localToken)) {
        return {
          'exists': true,
          'deviceInfo': deviceInfo ?? {'deviceName': 'Another Device'},
          'loginDate': lastSessionUpdate?.toDate(),
        };
      }

      return {'exists': false};
    } catch (e) {
      // On error, assume no existing session (fail-open for UX)
      return {'exists': false};
    }
  }

  /// Save device session to Firestore after successful login
  Future<void> _saveDeviceSession(String uid, String deviceToken) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activeDeviceToken': deviceToken,
        'deviceInfo': deviceInfo,
        'lastSessionUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log but don't fail - device session is non-critical for login
      print('[AuthService] Error saving device session: $e');
    }
  }

  /// Clear device session from Firestore on logout
  Future<void> _clearDeviceSession(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activeDeviceToken': FieldValue.delete(),
      });
    } catch (e) {
      // Silent fail - not critical
      print('[AuthService] Error clearing device session: $e');
    }
  }

  /// Logout from all other devices and keep only current device logged in
  /// Uses a two-step approach for instant logout (WhatsApp-style):
  /// 1. Set forceLogout flag to trigger immediate logout on other devices
  /// 2. Then set new device as active
  Future<void> logoutFromOtherDevices({String? userId}) async {
    try {
      // Get user ID from parameter or current user
      final uid = userId ?? currentUser?.uid;
      if (uid == null) {
        throw Exception('No user ID available');
      }

      // Get current device token from SharedPreferences
      String? localToken = await getLocalDeviceToken();
      print(
        '[AuthService] Current token: ${localToken?.substring(0, 8) ?? "NULL"}...',
      );

      // If no token in SharedPreferences, generate and save NEW one for this device
      if (localToken == null) {
        print(
          '[AuthService] No token found in SharedPreferences, generating new one...',
        );
        localToken = _generateDeviceToken();
        await _saveLocalDeviceToken(localToken);
        print(
          '[AuthService] New token generated and saved: ${localToken.substring(0, 8)}...',
        );
      }

      // Get current device info
      final deviceInfo = await _getDeviceInfo();

      print('[AuthService] Calling Cloud Function: forceLogoutOtherDevices');
      print('[AuthService] New device token: ${localToken.substring(0, 8)}...');

      // Call Callable Cloud Function to handle force logout securely
      // The Cloud Function runs with admin privileges, bypassing Firestore security rules
      // This ensures permission-denied errors don't block the logout process
      final callable = FirebaseFunctions.instance
          .httpsCallable('forceLogoutOtherDevices');

      try {
        final result = await callable.call({
          'localToken': localToken,
          'deviceInfo': deviceInfo,
        });

        if (result.data['success'] == true) {
          print(
            '[AuthService] ✓ Successfully forced logout on other devices - instant like WhatsApp!',
          );
        } else {
          throw Exception(
              result.data['message'] ?? 'Cloud Function returned error');
        }
      } catch (e) {
        print(
          '[AuthService] Cloud Function error: $e. Attempting direct Firestore write as fallback...',
        );
        // Fallback: Try direct Firestore write if Cloud Function fails
        // This handles cases where Cloud Function isn't deployed yet
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({
            'forceLogout': true,
            'activeDeviceToken': '',
            'lastSessionUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await Future.delayed(const Duration(milliseconds: 500));

          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({
            'activeDeviceToken': localToken,
            'deviceInfo': deviceInfo,
            'forceLogout': false,
            'lastSessionUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print(
            '[AuthService] ✓ Fallback write succeeded - forced logout completed',
          );
        } catch (fallbackError) {
          print('[AuthService] Fallback write also failed: $fallbackError');
          rethrow;
        }
      }
    } catch (e) {
      print('[AuthService] Error logging out from other devices: $e');
      rethrow;
    }
  }
}
