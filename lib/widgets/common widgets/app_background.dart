import 'package:flutter/material.dart';
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Floating particles (optional)
          if (showParticles)
            Positioned.fill(
              child: FloatingParticles(particleCount: particleCount),
            ),

          // Main content
          child,
        ],
      ),
    );
  }
}
