import 'package:flutter/material.dart';
import 'package:supper/main.dart';
import 'dart:async';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showHeavyLayers = false;

  @override
  void initState() {
    super.initState();

    // Animation controller for floating & rotation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Defer heavy layers (background image, patterns) until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showHeavyLayers = true);
    });

    // Navigate after splash time
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for minimum splash time (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    // Navigate after splash
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.splashDark3,
      body: Stack(
        children: [
          // Gradient Background - always visible immediately (lightweight)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.splashGradient,
              ),
            ),
          ),

          // Image Background - deferred to avoid blocking first frame
          if (_showHeavyLayers)
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeBackgroundImage,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  // Show nothing while decoding (gradient visible underneath)
                  return const SizedBox.shrink();
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: AppColors.darkOverlay(),
            ),
          ),

          // Background circular elements - deferred
          if (_showHeavyLayers)
            CustomPaint(
              size: screenSize,
              painter: _BackgroundPatternPainter(color: Colors.white),
            ),

          // Centered Logo - uses simple container instead of expensive BackdropFilter
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final value = _animationController.value;
                  final scale = 1.0 + (value * 0.05);

                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: screenSize.height * 0.28,
                  height: screenSize.height * 0.28,
                  constraints: const BoxConstraints(
                    maxWidth: 280,
                    maxHeight: 280,
                    minWidth: 180,
                    minHeight: 180,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.glassBackgroundDark(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.glassBorder(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.whiteAlpha(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      AppAssets.logoPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.apps_rounded,
                          size: 80,
                          color: Colors.white70,
                        );
                      },
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
}

// Background pattern painter
class _BackgroundPatternPainter extends CustomPainter {
  final Color color;
  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Big circles with reduced opacity for video background
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 200, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 120, paint);

    // Add border circles
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), 80, borderPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 60, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
