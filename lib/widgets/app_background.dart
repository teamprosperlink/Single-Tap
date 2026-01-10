import 'dart:ui' show ImageFilter;
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
    return Stack(
      children: [
        // Image Background
        Positioned.fill(
          child: Image.asset(
            'assets/logo/home_background.webp',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey.shade900, Colors.black],
                  ),
                ),
              );
            },
          ),
        ),

        // Blur effect (optional)
        if (showBlur)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          )
        else
          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: overlayOpacity)),
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
