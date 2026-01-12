import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart' show AuthService;
import '../../services/professional_service.dart';
import '../../services/business_service.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../widgets/country_code_picker_sheet.dart';
import '../../widgets/device_login_dialog.dart';
import '../home/main_navigation_screen.dart';
import '../professional/professional_setup_screen.dart';
import '../business/business_setup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.accountType});

  final String accountType;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUpMode = false;
  bool _acceptTerms = false;
  String _passwordStrength = ''; // ignore: unused_field, prefer_final_fields
  final Color _passwordStrengthColor = Colors.grey; // ignore: unused_field

  // Store login data when switching to signup
  String _savedLoginEmail = '';
  String _savedLoginPassword = '';

  // Phone OTP verification state
  bool _isOtpSent = false;
  String? _verificationId;
  final _otpController = TextEditingController();

  // Store user ID for device logout
  String? _pendingUserId;

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

    _passwordController.addListener(_checkPasswordStrength);
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

  void _checkPasswordStrength() {
    String password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
      });
      return;
    }

    // ignore: unused_local_variable
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;
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

    // Show loader on Send OTP button first
    setState(() {
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    // NOTE: Pre-login session check removed - it can cause false positives
    // when user has logged out but Firestore still has stale token.
    // The reliable check happens AFTER Firebase auth in verifyPhoneOTP()
    // using UID-based check which compares local token with server token.

    // Send OTP in background
    _authService.sendPhoneOTP(
      phoneNumber: fullPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOtpSent = true; // Now switch to OTP screen
            _verificationId = verificationId;
          });
          _showSuccessSnackBar('OTP sent to $fullPhoneNumber');
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOtpSent = false;
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

          // Store the user ID for logout
          _pendingUserId = userId ?? _authService.currentUser?.uid;
          _showDeviceLoginDialog(deviceName);
        } else {
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
      _authService.setPendingAccountType(widget.accountType);
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
                accountType: widget.accountType,
              )
            : await _authService.signInWithEmail(
                input,
                _passwordController.text,
              );

        if (user != null && mounted) {
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

            // Store the user ID for logout
            _pendingUserId = userId ?? _authService.currentUser?.uid;
            _showDeviceLoginDialog(deviceName);
          } else {
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

    // Get account type - first check widget.accountType (for new signups), then check stored accountType
    String accountType = widget.accountType.toLowerCase();

    // Also check the stored account type from Firestore for existing users
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final storedAccountType = doc.data()?['accountType']?.toString().toLowerCase() ?? '';
        // Use stored account type if widget account type is empty or "personal"
        if (storedAccountType.isNotEmpty &&
            (accountType.isEmpty || accountType == 'personal' || accountType.contains('personal'))) {
          accountType = storedAccountType;
        }
      }
    } catch (e) {
      // Error checking stored account type
    }

    try {
      // Check for Professional account
      if (accountType.contains('professional')) {
        final professionalService = ProfessionalService();
        final isSetupComplete = await professionalService.isProfessionalSetupComplete();

        if (!isSetupComplete) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const ProfessionalSetupScreen(),
            ),
            (route) => false,
          );
          return;
        }
      }

      // Check for Business account
      if (accountType.contains('business')) {
        final businessService = BusinessService();
        final isSetupComplete = await businessService.isBusinessSetupComplete();

        if (!isSetupComplete) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const BusinessSetupScreen(),
            ),
            (route) => false,
          );
          return;
        }
      }

      // Default: go to main navigation with account type
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(loginAccountType: widget.accountType),
        ),
        (route) => false,
      );
    } catch (e) {
      // Fallback: try to navigate to main screen anyway
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(),
          ),
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
        accountType: widget.accountType,
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

          // Store the user ID for logout
          _pendingUserId = userId ?? _authService.currentUser?.uid;
          _showDeviceLoginDialog(deviceName);
        } else {
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

  void _showDeviceLoginDialog(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DeviceLoginDialog(
        deviceName: deviceName,
        // Option 1: User clicks "Logout Other Device"
        onLogoutOtherDevice: () async {
          try {
            print('[LoginScreen] Logout other device - pending user ID: $_pendingUserId');

            // CRITICAL: Wait for listener to start before calling logoutFromOtherDevices
            // The listener needs time to initialize (500ms auth delay + listener setup)
            // If we call logoutFromOtherDevices() too early, the listener won't be ready
            // and won't properly handle the forceLogout signal
            // Extended to 2.5s to ensure we're well within protection window
            print('[LoginScreen] Waiting 2.5 seconds for listener to initialize...');
            await Future.delayed(const Duration(milliseconds: 2500));
            print('[LoginScreen] Listener should be initialized now, proceeding with logout');

            // Logout from other devices and keep current device logged in
            await _authService.logoutFromOtherDevices(userId: _pendingUserId);

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
              _showErrorSnackBar('Failed to logout from other device: ${e.toString()}');
            }
          }
        },
        // Option 2: User clicks "Stay Logged In" - Device B stays logged in without logging out Device A
        onCancel: () async {
          try {
            print('[LoginScreen] User chose to stay logged in on this device - navigating to main app');

            // Device B is already logged in (saved in auth_service)
            // Just navigate to main app without logging out Device A
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
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.greenAccent.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.redAccent.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      ),
    );
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
      body: Stack(
        children: [
          // Image Background (same as forgot password screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.splashGradient,
                  ),
                );
              },
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: AppColors.darkOverlay(alpha: 0.5),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 32),
                              _buildForm(),
                              // Show OTP boxes if phone OTP was sent
                              if (_isOtpSent) ...[
                                const SizedBox(height: 16),
                                _buildOtpSection(),
                              ],
                              if (!_isOtpSent) ...[
                                const SizedBox(height: 4),
                                _buildRememberMeAndForgot(),
                              ],
                              const SizedBox(height: 24),
                              _buildAuthButton(),
                              const SizedBox(height: 16),
                              _buildToggleModeButton(),
                              const SizedBox(height: 24),
                              _buildDivider(),
                              const SizedBox(height: 24),
                              _buildSocialLogin(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(
                _isSignUpMode ? Icons.person_add : Icons.lock_outline,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome Back\n${widget.accountType}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email or Phone field with country code picker
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country Code Picker - only show when input starts with a digit
              if (_startsWithDigit)
                Container(
                  height: 56,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isOtpSent ? null : _showCountryCodePicker,
                      borderRadius: BorderRadius.circular(16),
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
                  textInputAction: TextInputAction.next,
                  enabled: !_isOtpSent, // Disable when OTP is sent
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: _startsWithDigit
                        ? 'Phone Number'
                        : 'Email or Phone',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    hintText: _startsWithDigit
                        ? 'Enter phone number'
                        : 'Enter email or phone number',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    // Hide prefix icon when country code picker is shown to save space
                    prefixIcon: _startsWithDigit
                        ? null
                        : Icon(
                            Icons.person_outline,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),

                    // ---- Glassmorphism borders ----
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),

                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    errorStyle: const TextStyle(
                      height: 0.8,
                      color: Colors.redAccent,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: _startsWithDigit ? 16 : 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email or phone number';
                    }
                    // Check if it's a valid email or phone
                    final isEmail = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value);
                    final isPhone = _isPhoneNumber(value);
                    if (!isEmail && !isPhone) {
                      return 'Please enter a valid email or phone number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          // Password field - show for email login OR signup mode (NOT when OTP sent)
          // In signup mode, always show password field regardless of input type
          if (!_isOtpSent && (_isSignUpMode || !_isCurrentInputPhone)) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: Colors.white,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleAuth(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),

                // ---- Glassmorphism borders ----
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),

                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                errorStyle: const TextStyle(
                  height: 0.8,
                  color: Colors.redAccent,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                // Skip password validation for phone login (not signup)
                if (_isCurrentInputPhone && !_isSignUpMode) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (_isSignUpMode && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
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

    // Show only forgot password for login mode
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _forgotPassword,
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 240, 237, 237),
            ),
          ),
        ),
      ],
    );
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
      // Email entered OR Sign Up mode (with email or phone) - show Log In / Sign Up button
      buttonText = _isSignUpMode ? 'Sign Up' : 'Log In';
      onPressed = _isLoading ? null : _handleAuth;
      showLoader = _isLoading;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: showLoader
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleModeButton() {
    return TextButton(
      onPressed: _isLoading ? null : _toggleSignUpMode,
      child: RichText(
        text: TextSpan(
          text: _isSignUpMode
              ? 'Already have an account? '
              : "Don't have an account? ",
          style: const TextStyle(
            color: Color.fromARGB(255, 238, 237, 237),
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: _isSignUpMode ? 'Log In' : 'Sign Up',
              style: const TextStyle(
                color: Color.fromARGB(214, 106, 183, 255),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.g_mobiledata,
                  size: 38,
                  color: Color.fromARGB(255, 230, 226, 226),
                );
              },
            ),
            label: const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
      ),
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
