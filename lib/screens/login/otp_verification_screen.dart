import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../services/auth_service.dart' show AuthService;

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final String verificationId;
  final String accountType;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
    required this.verificationId,
    required this.accountType,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final _otpController = TextEditingController();
  final List<TextEditingController> _otpBoxControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _verificationId;

  // OTP timer
  Timer? _otpTimer;
  int _otpCountdown = 30;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startOtpTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    for (var controller in _otpBoxControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _otpTimer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpCountdown = 30;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _fullPhoneNumber => '${widget.countryCode}${widget.phoneNumber}';

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    _clearOtpBoxes();

    _authService.sendPhoneOTP(
      phoneNumber: _fullPhoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _showSuccess('OTP sent to $_fullPhoneNumber');
          _startOtpTimer();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          HapticFeedback.heavyImpact();
          _showError(error);
        }
      },
      onAutoVerify: (credential) async {
        try {
          final user = await _authService.verifyPhoneOTP(
            verificationId: _verificationId!,
            otp: credential.smsCode ?? '',
          );
          if (user != null && mounted) {
            _showSuccess('Phone verified automatically!');
            _navigateToHome();
          }
        } catch (_) {}
      },
    );
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showError('Please enter 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      _showError('Please request OTP first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.verifyPhoneOTP(
        verificationId: _verificationId!,
        otp: otp,
      );

      if (user != null && mounted) {
        HapticFeedback.lightImpact();
        _showSuccess('Phone verified successfully!');
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');

        if (errorMsg.contains('ALREADY_LOGGED_IN')) {
          final parts = errorMsg.split(':');
          String deviceName = 'Another Device';
          if (parts.length >= 2) {
            deviceName = parts.sublist(1, parts.length - 1).join(':').trim();
          }
          // Return to login screen with error info
          Navigator.pop(context, {'error': 'ALREADY_LOGGED_IN', 'device': deviceName});
        } else {
          HapticFeedback.heavyImpact();
          _showError(errorMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    // Return success to login screen which handles navigation
    Navigator.pop(context, {'success': true});
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

  void _onOtpBoxChanged(String value, int index) {
    setState(() {});

    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    String otp = _otpBoxControllers.map((c) => c.text).join();
    _otpController.text = otp;

    if (otp.length == 6) {
      FocusScope.of(context).unfocus();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackBarHelper.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    SnackBarHelper.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final String formattedTime =
        '${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')} Sec';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify your mobile number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Illustration
                Center(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white, Colors.transparent],
                        stops: [0.0, 0.75, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/Forgot Password.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Description text
                Text(
                  'we have sent a verification code to',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                // Phone number
                Text(
                  '${widget.countryCode} ${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // 6 OTP Boxes
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    const totalGapWidth = 5 * 10.0;
                    final boxWidth = ((availableWidth - totalGapWidth) / 6).clamp(40.0, 52.0);
                    final boxHeight = boxWidth * 1.1;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 0; i < 6; i++)
                          _buildSingleOtpBox(i, boxWidth, boxHeight),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Timer and Resend row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: _otpCountdown == 0 && !_isLoading ? _resendOTP : null,
                      child: Text(
                        'Resend OTP ?',
                        style: TextStyle(
                          fontSize: 14,
                          color: _otpCountdown == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
                // Push button toward bottom
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                // Verify OTP button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF007AFF),
                      disabledBackgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify OTP Login',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleOtpBox(int index, double boxWidth, double boxHeight) {
    final bool hasFocus = _otpFocusNodes[index].hasFocus;
    final bool hasValue = _otpBoxControllers[index].text.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
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
              fontSize: boxWidth * 0.45,
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
}
