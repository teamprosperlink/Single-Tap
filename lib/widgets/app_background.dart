import 'package:flutter/material.dart';
import '../res/config/app_colors.dart';
import 'floating_particles.dart';

/// A reusable background widget that matches the home screen's beautiful background.
/// Use this widget to wrap your screen content for a consistent look across the app.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles;
  final bool showBlur;
  final double blurAmount;
  final double overlayOpacity;
  final int particleCount;

  const AppBackground({
    super.key,
    required this.child,
    this.showParticles = true,
    this.showBlur = false,
    this.blurAmount = 12,
    this.overlayOpacity = 0.3,
    this.particleCount = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient Background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.splashGradient,
            ),
          ),
        ),

        // Floating particles (optional)
        if (showParticles)
          Positioned.fill(child: FloatingParticles(particleCount: particleCount)),

        // Main content
        child,
      ],
    );
  }
}
