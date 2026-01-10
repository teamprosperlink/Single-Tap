import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../res/utils/photo_url_helper.dart';

/// Model class to hold active device session info
class ActiveDeviceInfo {
  final String deviceName;
  final String deviceModel;
  final DateTime loginTime;

  ActiveDeviceInfo({
    required this.deviceName,
    required this.deviceModel,
    required this.loginTime,
  });

  factory ActiveDeviceInfo.fromMap(Map<String, dynamic> map) {
    return ActiveDeviceInfo(
      deviceName: map['deviceName'] as String? ?? 'Unknown Device',
      deviceModel: map['deviceModel'] as String? ?? 'Unknown',
      loginTime: (map['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static const String _deviceTokenKey = 'device_login_token';

  // Phone verification state - stored for auto-retrieval timeout handling
  // ignore: unused_field
  String? _verificationId;
  int? _resendToken;

  // Store phone number for session check during OTP verification
  String? _pendingPhoneNumber;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Direct access to Firebase auth for emergency sign-out
  FirebaseAuth get firebaseAuth => _auth;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update profile first, then register device
      if (result.user != null) {
        final user = result.user!;

        // CRITICAL: Check if already logged in on another device AFTER Firebase auth
        // Use UID-based check - this is the ONLY reliable check
        // It directly compares local device token with server token
        // ignore: avoid_print
        print('[EmailLogin] Checking existing session for UID: ${user.uid}');
        final existingSessionByUid = await _checkExistingSessionByUid(user.uid);
        if (existingSessionByUid != null) {
          // ignore: avoid_print
          print(
            '[EmailLogin] ❌ EXISTING SESSION FOUND - BLOCKING LOGIN AND SIGNING OUT',
          );
          // CRITICAL: Sign out from Firebase AND clear local token
          try {
            // Delete local token FIRST
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('device_login_token');
            // ignore: avoid_print
            print('[EmailLogin] Local device token cleared');

            // Then sign out from Firebase
            await _auth.signOut();
            // ignore: avoid_print
            print('[EmailLogin] Firebase signed out successfully');

            // Extra wait to ensure state propagates
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            // ignore: avoid_print
            print('[EmailLogin] Error during logout: $e');
          }

          // Format: ALREADY_LOGGED_IN:DeviceName:Timestamp:CredentialType:Credential:UID
          throw Exception(
            'ALREADY_LOGGED_IN:${existingSessionByUid.deviceName}:${existingSessionByUid.loginTime.millisecondsSinceEpoch}:email:$email:${user.uid}',
          );
        }

        // ignore: avoid_print
        print('[EmailLogin] ✅ NO EXISTING SESSION - PROCEEDING');

        // Wait for profile update to complete first (so email is saved)
        await _updateUserProfileOnLoginAsync(user, email);

        // Register this device as active device (single device login)
        await _registerDeviceAfterLogin(user.uid);
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
    } catch (e) {
      // Re-throw ALREADY_LOGGED_IN exception as-is
      if (e.toString().contains('ALREADY_LOGGED_IN')) {
        rethrow;
      }
      // Re-throw session check errors (device verification failures)
      if (e.toString().contains('[SessionCheck]')) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: ${e.toString()}');
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

      // NOTE: Pre-login session check removed - it can cause false positives
      // when user has logged out but Firestore still has stale token.
      // The reliable check happens AFTER Firebase auth using UID-based check
      // which compares local token with server token.

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      // Save Google profile photo URL to Firestore
      if (result.user != null) {
        final user = result.user!;

        // CRITICAL: Check if already logged in on another device AFTER Firebase auth
        // This is the most reliable check using UID
        // ignore: avoid_print
        print('[GoogleLogin] Checking existing session for UID: ${user.uid}');
        final existingSessionByUid = await _checkExistingSessionByUid(user.uid);
        if (existingSessionByUid != null) {
          // ignore: avoid_print
          print(
            '[GoogleLogin] ❌ EXISTING SESSION FOUND - BLOCKING LOGIN AND SIGNING OUT',
          );
          // CRITICAL: Sign out from Firebase AND clear local token
          try {
            // Delete local token FIRST
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('device_login_token');
            // ignore: avoid_print
            print('[GoogleLogin] Local device token cleared');

            // Then sign out from Firebase
            await _auth.signOut();
            // ignore: avoid_print
            print('[GoogleLogin] Firebase signed out successfully');

            // Extra wait to ensure state propagates
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            // ignore: avoid_print
            print('[GoogleLogin] Error during logout: $e');
          }
          // Format: ALREADY_LOGGED_IN:DeviceName:Timestamp:CredentialType:Credential:UID
          throw Exception(
            'ALREADY_LOGGED_IN:${existingSessionByUid.deviceName}:${existingSessionByUid.loginTime.millisecondsSinceEpoch}:google:${googleUser.email}:${user.uid}',
          );
        }

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

        // Register this device as active device (single device login)
        await _registerDeviceAfterLogin(user.uid);
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
    } catch (e) {
      // Re-throw ALREADY_LOGGED_IN exception as-is
      if (e.toString().contains('ALREADY_LOGGED_IN')) {
        rethrow;
      }
      // Re-throw session check errors (device verification failures)
      if (e.toString().contains('[SessionCheck]')) {
        rethrow;
      }
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      // CRITICAL: Clear device token from Firestore SYNCHRONOUSLY (must await)
      // This must complete BEFORE we sign out locally
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Update with strict wait - no catch, let it fail hard if needed
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
                'activeDeviceToken':
                    FieldValue.delete(), // CRITICAL: Delete token
                'deviceName': FieldValue.delete(),
              })
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  // If timeout, try set with null instead
                  throw Exception('Update timeout - trying set');
                },
              );
          print(
            '[SignOut] Successfully cleared activeDeviceToken for ${user.uid}',
          );
        } catch (e) {
          print('[SignOut] Update failed: $e - trying set with null');
          // Fallback: Set with explicit null values
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'activeDeviceToken': null,
                  'deviceName': null,
                }, SetOptions(merge: true))
                .timeout(const Duration(seconds: 5));
            print('[SignOut] Set with null successful');
          } catch (e2) {
            print('[SignOut] Set also failed: $e2');
          }
        }
      }

      // Clear local device token AFTER Firestore update completes
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceTokenKey);
      print('[SignOut] Local token cleared');

      // Sign out from Firebase and Google LAST
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut().catchError((e) => null),
      ]);
      print('[SignOut] Firebase signOut completed');
    } catch (e) {
      print('[SignOut] Error: $e');
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
      // Store phone number for session check during OTP verification
      _pendingPhoneNumber = phoneNumber;

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

      // Update profile first, then register device
      if (result.user != null) {
        final user = result.user!;

        // CRITICAL: Check if already logged in on another device AFTER Firebase auth
        // Use UID-based check - this is the ONLY reliable check
        // It directly compares local device token with server token
        // ignore: avoid_print
        print('[PhoneLogin] Checking existing session for UID: ${user.uid}');
        final existingSessionByUid = await _checkExistingSessionByUid(user.uid);
        if (existingSessionByUid != null) {
          // ignore: avoid_print
          print(
            '[PhoneLogin] ❌ EXISTING SESSION FOUND - BLOCKING LOGIN AND SIGNING OUT',
          );
          // CRITICAL: Sign out from Firebase AND clear local token
          try {
            // Delete local token FIRST
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('device_login_token');
            // ignore: avoid_print
            print('[PhoneLogin] Local device token cleared');

            // Then sign out from Firebase
            await _auth.signOut();
            // ignore: avoid_print
            print('[PhoneLogin] Firebase signed out successfully');

            // Extra wait to ensure state propagates
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            // ignore: avoid_print
            print('[PhoneLogin] Error during logout: $e');
          }
          final phoneForLogout = _pendingPhoneNumber;
          _pendingPhoneNumber = null;
          // Format: ALREADY_LOGGED_IN:DeviceName:Timestamp:CredentialType:Credential:UID
          throw Exception(
            'ALREADY_LOGGED_IN:${existingSessionByUid.deviceName}:${existingSessionByUid.loginTime.millisecondsSinceEpoch}:phone:${phoneForLogout ?? ''}:${user.uid}',
          );
        }

        // Wait for profile update to complete first (so phone number is saved)
        await _updateUserProfileOnPhoneLoginAsync(user);

        // Register this device as active device (single device login)
        await _registerDeviceAfterLogin(user.uid);

        // Clear pending phone number
        _pendingPhoneNumber = null;
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
    } catch (e) {
      // Re-throw ALREADY_LOGGED_IN exception as-is
      if (e.toString().contains('ALREADY_LOGGED_IN')) {
        rethrow;
      }
      // Re-throw session check errors (device verification failures)
      if (e.toString().contains('[SessionCheck]')) {
        rethrow;
      }
      throw Exception('OTP verification failed: ${e.toString()}');
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

  /// Generate a unique device token for single device login
  Future<String> _generateAndSaveDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = const Uuid().v4();
    await prefs.setString(_deviceTokenKey, token);
    return token;
  }

  /// Get the current device token
  Future<String?> _getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceTokenKey);
  }

  /// Save device token to Firestore for the user with device info
  Future<void> _saveDeviceTokenToFirestore(String userId, String token) async {
    final deviceName = await _getDeviceName();
    // Use set with merge to ensure document exists
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'activeDeviceToken': token,
      'deviceName': deviceName,
      'deviceModel': Platform.operatingSystem,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Check if current device is the active device for the user
  /// Returns true if device is valid, false if user should be logged out
  Future<bool> validateDeviceSession({bool autoLogout = true}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('[ValidateSession] No user logged in');
        return false;
      }

      final localToken = await _getDeviceToken();
      if (localToken == null) {
        print('[ValidateSession] No local token found');
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) {
        print('[ValidateSession] User document does not exist');
        return false;
      }

      final data = doc.data();
      final serverToken = data?['activeDeviceToken'] as String?;

      print('[ValidateSession] Comparing tokens:');
      print('[ValidateSession]   Local:  ${localToken.substring(0, 6)}...');
      print(
        '[ValidateSession]   Server: ${serverToken?.substring(0, 6) ?? 'NULL'}...',
      );

      // If server token is null/deleted, user was logged out remotely
      if (serverToken == null || serverToken.isEmpty) {
        print('[ValidateSession] Server token deleted - LOGOUT DETECTED');
        if (autoLogout) {
          print('[ValidateSession] Calling forceLogout()');
          await forceLogout();
        }
        return false;
      }

      // If server token doesn't match local token, user logged in from another device
      if (serverToken != localToken) {
        print('[ValidateSession] Token mismatch - LOGOUT DETECTED');
        // Force logout this device
        if (autoLogout) {
          print('[ValidateSession] Calling forceLogout()');
          await forceLogout();
        }
        return false;
      }

      print('[ValidateSession] Session valid - tokens match');
      // Session is valid - refresh device name in case it was saved with old code
      // This will update generic names like "Android Device" to actual model names
      _refreshDeviceName(user.uid);

      return true;
    } catch (e) {
      print('[ValidateSession] Error: $e');
      return true; // On error, don't force logout
    }
  }

  /// Refresh device name in Firestore (fire-and-forget)
  /// This updates old generic names to proper device model names
  void _refreshDeviceName(String userId) async {
    try {
      final deviceName = await _getDeviceName();
      // Only update if we got a meaningful name (not generic)
      if (deviceName.isNotEmpty &&
          deviceName != 'Android Device' &&
          deviceName != 'Android Phone' &&
          deviceName != 'iPhone' &&
          deviceName != 'Unknown Device' &&
          deviceName != 'Mobile Device') {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'deviceName': deviceName},
        );
      }
    } catch (e) {
      // Ignore errors - this is a background refresh
    }
  }

  /// Force logout without updating Firestore (used when kicked out by another device)
  Future<void> forceLogout() async {
    print('[ForceLogout] ===== STARTING FORCE LOGOUT =====');
    try {
      // Clear local device token
      print('[ForceLogout] Clearing local device token...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceTokenKey);
      print('[ForceLogout] Local device token cleared');

      // Sign out from Firebase and Google
      print('[ForceLogout] Signing out from Firebase and Google...');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut().catchError((e) {
          print('[ForceLogout] Google Sign-Out error (non-fatal): $e');
          return null;
        }),
      ]);
      print('[ForceLogout] Firebase and Google sign-out completed');

      // Verify user is actually null
      final currentUser = _auth.currentUser;
      print(
        '[ForceLogout] Current user is now: ${currentUser?.uid ?? 'NULL (VERIFIED)'}',
      );
      print('[ForceLogout] ===== FORCE LOGOUT COMPLETE =====');
    } catch (e) {
      print('[ForceLogout] ⚠️ Error in forceLogout: $e');
      print('[ForceLogout] Attempting fallback: Firebase sign-out only...');
      try {
        await _auth.signOut();
        print('[ForceLogout] Fallback sign-out succeeded');
      } catch (e2) {
        print('[ForceLogout]   CRITICAL: Even fallback sign-out failed: $e2');
        rethrow;
      }
    }
  }

  /// Stream that monitors device session validity in real-time
  /// Emits false when device token is cleared (remote logout) or mismatched
  /// Used to instantly logout user when they're logged out from another device
  Stream<bool> deviceSessionStream(String userId, String localToken) {
    // ignore: avoid_print
    print(
      '[DeviceSession] Starting stream for user: $userId, localToken: ${localToken.substring(0, 8)}...',
    );

    // Direct Firestore stream - no async complexity
    return FirebaseFirestore.instance.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      // ignore: avoid_print
      print('[DeviceSession] Snapshot received at ${DateTime.now()}');

      if (!snapshot.exists) {
        // ignore: avoid_print
        print('[DeviceSession] Document does not exist - invalid');
        return false;
      }

      final data = snapshot.data();
      final serverToken = data?['activeDeviceToken'] as String?;

      // ignore: avoid_print
      print(
        '[DeviceSession] Server token: ${serverToken?.substring(0, 8) ?? 'NULL/DELETED'}',
      );

      // If server token is null/deleted, user was logged out remotely
      if (serverToken == null || serverToken.isEmpty) {
        // ignore: avoid_print
        print(
          '[DeviceSession] *** REMOTE LOGOUT DETECTED - Token deleted! ***',
        );
        return false;
      }

      // If tokens don't match, user logged in from another device
      final isValid = serverToken == localToken;
      if (!isValid) {
        // ignore: avoid_print
        print(
          '[DeviceSession] *** TOKEN MISMATCH - Another device logged in! ***',
        );
      }
      return isValid;
    });
  }

  /// Get local device token (public method for stream setup)
  Future<String?> getLocalDeviceToken() async {
    return await _getDeviceToken();
  }

  /// Remote logout by UID: Clear device token from Firestore to logout another device
  /// This is the preferred method as it works directly with the user document
  /// Requires the caller to be authenticated (will work during login flow)
  Future<bool> remoteLogoutByUid(String uid) async {
    try {
      // ignore: avoid_print
      print(
        '[RemoteLogout] ===== STARTING REMOTE LOGOUT FOR OTHER DEVICE =====',
      );
      print('[RemoteLogout] Target UID: $uid');

      // Directly update the user document by UID
      print('[RemoteLogout] Deleting activeDeviceToken from Firestore...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
            'activeDeviceToken': FieldValue.delete(),
            'deviceName': FieldValue.delete(),
          })
          .timeout(const Duration(seconds: 5));

      print('[RemoteLogout] ✓ Successfully deleted activeDeviceToken');

      // CRITICAL: Wait for Firestore to propagate globally
      // Real devices might have slower network than emulators
      // Increased from 1000ms to 2000ms for real device compatibility
      print(
        '[RemoteLogout] Waiting 2000ms for Firestore global propagation...',
      );
      await Future.delayed(const Duration(milliseconds: 2000));
      print('[RemoteLogout] ✓ Propagation complete');

      print('[RemoteLogout] ===== REMOTE LOGOUT COMPLETE =====');
      print(
        '[RemoteLogout] ⭐ Other device should detect logout within 150-300ms (polling interval)',
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteLogout]   Remote logout by UID failed: $e');
      return false;
    }
  }

  /// Remote logout: Clear device token from Firestore to logout another device
  /// This is used when user wants to force logout from another device
  /// Takes email or phone to find the user document
  Future<bool> remoteLogoutByEmail(String email) async {
    try {
      // Normalize email
      final normalizedEmail = email.trim().toLowerCase();

      // Find user by email
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .orderBy('uid')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .orderBy('uid')
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        return false; // User not found
      }

      // Clear device token from Firestore
      final userId = querySnapshot.docs.first.id;
      // ignore: avoid_print
      print('[RemoteLogout] Deleting token for user: $userId (email-based)');
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'activeDeviceToken': FieldValue.delete(),
        'deviceName': FieldValue.delete(),
      });

      // Wait for Firestore propagation
      // ignore: avoid_print
      print('[RemoteLogout] Waiting 1000ms for propagation...');
      await Future.delayed(const Duration(milliseconds: 1000));

      // ignore: avoid_print
      print('[RemoteLogout] ✓ Email-based logout complete');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteLogout]   Email-based logout failed: $e');
      return false;
    }
  }

  /// Remote logout by phone number
  Future<bool> remoteLogoutByPhone(String phoneNumber) async {
    try {
      // Normalize phone number
      final normalizedPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Create list of phone formats to try
      final phoneFormats = <String>[normalizedPhone];

      if (normalizedPhone.startsWith('+')) {
        phoneFormats.add(normalizedPhone.substring(1));
      } else {
        phoneFormats.add('+$normalizedPhone');
      }

      if (normalizedPhone.startsWith('+91')) {
        phoneFormats.add(normalizedPhone.substring(3));
        phoneFormats.add('91${normalizedPhone.substring(3)}');
      } else if (normalizedPhone.startsWith('91') &&
          normalizedPhone.length > 10) {
        phoneFormats.add('+$normalizedPhone');
        phoneFormats.add(normalizedPhone.substring(2));
      }

      QuerySnapshot<Map<String, dynamic>>? querySnapshot;

      for (final format in phoneFormats) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: format)
            .orderBy('uid')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          break;
        }
      }

      if (querySnapshot == null || querySnapshot.docs.isEmpty) {
        return false; // User not found
      }

      // Clear device token from Firestore
      final userId = querySnapshot.docs.first.id;
      // ignore: avoid_print
      print('[RemoteLogout] Deleting token for user: $userId (phone-based)');
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'activeDeviceToken': FieldValue.delete(),
        'deviceName': FieldValue.delete(),
      });

      // Wait for Firestore propagation
      // ignore: avoid_print
      print('[RemoteLogout] Waiting 1000ms for propagation...');
      await Future.delayed(const Duration(milliseconds: 1000));

      // ignore: avoid_print
      print('[RemoteLogout] ✓ Phone-based logout complete');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteLogout]   Phone-based logout failed: $e');
      return false;
    }
  }

  /// Register device after successful login - SINGLE DEVICE ONLY
  Future<void> _registerDeviceAfterLogin(String userId) async {
    try {
      print('[RegisterDevice] ===== SINGLE DEVICE LOGIN START =====');

      // Generate new token
      print('[RegisterDevice] Generating new token...');
      final newToken = await _generateAndSaveDeviceToken();
      print('[RegisterDevice] New token: ${newToken.substring(0, 6)}...');

      // CRITICAL: Delete ALL previous tokens FIRST
      // This ensures any other device will detect logout immediately
      print('[RegisterDevice] Deleting ALL previous tokens...');
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
              'activeDeviceToken': FieldValue.delete(),
              'deviceName': FieldValue.delete(),
            })
            .timeout(const Duration(seconds: 3));
        print('[RegisterDevice] ✓ All previous tokens deleted');
      } catch (e) {
        print('[RegisterDevice] ⚠️ Delete previous failed (continuing): $e');
      }

      // Wait for deletion to propagate across all Firebase servers
      print('[RegisterDevice] Waiting 2500ms for Firestore propagation...');
      await Future.delayed(const Duration(milliseconds: 2500));

      // NOW save ONLY our new token
      // This is the only token that exists at this point
      print('[RegisterDevice] Saving new token (ONLY active token)...');
      await _saveDeviceTokenToFirestore(userId, newToken);
      print('[RegisterDevice] ✓ New token saved (single device active)');

      // Final wait to ensure new token is replicated
      await Future.delayed(const Duration(milliseconds: 1500));

      print('[RegisterDevice] ✓✓✓ SINGLE DEVICE LOGIN COMPLETE ✓✓✓');
      print('[RegisterDevice] ===== END =====');
    } catch (e) {
      print('[RegisterDevice]   ERROR: $e');
      rethrow;
    }
  }

  /// Get current device name with actual model info
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Get brand and model - these should always be available on Android
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        final manufacturer = androidInfo.manufacturer;
        final device = androidInfo.device;
        final product = androidInfo.product;

        // Debug log the values (will be visible in console)
        // ignore: avoid_print
        print(
          'Device Info - Brand: $brand, Model: $model, Manufacturer: $manufacturer, Device: $device, Product: $product',
        );

        // Try to build a meaningful device name
        if (model.isNotEmpty && model != 'unknown') {
          // Format brand name properly
          String brandName = brand.isNotEmpty ? brand : manufacturer;
          if (brandName.isNotEmpty && brandName != 'unknown') {
            brandName = _capitalizeFirstLetter(brandName);

            // Check if model already contains brand name to avoid duplication
            // e.g., "Samsung Galaxy S21" already has Samsung
            if (model.toLowerCase().contains(brandName.toLowerCase())) {
              return model;
            }

            // Check for common patterns where model starts with brand code
            // e.g., SM-G991B (Samsung), RMX3085 (Realme), M2101K6G (Xiaomi)
            if (_isModelCodeOnly(model)) {
              // Try to get friendly name from model code
              final friendlyName = _getAndroidFriendlyName(brandName, model);
              if (friendlyName != null) {
                return friendlyName;
              }
              // If no friendly name, show brand + model code
              return '$brandName $model';
            }

            return '$brandName $model';
          }
          // Model only (no brand)
          return model;
        } else if (device.isNotEmpty && device != 'unknown') {
          return device;
        } else if (product.isNotEmpty && product != 'unknown') {
          return product;
        }
        return 'Android Phone';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Get model identifier like "iPhone14,2" and convert to friendly name
        final machineId = iosInfo.utsname.machine;
        final name =
            iosInfo.name; // User's custom device name like "John's iPhone"
        final modelName = iosInfo.model; // This gives "iPhone", "iPad", etc.

        // Debug log the values
        // ignore: avoid_print
        print('iOS Info - Machine: $machineId, Name: $name, Model: $modelName');

        // Try to get a user-friendly name from machine identifier
        if (machineId.isNotEmpty) {
          // Convert machine identifier to friendly name
          final friendlyName = _getIPhoneFriendlyName(machineId);
          if (friendlyName != null) {
            return friendlyName;
          }
        }

        // Use user's custom device name if it's meaningful
        // Skip if it's just "iPhone" or generic name
        if (name.isNotEmpty &&
                name != 'iPhone' &&
                name != 'iPad' &&
                !name.toLowerCase().contains('iphone') ||
            name.contains("'s")) {
          // User names like "John's iPhone"
          return name;
        }

        // Fallback to model name (iPhone, iPad)
        if (modelName.isNotEmpty && modelName != 'unknown') {
          return modelName;
        }
        return 'iPhone';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName.isNotEmpty
            ? windowsInfo.computerName
            : 'Windows PC';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName.isNotEmpty ? macInfo.computerName : 'Mac';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.prettyName.isNotEmpty
            ? linuxInfo.prettyName
            : 'Linux PC';
      }
      return 'Unknown Device';
    } catch (e) {
      // ignore: avoid_print
      print('Error getting device name: $e');
      // Fallback to platform-based names if device_info_plus fails
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isMacOS) return 'Mac';
      if (Platform.isLinux) return 'Linux PC';
      return 'Mobile Device';
    }
  }

  /// Capitalize first letter of a string
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Check if model string is just a code (like SM-G991B) rather than a name
  bool _isModelCodeOnly(String model) {
    // Common model code patterns
    // Samsung: SM-XXXX, GT-XXXX
    // Xiaomi: M2101K6G, 2201116SG
    // Realme: RMX3085
    // OnePlus: LE2115, DN2103
    // Oppo: CPH2185
    // Vivo: V2111
    return RegExp(
          r'^[A-Z]{2,3}[-]?[A-Z0-9]{4,}$',
          caseSensitive: false,
        ).hasMatch(model) ||
        RegExp(r'^[0-9]{4,}[A-Z0-9]*$').hasMatch(model);
  }

  /// Get friendly name for Android devices from model code
  String? _getAndroidFriendlyName(String brand, String modelCode) {
    final upperModel = modelCode.toUpperCase();
    final lowerBrand = brand.toLowerCase();

    // Samsung model mappings
    if (lowerBrand == 'samsung') {
      final samsungModels = {
        // Galaxy S series
        'SM-S928': 'Galaxy S24 Ultra',
        'SM-S926': 'Galaxy S24+',
        'SM-S921': 'Galaxy S24',
        'SM-S918': 'Galaxy S23 Ultra',
        'SM-S916': 'Galaxy S23+',
        'SM-S911': 'Galaxy S23',
        'SM-S908': 'Galaxy S22 Ultra',
        'SM-S906': 'Galaxy S22+',
        'SM-S901': 'Galaxy S22',
        'SM-G998': 'Galaxy S21 Ultra',
        'SM-G996': 'Galaxy S21+',
        'SM-G991': 'Galaxy S21',
        'SM-G988': 'Galaxy S20 Ultra',
        'SM-G986': 'Galaxy S20+',
        'SM-G981': 'Galaxy S20',
        // Galaxy A series
        'SM-A546': 'Galaxy A54',
        'SM-A536': 'Galaxy A53',
        'SM-A526': 'Galaxy A52',
        'SM-A346': 'Galaxy A34',
        'SM-A336': 'Galaxy A33',
        'SM-A236': 'Galaxy A23',
        'SM-A146': 'Galaxy A14',
        'SM-A136': 'Galaxy A13',
        'SM-A047': 'Galaxy A04s',
        // Galaxy M series
        'SM-M546': 'Galaxy M54',
        'SM-M536': 'Galaxy M53',
        'SM-M336': 'Galaxy M33',
        'SM-M236': 'Galaxy M23',
        // Galaxy F series
        'SM-E546': 'Galaxy F54',
        'SM-E236': 'Galaxy F23',
        // Galaxy Note series
        'SM-N986': 'Galaxy Note 20 Ultra',
        'SM-N981': 'Galaxy Note 20',
        'SM-N976': 'Galaxy Note 10+ 5G',
        'SM-N975': 'Galaxy Note 10+',
        'SM-N970': 'Galaxy Note 10',
        // Galaxy Z Fold/Flip
        'SM-F946': 'Galaxy Z Fold 5',
        'SM-F936': 'Galaxy Z Fold 4',
        'SM-F926': 'Galaxy Z Fold 3',
        'SM-F731': 'Galaxy Z Flip 5',
        'SM-F721': 'Galaxy Z Flip 4',
        'SM-F711': 'Galaxy Z Flip 3',
      };

      // Check for prefix match
      for (final entry in samsungModels.entries) {
        if (upperModel.startsWith(entry.key)) {
          return 'Samsung ${entry.value}';
        }
      }
    }

    // OnePlus model mappings
    if (lowerBrand == 'oneplus') {
      final onePlusModels = {
        'CPH2449': 'OnePlus 12',
        'CPH2451': 'OnePlus 12R',
        'PHB110': 'OnePlus 11',
        'CPH2423': 'OnePlus 11R',
        'NE2215': 'OnePlus 10 Pro',
        'NE2213': 'OnePlus 10T',
        'LE2115': 'OnePlus 9 Pro',
        'LE2111': 'OnePlus 9',
        'LE2117': 'OnePlus 9R',
        'IN2023': 'OnePlus 8 Pro',
        'IN2013': 'OnePlus 8',
        'IN2011': 'OnePlus 8T',
        'HD1913': 'OnePlus 7T Pro',
        'HD1903': 'OnePlus 7T',
        'GM1917': 'OnePlus 7 Pro',
        'GM1903': 'OnePlus 7',
        'AC2003': 'OnePlus Nord',
        'BE2029': 'OnePlus Nord N10',
        'DN2103': 'OnePlus Nord 2',
        'CPH2381': 'OnePlus Nord CE 2',
        'CPH2409': 'OnePlus Nord CE 3',
      };

      if (onePlusModels.containsKey(upperModel)) {
        return onePlusModels[upperModel];
      }
    }

    // Xiaomi/Redmi/POCO model mappings
    if (lowerBrand == 'xiaomi' ||
        lowerBrand == 'redmi' ||
        lowerBrand == 'poco') {
      final xiaomiModels = {
        '2312DRA50G': 'Xiaomi 14',
        '2311DRK48G': 'Xiaomi 14 Pro',
        '2210132G': 'Xiaomi 13',
        '2210132C': 'Xiaomi 13 Pro',
        '2211133G': 'Xiaomi 13T',
        '23078PND5G': 'Xiaomi 13T Pro',
        '2201123G': 'Xiaomi 12',
        '2201122G': 'Xiaomi 12 Pro',
        '2203121C': 'Xiaomi 12S Ultra',
        '23053RN02A': 'Redmi Note 12 Pro+',
        '22101316G': 'Redmi Note 12',
        '22101316I': 'Redmi Note 12 Pro',
        '21091116AG': 'Redmi Note 11',
        '2201116SG': 'Redmi Note 11 Pro',
        '2201116TG': 'Redmi Note 11 Pro+',
        'M2101K6G': 'Redmi Note 10 Pro',
        '23076PC4BI': 'POCO X5 Pro',
        '22101320G': 'POCO X5',
        '22041219PG': 'POCO F4',
        '21091116UG': 'POCO M4 Pro',
        'M2012K11AG': 'POCO X3 Pro',
      };

      if (xiaomiModels.containsKey(upperModel)) {
        return xiaomiModels[upperModel];
      }
    }

    // Realme model mappings
    if (lowerBrand == 'realme') {
      final realmeModels = {
        'RMX3700': 'Realme GT 5 Pro',
        'RMX3663': 'Realme GT Neo 5',
        'RMX3574': 'Realme GT 3',
        'RMX3571': 'Realme GT Neo 3',
        'RMX3560': 'Realme GT Neo 3T',
        'RMX3393': 'Realme GT 2 Pro',
        'RMX3311': 'Realme GT Neo 2',
        'RMX3085': 'Realme GT',
        'RMX3630': 'Realme 11 Pro+',
        'RMX3771': 'Realme 12 Pro+',
        'RMX3761': 'Realme 12 Pro',
        'RMX3516': 'Realme 10 Pro+',
        'RMX3661': 'Realme Narzo 60 Pro',
        'RMX3686': 'Realme C55',
      };

      if (realmeModels.containsKey(upperModel)) {
        return realmeModels[upperModel];
      }
    }

    // Oppo model mappings
    if (lowerBrand == 'oppo') {
      final oppoModels = {
        'CPH2551': 'Oppo Find X7 Ultra',
        'CPH2525': 'Oppo Find X6 Pro',
        'CPH2519': 'Oppo Find X6',
        'CPH2305': 'Oppo Find X5 Pro',
        'CPH2185': 'Oppo Reno 6 Pro',
        'CPH2251': 'Oppo Reno 7 Pro',
        'CPH2363': 'Oppo Reno 8 Pro',
        'CPH2359': 'Oppo Reno 8',
        'CPH2493': 'Oppo Reno 10 Pro+',
        'CPH2609': 'Oppo Reno 11 Pro',
        'CPH2505': 'Oppo A78',
        'CPH2387': 'Oppo A96',
        'CPH2269': 'Oppo A76',
      };

      if (oppoModels.containsKey(upperModel)) {
        return oppoModels[upperModel];
      }
    }

    // Vivo model mappings
    if (lowerBrand == 'vivo') {
      final vivoModels = {
        'V2324': 'Vivo X100 Pro',
        'V2309': 'Vivo X100',
        'V2219': 'Vivo X90 Pro',
        'V2217': 'Vivo X90',
        'V2145': 'Vivo X80 Pro',
        'V2183': 'Vivo X80',
        'V2111': 'Vivo X70 Pro+',
        'V2105': 'Vivo X70 Pro',
        'V2230': 'Vivo V29 Pro',
        'V2250': 'Vivo V29',
        'V2205': 'Vivo V27 Pro',
        'V2246': 'Vivo V27',
        'V2166': 'Vivo V25 Pro',
        'V2238': 'Vivo Y100',
        'V2207': 'Vivo Y56',
      };

      if (vivoModels.containsKey(upperModel)) {
        return vivoModels[upperModel];
      }
    }

    return null; // No friendly name found
  }

  /// Convert iOS machine identifier to friendly name
  String? _getIPhoneFriendlyName(String machineId) {
    // Common iPhone models mapping
    final Map<String, String> iphoneModels = {
      // iPhone 16 Series (2024)
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
      'iPhone17,3': 'iPhone 16',
      'iPhone17,4': 'iPhone 16 Plus',
      // iPhone 15 Series (2023)
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      // iPhone 14 Series (2022)
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      // iPhone 13 Series (2021)
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13',
      // iPhone 12 Series (2020)
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      // iPhone 11 Series (2019)
      'iPhone12,1': 'iPhone 11',
      'iPhone12,3': 'iPhone 11 Pro',
      'iPhone12,5': 'iPhone 11 Pro Max',
      // iPhone XS/XR Series (2018)
      'iPhone11,2': 'iPhone XS',
      'iPhone11,4': 'iPhone XS Max',
      'iPhone11,6': 'iPhone XS Max',
      'iPhone11,8': 'iPhone XR',
      // iPhone X (2017)
      'iPhone10,3': 'iPhone X',
      'iPhone10,6': 'iPhone X',
      // iPhone 8 Series (2017)
      'iPhone10,1': 'iPhone 8',
      'iPhone10,4': 'iPhone 8',
      'iPhone10,2': 'iPhone 8 Plus',
      'iPhone10,5': 'iPhone 8 Plus',
      // iPhone 7 Series (2016)
      'iPhone9,1': 'iPhone 7',
      'iPhone9,3': 'iPhone 7',
      'iPhone9,2': 'iPhone 7 Plus',
      'iPhone9,4': 'iPhone 7 Plus',
      // iPhone SE Series
      'iPhone14,6': 'iPhone SE (3rd Gen)',
      'iPhone12,8': 'iPhone SE (2nd Gen)',
      'iPhone8,4': 'iPhone SE (1st Gen)',
      // iPad Pro models
      'iPad16,3': 'iPad Pro 11" (M4)',
      'iPad16,4': 'iPad Pro 11" (M4)',
      'iPad16,5': 'iPad Pro 13" (M4)',
      'iPad16,6': 'iPad Pro 13" (M4)',
      'iPad14,3': 'iPad Pro 11" (4th Gen)',
      'iPad14,4': 'iPad Pro 11" (4th Gen)',
      'iPad14,5': 'iPad Pro 12.9" (6th Gen)',
      'iPad14,6': 'iPad Pro 12.9" (6th Gen)',
      'iPad13,4': 'iPad Pro 11" (3rd Gen)',
      'iPad13,5': 'iPad Pro 11" (3rd Gen)',
      'iPad13,6': 'iPad Pro 11" (3rd Gen)',
      'iPad13,7': 'iPad Pro 11" (3rd Gen)',
      'iPad13,8': 'iPad Pro 12.9" (5th Gen)',
      'iPad13,9': 'iPad Pro 12.9" (5th Gen)',
      'iPad13,10': 'iPad Pro 12.9" (5th Gen)',
      'iPad13,11': 'iPad Pro 12.9" (5th Gen)',
      // iPad Air models
      'iPad14,8': 'iPad Air (M2) 11"',
      'iPad14,9': 'iPad Air (M2) 11"',
      'iPad14,10': 'iPad Air (M2) 13"',
      'iPad14,11': 'iPad Air (M2) 13"',
      'iPad13,16': 'iPad Air (5th Gen)',
      'iPad13,17': 'iPad Air (5th Gen)',
      'iPad13,1': 'iPad Air (4th Gen)',
      'iPad13,2': 'iPad Air (4th Gen)',
      // iPad mini models
      'iPad14,1': 'iPad mini (6th Gen)',
      'iPad14,2': 'iPad mini (6th Gen)',
      'iPad11,1': 'iPad mini (5th Gen)',
      'iPad11,2': 'iPad mini (5th Gen)',
      // iPad models
      'iPad13,18': 'iPad (10th Gen)',
      'iPad13,19': 'iPad (10th Gen)',
      'iPad12,1': 'iPad (9th Gen)',
      'iPad12,2': 'iPad (9th Gen)',
    };

    return iphoneModels[machineId];
  }

  /// Check if user is already logged in on another device by UID
  /// This is the most reliable check as it uses the exact user document
  /// SINGLE DEVICE LOGIN: STRICT CHECK - no lenient timeout exceptions
  Future<ActiveDeviceInfo?> _checkExistingSessionByUid(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) {
        return null; // New user, no existing session
      }

      final userData = doc.data();
      if (userData == null) return null;

      final activeToken = userData['activeDeviceToken'] as String?;

      // If no token exists, no active session
      if (activeToken == null || activeToken.isEmpty) {
        // ignore: avoid_print
        print('[SessionCheck] No active token found - allowing login');
        return null; // No active session
      }

      // Check if local token matches server token
      // If they match, it means same device is trying to re-login (allow it)
      final localToken = await _getDeviceToken();
      if (localToken != null && localToken == activeToken) {
        // ignore: avoid_print
        print('[SessionCheck] Same device token - allowing login');
        return null; // Same device, allow login
      }

      // STRICT SINGLE DEVICE: If token exists and doesn't match = BLOCK LOGIN
      // Do NOT check inactivity, lastSeen, or isOnline status
      // This ensures ONLY the device with matching token can login

      // ignore: avoid_print
      print('[SessionCheck]   ACTIVE SESSION BLOCKED');
      print('[SessionCheck] Server token: ${activeToken.substring(0, 6)}...');
      print(
        '[SessionCheck] Local token:  ${localToken?.substring(0, 6) ?? 'NULL'}...',
      );
      print('[SessionCheck] Active session found on another device');
      return ActiveDeviceInfo.fromMap(userData);
    } catch (e) {
      // ignore: avoid_print
      print('[SessionCheck]   ERROR during session check: $e');
      // CRITICAL: On error, BLOCK login (don't allow)
      // This prevents bypass attacks where Firestore errors allow multiple logins
      throw Exception('[SessionCheck] Failed to verify device session: $e');
    }
  }

  /// Check if user is already logged in on another device by email
  /// Returns ActiveDeviceInfo if logged in elsewhere, null if not
  /// If excludeCurrentDevice is true, it will check if local token matches server token
  /// and return null if they match (meaning same device is trying to re-login)
  Future<ActiveDeviceInfo?> checkExistingSession(
    String email, {
    bool excludeCurrentDevice = false,
  }) async {
    try {
      // Normalize email - trim and lowercase
      final normalizedEmail = email.trim().toLowerCase();

      // Query users collection by email to get active session info
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .orderBy('uid')
          .limit(1)
          .get();

      // Also try with original email (in case stored with different case)
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .orderBy('uid')
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        return null; // New user, no existing session
      }

      final userData = querySnapshot.docs.first.data();
      final activeToken = userData['activeDeviceToken'] as String?;

      if (activeToken == null || activeToken.isEmpty) {
        return null; // No active session
      }

      // If excludeCurrentDevice is true, check if local token matches server token
      // If they match, it means same device is trying to re-login (allow it)
      if (excludeCurrentDevice) {
        final localToken = await _getDeviceToken();
        if (localToken != null && localToken == activeToken) {
          return null; // Same device, allow login
        }
      }

      // There's an active session on another device
      return ActiveDeviceInfo.fromMap(userData);
    } catch (e) {
      return null; // On error, allow login
    }
  }

  /// Check if user is already logged in on another device by phone number
  /// If excludeCurrentDevice is true, it will check if local token matches server token
  /// and return null if they match (meaning same device is trying to re-login)
  Future<ActiveDeviceInfo?> checkExistingSessionByPhone(
    String phoneNumber, {
    bool excludeCurrentDevice = false,
  }) async {
    try {
      // Normalize phone number - remove spaces, dashes
      final normalizedPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Create list of phone formats to try
      final phoneFormats = <String>[normalizedPhone];

      // Add format without + if it has +
      if (normalizedPhone.startsWith('+')) {
        phoneFormats.add(normalizedPhone.substring(1));
      } else {
        // Add format with + if it doesn't have
        phoneFormats.add('+$normalizedPhone');
      }

      // For Indian numbers, also try with/without 91 prefix
      if (normalizedPhone.startsWith('+91')) {
        phoneFormats.add(normalizedPhone.substring(3)); // Remove +91
        phoneFormats.add('91${normalizedPhone.substring(3)}'); // 91XXXXXXXXXX
      } else if (normalizedPhone.startsWith('91') &&
          normalizedPhone.length > 10) {
        phoneFormats.add('+$normalizedPhone'); // +91XXXXXXXXXX
        phoneFormats.add(normalizedPhone.substring(2)); // Just the number
      }

      QuerySnapshot<Map<String, dynamic>>? querySnapshot;

      // Try all phone formats
      for (final format in phoneFormats) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: format)
            .orderBy('uid')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          break; // Found user, stop searching
        }
      }

      if (querySnapshot == null || querySnapshot.docs.isEmpty) {
        return null;
      }

      final userData = querySnapshot.docs.first.data();
      final activeToken = userData['activeDeviceToken'] as String?;

      if (activeToken == null || activeToken.isEmpty) {
        return null; // No active session
      }

      // If excludeCurrentDevice is true, check if local token matches server token
      // If they match, it means same device is trying to re-login (allow it)
      if (excludeCurrentDevice) {
        final localToken = await _getDeviceToken();
        if (localToken != null && localToken == activeToken) {
          return null; // Same device, allow login
        }
      }

      // There's an active session on another device
      return ActiveDeviceInfo.fromMap(userData);
    } catch (e) {
      return null; // On error, allow login
    }
  }
}
