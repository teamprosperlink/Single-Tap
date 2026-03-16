import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart' show AuthService;
import '../../res/config/app_colors.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../widgets/common widgets/country_code_picker_sheet.dart';
import '../../widgets/common widgets/device_login_dialog.dart';
import '../home/main_navigation_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.accountType = 'Personal Account'});

  final String accountType;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUpMode = false;
  bool _acceptTerms = false;

  // Store login data when switching to signup
  String _savedLoginEmail = '';
  String _savedLoginPassword = '';

  // Phone OTP verification state
  bool _isOtpSent = false;
  String? _verificationId;
  final _otpController = TextEditingController();

  // Store user ID for device logout
  String? _pendingUserId;

  // Account type tab (0 = Personal, 1 = Business)
  int _selectedTabIndex = 0;

  String get _currentAccountType =>
      _selectedTabIndex == 0 ? 'Personal Account' : 'Business Account';

  // Country code data
  String _selectedCountryCode = '+91';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'country': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'country': 'UK', 'flag': '🇬🇧'},
    {'code': '+61', 'country': 'Australia', 'flag': '🇦🇺'},
    {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+65', 'country': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+60', 'country': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+49', 'country': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'country': 'France', 'flag': '🇫🇷'},
    {'code': '+39', 'country': 'Italy', 'flag': '🇮🇹'},
    {'code': '+81', 'country': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'country': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+86', 'country': 'China', 'flag': '🇨🇳'},
    {'code': '+55', 'country': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'country': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+27', 'country': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'country': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+92', 'country': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'country': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+977', 'country': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+94', 'country': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+63', 'country': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+62', 'country': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+66', 'country': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+84', 'country': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+7', 'country': 'Russia', 'flag': '🇷🇺'},
    {'code': '+34', 'country': 'Spain', 'flag': '🇪🇸'},
    {'code': '+31', 'country': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+46', 'country': 'Sweden', 'flag': '🇸🇪'},
  ];

  // Individual OTP box controllers
  final List<TextEditingController> _otpBoxControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
    _fadeController.forward();

    _emailOrPhoneController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    // Rebuild UI when input changes to show/hide password field
    setState(() {});
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _signupPhoneController.dispose();
    _otpController.dispose();
    for (var controller in _otpBoxControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleSignUpMode() {
    final wasSignUpMode = _isSignUpMode;

    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _isOtpSent = false;
      _verificationId = null;
      _otpController.clear();
      _clearOtpBoxes();

      if (!wasSignUpMode && _isSignUpMode) {
        // Login -> SignUp: Save login data, then clear fields for fresh signup
        _savedLoginEmail = _emailOrPhoneController.text;
        _savedLoginPassword = _passwordController.text;
        _emailOrPhoneController.clear();
        _passwordController.clear();
        _signupPhoneController.clear();
        _acceptTerms = false;
      } else if (wasSignUpMode && !_isSignUpMode) {
        // SignUp -> Login: Restore saved login data
        _emailOrPhoneController.text = _savedLoginEmail;
        _passwordController.text = _savedLoginPassword;
      }
    });
    _animationController.reset();
    _animationController.forward();
  }

  // Check if input is phone number (for validation - 6-15 digits)
  bool _isPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Check for 6-15 digit phone numbers
    return RegExp(r'^[0-9]{6,15}$').hasMatch(cleaned);
  }

  // Check if input starts with a digit (to show country code picker)
  bool get _startsWithDigit {
    final input = _emailOrPhoneController.text.trim();
    if (input.isEmpty) return false;
    return RegExp(r'^[0-9]').hasMatch(input);
  }

  // Check current input type for UI updates
  bool get _isCurrentInputPhone {
    final input = _emailOrPhoneController.text.trim();
    return _isPhoneNumber(input);
  }

  // Get clean phone number
  String _getCleanPhoneNumber(String input) {
    return input.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CountryCodePickerSheet(
          countryCodes: _countryCodes,
          selectedCountryCode: _selectedCountryCode,
          onSelect: (code, flag) {
            setState(() {
              _selectedCountryCode = code;
            });
          },
        );
      },
    );
  }

  Future<void> _sendPhoneOTP() async {
    final input = _emailOrPhoneController.text.trim();
    final phone = _getCleanPhoneNumber(input);
    if (phone.isEmpty || phone.length < 6 || phone.length > 15) {
      _showErrorSnackBar('Please enter a valid phone number');
      return;
    }

    final fullPhoneNumber = '$_selectedCountryCode$phone';

    setState(() {
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    _authService.sendPhoneOTP(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          // Navigate to OTP verification screen
          _navigateToOtpScreen(phone, verificationId);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          HapticFeedback.heavyImpact();
          _showErrorSnackBar(error);
        }
      },
      onAutoVerify: (credential) async {
        // Auto verification on Android
        try {
          final user = await _authService.verifyPhoneOTP(
            verificationId: _verificationId!,
            otp: credential.smsCode ?? '',
          );
          if (user != null && mounted) {
            _showSuccessSnackBar('Phone verified automatically!');
            await _navigateAfterAuth(isNewUser: true);
          }
        } catch (e) {
          // Auto-verify failed, user will enter OTP manually
        }
      },
    );
  }

  Future<void> _navigateToOtpScreen(String phone, String verificationId) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: phone,
          countryCode: _selectedCountryCode,
          verificationId: verificationId,
          accountType: _currentAccountType,
        ),
      ),
    );

    if (result != null && mounted) {
      if (result['success'] == true) {
        // OTP verified successfully, navigate to home
        await _navigateAfterAuth(isNewUser: true);
      } else if (result['error'] == 'ALREADY_LOGGED_IN') {
        // Handle device already logged in
        final deviceName = result['device'] as String? ?? 'Another Device';
        _pendingUserId = _authService.currentUser?.uid;
        await _showDeviceLoginDialog(deviceName);
      }
    }
  }

  Future<void> _verifyPhoneOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showErrorSnackBar('Please enter 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      _showErrorSnackBar('Please request OTP first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.verifyPhoneOTP(
        verificationId: _verificationId!,
        otp: otp,
      );

      if (user != null && mounted) {
        HapticFeedback.lightImpact();
        _showSuccessSnackBar('Phone verified successfully!');
        await _navigateAfterAuth(isNewUser: true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        print('[LoginScreen] ===== OTP VERIFICATION ERROR =====');
        print('[LoginScreen] Error: $errorMsg');
        print(
          '[LoginScreen] Contains ALREADY_LOGGED_IN: ${errorMsg.contains('ALREADY_LOGGED_IN')}',
        );
        print('[LoginScreen] =====================================');

        if (errorMsg.contains('ALREADY_LOGGED_IN')) {
          // Extract device name and user ID from error message
          // Format: ALREADY_LOGGED_IN:Device Name:userIdToPass
          final parts = errorMsg.split(':');
          String deviceName = 'Another Device';
          String? userId;

          if (parts.length >= 2) {
            deviceName = parts.sublist(1, parts.length - 1).join(':').trim();
          }
          if (parts.length >= 3) {
            userId = parts.last.trim();
          }

          print('[LoginScreen] Device Name: $deviceName');
          print('[LoginScreen] User ID: $userId');

          // Store the user ID for logout
          _pendingUserId = userId ?? _authService.currentUser?.uid;

          // Show device login dialog to user - let them decide
          print('[LoginScreen]  Showing device login dialog...');
          await _showDeviceLoginDialog(deviceName);
        } else {
          print(
            '[LoginScreen]   Not ALREADY_LOGGED_IN error, showing error snackbar',
          );
          HapticFeedback.heavyImpact();
          _showErrorSnackBar(errorMsg);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetOtpState() {
    setState(() {
      _isOtpSent = false;
      _verificationId = null;
      _otpController.clear();
      _clearOtpBoxes();
    });
  }

  Future<void> _handleAuth() async {
    final input = _emailOrPhoneController.text.trim();

    // In LOGIN mode with phone number - send OTP
    // In SIGNUP mode - always use email+password flow (even for phone numbers as username)
    if (_isPhoneNumber(input) && !_isSignUpMode) {
      // Set pending account type for phone registration
      _authService.setPendingAccountType(_currentAccountType);
      await _sendPhoneOTP();
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Check terms acceptance for signup
      if (_isSignUpMode && !_acceptTerms) {
        _showErrorSnackBar(
          'Please accept the Terms of Service and Privacy Policy to continue',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // NOTE: Pre-login session check removed - it can cause false positives
        // when user has logged out but Firestore still has stale token.
        // The reliable check happens AFTER Firebase auth in signInWithEmail()
        // using UID-based check which compares local token with server token.

        final user = _isSignUpMode
            ? await _authService.signUpWithEmail(
                input,
                _passwordController.text,
                accountType: _currentAccountType,
              )
            : await _authService.signInWithEmail(
                input,
                _passwordController.text,
              );

        if (user != null && mounted) {
          // Save phone number to user profile after signup
          if (_isSignUpMode && _signupPhoneController.text.trim().isNotEmpty) {
            final phone = '$_selectedCountryCode${_signupPhoneController.text.trim()}';
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'phone': phone}, SetOptions(merge: true));
          }

          HapticFeedback.lightImpact();
          _showSuccessSnackBar(
            _isSignUpMode ? 'Account created successfully!' : 'Welcome back!',
          );
          // Navigate based on account type for signup
          await _navigateAfterAuth(isNewUser: _isSignUpMode);
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = e.toString().replaceAll('Exception: ', '');
          print('[LoginScreen] ===== EMAIL/PASSWORD AUTH ERROR =====');
          print('[LoginScreen] Error: $errorMsg');
          print(
            '[LoginScreen] Contains ALREADY_LOGGED_IN: ${errorMsg.contains('ALREADY_LOGGED_IN')}',
          );
          print('[LoginScreen] ========================================');

          if (errorMsg.contains('ALREADY_LOGGED_IN')) {
            // Extract device name and user ID from error message
            // Format: ALREADY_LOGGED_IN:Device Name:userIdToPass
            final parts = errorMsg.split(':');
            String deviceName = 'Another Device';
            String? userId;

            if (parts.length >= 2) {
              deviceName = parts.sublist(1, parts.length - 1).join(':').trim();
            }
            if (parts.length >= 3) {
              userId = parts.last.trim();
            }

            print('[LoginScreen] Device Name: $deviceName');
            print('[LoginScreen] User ID: $userId');

            // Store the user ID for logout
            _pendingUserId = userId ?? _authService.currentUser?.uid;

            // Show device login dialog to user - let them decide
            print('[LoginScreen]  Showing device login dialog...');
            await _showDeviceLoginDialog(deviceName);
          } else {
            print(
              '[LoginScreen]   Not ALREADY_LOGGED_IN error, showing error snackbar',
            );
            HapticFeedback.heavyImpact();
            _showErrorSnackBar(errorMsg);
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Navigate after authentication based on account type
  Future<void> _navigateAfterAuth({bool isNewUser = false}) async {
    if (!mounted) return;

    // Get account type - first check _currentAccountType (for new signups), then check stored accountType
    String accountType = _currentAccountType.toLowerCase();

    // Also check the stored account type from Firestore for existing users
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final storedAccountType =
            doc.data()?['accountType']?.toString().toLowerCase() ?? '';
        // Use stored account type if widget account type is empty or "personal"
        if (storedAccountType.isNotEmpty &&
            (accountType.isEmpty ||
                accountType == 'personal' ||
                accountType.contains('personal'))) {
          accountType = storedAccountType;
        }
      }
    } catch (e) {
      // Error checking stored account type
    }

    try {
      // Go to main navigation with account type
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              MainNavigationScreen(loginAccountType: _currentAccountType),
        ),
        (route) => false,
      );
    } catch (e) {
      // Fallback: try to navigate to main screen anyway
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle(
        accountType: _currentAccountType,
      );

      if (user != null && mounted) {
        HapticFeedback.lightImpact();
        _showSuccessSnackBar('Welcome, ${user.displayName ?? 'User'}!');
        // Navigate based on account type
        await _navigateAfterAuth(isNewUser: true);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        print('[LoginScreen] ===== GOOGLE SIGN-IN ERROR =====');
        print('[LoginScreen] Error: $errorMsg');
        print(
          '[LoginScreen] Contains ALREADY_LOGGED_IN: ${errorMsg.contains('ALREADY_LOGGED_IN')}',
        );
        print('[LoginScreen] ======================================');

        if (errorMsg.contains('ALREADY_LOGGED_IN')) {
          // Extract device name and user ID from error message
          // Format: ALREADY_LOGGED_IN:Device Name:userIdToPass
          final parts = errorMsg.split(':');
          String deviceName = 'Another Device';
          String? userId;

          if (parts.length >= 2) {
            deviceName = parts.sublist(1, parts.length - 1).join(':').trim();
          }
          if (parts.length >= 3) {
            userId = parts.last.trim();
          }

          print('[LoginScreen] Device Name: $deviceName');
          print('[LoginScreen] User ID: $userId');

          // Store the user ID for logout
          _pendingUserId = userId ?? _authService.currentUser?.uid;

          // Show device login dialog to user - let them decide
          print('[LoginScreen]  Showing device login dialog...');
          await _showDeviceLoginDialog(deviceName);
        } else {
          print(
            '[LoginScreen]   Not ALREADY_LOGGED_IN error, showing error snackbar',
          );
          HapticFeedback.heavyImpact();
          _showErrorSnackBar(errorMsg);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  /// Show device login dialog when another device is detected
  /// Gives user the option to logout the other device or stay logged in on both
  /// Returns a Future that completes when the user makes a choice
  Future<void> _showDeviceLoginDialog(String deviceName) async {
    print('[LoginScreen]  _showDeviceLoginDialog CALLED');
    print('[LoginScreen]  Device Name: $deviceName');
    print('[LoginScreen]  Context mounted: $mounted');
    print('[LoginScreen]  About to call showDialog...');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        print('[LoginScreen]  Dialog builder called');
        return DeviceLoginDialog(
          deviceName: deviceName,
          // Option 1: User clicks "Logout Other Device"
          onLogoutOtherDevice: () async {
            try {
              print(
                '[LoginScreen] Logout other device - pending user ID: $_pendingUserId',
              );

              // CRITICAL: Wait for listener to start before calling logoutFromOtherDevices
              // The listener needs time to initialize:
              // 1. Device A auth state stream fires (500ms)
              // 2. initializeServices() runs (300ms)
              // 3. _startDeviceSessionMonitoring() creates listener (200ms)
              // 4. _listenerReady = true (100ms)
              // 5. First snapshot arrives and is processed (500ms)
              // Total: ~1.6 seconds minimum for safety
              // Extended to 4+ seconds to ensure listener is FULLY ready and processing snapshots
              print(
                '[LoginScreen] Waiting 4.5 seconds for listener to fully initialize and process snapshots...',
              );
              await Future.delayed(const Duration(milliseconds: 4500));
              print(
                '[LoginScreen] Listener should be fully initialized now, proceeding with logout',
              );

              // Logout from other devices and keep current device logged in
              await _authService.logoutFromOtherDevices(userId: _pendingUserId);

              // CRITICAL: Wait for old device to actually logout before proceeding
              // This ensures only one device is logged in at a time
              print('[LoginScreen]  Waiting for old device to logout...');
              final oldDeviceLoggedOut = await _authService
                  .waitForOldDeviceLogout(userId: _pendingUserId);
              if (oldDeviceLoggedOut) {
                print(
                  '[LoginScreen]   Old device confirmed logged out, proceeding with Device B login',
                );
              } else {
                print(
                  '[LoginScreen]   Timeout waiting for old device logout, proceeding anyway',
                );
              }

              // CRITICAL: Now that old device is logged out, save Device B's session
              // This was deferred from the initial login because device conflict existed
              // logoutFromOtherDevices STEP 2 already saved the token, but verify it's there
              print(
                '[LoginScreen]  Verifying Device B session saved to Firestore...',
              );
              try {
                await _authService.saveCurrentDeviceSession();
              } catch (e) {
                print('[LoginScreen]   Error verifying device session: $e');
              }

              // Close dialog - use mounted check before accessing context
              // The dialog context may not be valid after long async operations
              if (mounted && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              // Wait a moment for Firestore to sync
              await Future.delayed(const Duration(milliseconds: 300));

              // Navigate to main app - use the screen's context (self) for navigation
              if (mounted) {
                await _navigateAfterAuth(isNewUser: false);
              }
            } catch (e) {
              if (mounted) {
                HapticFeedback.heavyImpact();
                _showErrorSnackBar(
                  'Failed to logout from other device: ${e.toString()}',
                );
              }
            }
          },
          // Option 2: User clicks "Stay Logged In" - Device B stays logged in without logging out Device A
          onCancel: () async {
            try {
              print(
                '[LoginScreen] User chose to stay logged in on this device - both devices logged in',
              );

              // CRITICAL: Device B needs to be saved to Firestore
              // Device A stays logged in, Device B is NEW active device
              // Actually, Device B shouldn't take over - keep Device A as active
              // So Device B is logged in Firebase but NOT the active device in Firestore
              // This way both devices are logged in at Firebase level
              print(
                '[LoginScreen]  Saving Device B session to Firestore (both devices logged in)...',
              );
              try {
                await _authService.saveCurrentDeviceSession();
              } catch (e) {
                print('[LoginScreen]   Error saving device session: $e');
              }

              if (mounted) {
                await _navigateAfterAuth(isNewUser: false);
              }
            } catch (e) {
              if (mounted) {
                HapticFeedback.heavyImpact();
                _showErrorSnackBar('Error: ${e.toString()}');
              }
            }
          },
        );
      },
    );
    print('[LoginScreen]  showDialog completed');
  }

  void _showSuccessSnackBar(String message) {
    SnackBarHelper.showSuccess(context, message);
  }

  void _showErrorSnackBar(String message) {
    SnackBarHelper.showError(context, message);
  }

  void _onOtpBoxChanged(String value, int index) {
    // Update UI
    setState(() {});

    // Move to next box when digit entered
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Move to previous box on backspace when empty
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    // Update the main OTP controller with combined value
    String otp = _otpBoxControllers.map((c) => c.text).join();
    _otpController.text = otp;

    // Auto-verify when all 6 digits entered
    if (otp.length == 6) {
      // Hide keyboard
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isSignUpMode ? 'Sign Up' : 'Sign In',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
          ),
        ),
      ),
      extendBody: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Center(child: _buildHeader()),
                  const SizedBox(height: 32),
                  _buildAccountTabs(),
                  const SizedBox(height: 6),
                  _buildForm(),
                  // Show OTP boxes if phone OTP was sent
                  if (_isOtpSent) ...[
                    const SizedBox(height: 16),
                    _buildOtpSection(),
                  ],
                  if (_isSignUpMode && !_isOtpSent) ...[
                    const SizedBox(height: 16),
                    _buildRememberMeAndForgot(),
                  ],
                  const SizedBox(height: 28),
                  _buildAuthButton(),
                  const SizedBox(height: 12),
                  _buildToggleModeButton(),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSocialLogin(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Welcome to Single Tap',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'You can need, everything in one place',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAccountTabs() {
    final tabs = ['Personal', 'Business'];
    final descriptions = [
      'Use personal to explore, connect, and share as an individual user',
      'Use business to list services, manage clients, and grow your brand',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar - full width with bottom line
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = _selectedTabIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        // Description
        Text(
          descriptions[_selectedTabIndex],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  // Reusable field input decoration
  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 14,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.15),
      errorStyle: const TextStyle(
        height: 0.8,
        color: Colors.redAccent,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildForm() {
    if (_isSignUpMode) {
      return _buildSignupForm();
    }
    return _buildLoginForm();
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mobile Number field
          _buildFieldLabel('Mobile Number'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country Code Picker - always visible in signup
              Container(
                height: 52,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showCountryCodePicker,
                    borderRadius: BorderRadius.circular(14),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCountryCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Phone input
              Expanded(
                child: TextFormField(
                  controller: _signupPhoneController,
                  keyboardType: TextInputType.phone,
                  cursorColor: Colors.white,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: _fieldDecoration(hintText: 'Enter phone number'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!_isPhoneNumber(value)) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Email address field
          _buildFieldLabel('Email address'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailOrPhoneController,
            keyboardType: TextInputType.emailAddress,
            cursorColor: Colors.white,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration(hintText: 'Enter email address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              final isEmail = RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value);
              if (!isEmail) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password field
          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            cursorColor: Colors.white,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleAuth(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration(
              hintText: 'Enter your password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Email or Mobile" label above field
          _buildFieldLabel(_startsWithDigit ? 'Phone Number' : 'Email or Mobile'),
          const SizedBox(height: 8),

          // Email or Phone field with country code picker
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country Code Picker - only show when input starts with a digit
              if (_startsWithDigit)
                Container(
                  height: 52,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isOtpSent ? null : _showCountryCodePicker,
                      borderRadius: BorderRadius.circular(14),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountryCode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Email/Phone input field
              Expanded(
                child: TextFormField(
                  controller: _emailOrPhoneController,
                  keyboardType: _isCurrentInputPhone
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  cursorColor: Colors.white,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleAuth(),
                  enabled: !_isOtpSent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: _fieldDecoration(hintText: 'Enter your email or mobile'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email or mobile number';
                    }
                    final isEmail = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value);
                    final isPhone = _isPhoneNumber(value);
                    if (!isEmail && !isPhone) {
                      return 'Please enter a valid email or mobile number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          // Password field - always show, hide only when phone number entered
          if (!_isOtpSent && !_startsWithDigit) ...[
            const SizedBox(height: 16),
            _buildFieldLabel('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: Colors.white,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleAuth(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              decoration: _fieldDecoration(
                hintText: 'Enter your password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (_isCurrentInputPhone) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _isLoading ? null : _forgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.iosBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      children: [
        _buildOtpBoxes(),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  _clearOtpBoxes();
                  _sendPhoneOTP();
                },
          child: const Text(
            'Resend OTP',
            style: TextStyle(
              color: Color.fromARGB(214, 106, 183, 255),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _resetOtpState,
          child: const Text(
            'Change Number',
            style: TextStyle(
              color: Color.fromARGB(255, 240, 237, 237),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeAndForgot() {
    // Show terms checkbox for signup mode
    if (_isSignUpMode) {
      return Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _acceptTerms,
              onChanged: (value) {
                setState(() {
                  _acceptTerms = value ?? false;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.green;
                }
                return Colors.grey;
              }),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'I agree to the Terms of Service and Privacy Policy',
              style: TextStyle(
                color: Color.fromARGB(255, 240, 237, 237),
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAuthButton() {
    // Determine button text and action based on state
    String buttonText;
    VoidCallback? onPressed;
    bool showLoader = false;

    if (_isOtpSent) {
      // OTP screen - show Verify OTP button
      buttonText = 'Verify OTP';
      onPressed = _isLoading ? null : _verifyPhoneOTP;
      showLoader = _isLoading;
    } else if (_isCurrentInputPhone && !_isSignUpMode) {
      // Phone number entered in LOGIN mode - show Send OTP button
      buttonText = 'Send OTP';
      onPressed = _isLoading ? null : _sendPhoneOTP;
      showLoader = _isLoading;
    } else {
      // Email entered OR Sign Up mode (with email or phone) - show Sign In / Sign Up button
      buttonText = _isSignUpMode ? 'Sign Up' : 'Sign In';
      onPressed = _isLoading ? null : _handleAuth;
      showLoader = _isLoading;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF2563EB),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showLoader
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToggleModeButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUpMode
              ? 'Already have an account? '
              : "Don't have an account? ",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: _isLoading ? null : _toggleSignUpMode,
          child: Text(
            _isSignUpMode ? 'Sign In' : 'Sign Up',
            style: const TextStyle(
              color: AppColors.iosBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.2),
            thickness: 0.8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.2),
            thickness: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Google icon
        GestureDetector(
          onTap: _isLoading ? null : _signInWithGoogle,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Apple icon
        GestureDetector(
          onTap: _isLoading ? null : () {
            // Apple sign-in placeholder
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.apple,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBoxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter 6-digit OTP',
          style: TextStyle(
            color: Color.fromARGB(255, 240, 237, 237),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate box size based on available width
            // 6 boxes + 5 gaps (8px each) = total width
            final availableWidth = constraints.maxWidth;
            const totalGapWidth = 5 * 8.0; // 5 gaps of 8px each
            final boxWidth = ((availableWidth - totalGapWidth) / 6).clamp(
              36.0,
              48.0,
            );
            final boxHeight = boxWidth * 1.1; // Slightly taller than wide

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < 6; i++)
                  _buildSingleOtpBox(i, boxWidth, boxHeight),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSingleOtpBox(int index, double boxWidth, double boxHeight) {
    final bool hasFocus = _otpFocusNodes[index].hasFocus;
    final bool hasValue = _otpBoxControllers[index].text.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Focus on this box when tapped
          _otpFocusNodes[index].requestFocus();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withValues(alpha: 0.3),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            color: hasFocus
                ? Colors.white.withValues(alpha: 0.2)
                : hasValue
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFocus
                  ? Colors.white
                  : hasValue
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.3),
              width: hasFocus ? 2 : 1.5,
            ),
            boxShadow: hasFocus
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _otpBoxControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: boxWidth * 0.45, // Dynamic font size based on box width
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            showCursor: true,
            cursorColor: Colors.white,
            cursorWidth: 2,
            cursorHeight: boxHeight * 0.5,
            enableSuggestions: false,
            autocorrect: false,
            enableInteractiveSelection: false,
            contextMenuBuilder: null,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
            ),
            onChanged: (value) {
              _onOtpBoxChanged(value, index);
            },
          ),
        ),
      ),
    );
  }

  void _clearOtpBoxes() {
    for (var controller in _otpBoxControllers) {
      controller.clear();
    }
    _otpController.clear();
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }
}
