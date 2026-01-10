import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

enum VoiceOrbState { idle, listening, processing, speaking }

class VoiceOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double size;

  const VoiceOrb({super.key, this.state = VoiceOrbState.idle, this.size = 200});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for breathing effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation for processing state
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Wave animation for speaking state
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _updateAnimationState();
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        _pulseController.repeat(reverse: true);
        _rotateController.stop();
        _waveController.stop();
        break;
      case VoiceOrbState.listening:
        _pulseController.repeat(reverse: true);
        _rotateController.stop();
        _waveController.stop();
        break;
      case VoiceOrbState.processing:
        _pulseController.stop();
        _rotateController.repeat();
        _waveController.stop();
        break;
      case VoiceOrbState.speaking:
        _pulseController.stop();
        _rotateController.stop();
        _waveController.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _rotateController,
        _waveController,
      ]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow rings
              if (widget.state == VoiceOrbState.listening)
                ..._buildRippleRings(),

              // Main orb
              Transform.scale(
                scale:
                    widget.state == VoiceOrbState.idle ||
                        widget.state == VoiceOrbState.listening
                    ? _pulseAnimation.value
                    : 1.0,
                child: Transform.rotate(
                  angle: widget.state == VoiceOrbState.processing
                      ? _rotateController.value * 2 * math.pi
                      : 0,
                  child: Container(
                    width: widget.size * 0.7,
                    height: widget.size * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _getGradient(),
                      boxShadow: [
                        BoxShadow(
                          color: _getGlowColor().withValues(alpha: 0.6),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: _getGlowColor().withValues(alpha: 0.3),
                          blurRadius: 80,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Wave particles for speaking state
              if (widget.state == VoiceOrbState.speaking)
                ..._buildWaveParticles(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildRippleRings() {
    return List.generate(3, (index) {
      final delay = index * 0.2;
      final animation = Tween<double>(begin: 0.5, end: 1.2).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        ),
      );

      return Transform.scale(
        scale: animation.value,
        child: Container(
          width: widget.size * 0.7,
          height: widget.size * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(
                0xFF8B5CF6,
              ).withValues(alpha: (1 - animation.value) * 0.5),
              width: 2,
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildWaveParticles() {
    return List.generate(8, (index) {
      final angle = (index / 8) * 2 * math.pi;
      final distance = 60 + math.sin(_waveController.value * math.pi) * 20;

      return Transform.translate(
        offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });
  }

  Gradient _getGradient() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        );
      case VoiceOrbState.listening:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        );
      case VoiceOrbState.processing:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFFFAA00),
            Color(0xFFFF6B6B),
            Color(0xFF8B5CF6),
          ],
          transform: GradientRotation(_rotateController.value * math.pi),
        );
      case VoiceOrbState.speaking:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
        );
    }
  }

  Color _getGlowColor() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const Color(0xFF8B5CF6);
      case VoiceOrbState.listening:
        return const Color(0xFF0EA5E9);
      case VoiceOrbState.processing:
        return const Color(0xFFFFAA00);
      case VoiceOrbState.speaking:
        return const Color(0xFF10B981);
    }
  }
}
