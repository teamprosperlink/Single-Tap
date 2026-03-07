import 'package:flutter/material.dart';
import 'dart:math' as math;

enum VoiceOrbState { idle, listening, processing, speaking }

class VoiceOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double size;

  const VoiceOrb({super.key, this.state = VoiceOrbState.idle, this.size = 200});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _rotateController;
  late AnimationController _glowPulseController;

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    _glowPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _syncAnimationSpeeds();
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncAnimationSpeeds();
  }

  void _syncAnimationSpeeds() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        _breatheController.duration = const Duration(milliseconds: 2500);
        _rotateController.duration = const Duration(milliseconds: 8000);
        _glowPulseController.duration = const Duration(milliseconds: 2000);
      case VoiceOrbState.listening:
        _breatheController.duration = const Duration(milliseconds: 1000);
        _rotateController.duration = const Duration(milliseconds: 3000);
        _glowPulseController.duration = const Duration(milliseconds: 600);
      case VoiceOrbState.processing:
        _breatheController.duration = const Duration(milliseconds: 1600);
        _rotateController.duration = const Duration(milliseconds: 2000);
        _glowPulseController.duration = const Duration(milliseconds: 800);
      case VoiceOrbState.speaking:
        _breatheController.duration = const Duration(milliseconds: 1200);
        _rotateController.duration = const Duration(milliseconds: 4000);
        _glowPulseController.duration = const Duration(milliseconds: 700);
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _rotateController.dispose();
    _glowPulseController.dispose();
    super.dispose();
  }

  // Color sets per state
  List<Color> _primaryColors() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const [Color(0xFF7C3AED), Color(0xFF3B82F6), Color(0xFF06B6D4)];
      case VoiceOrbState.listening:
        return const [Color(0xFF06B6D4), Color(0xFF8B5CF6), Color(0xFF38BDF8)];
      case VoiceOrbState.processing:
        return const [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6)];
      case VoiceOrbState.speaking:
        return const [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF8B5CF6)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breatheController,
        _rotateController,
        _glowPulseController,
      ]),
      builder: (context, _) {
        final breathe = Curves.easeInOut.transform(_breatheController.value);
        final rotate = _rotateController.value * 2 * math.pi;
        final glowPulse = _glowPulseController.value;
        final colors = _primaryColors();
        final isActive = widget.state != VoiceOrbState.idle;

        final orbSize = widget.size * 0.58;
        final scale = 1.0 + breathe * (isActive ? 0.06 : 0.03);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Soft wide ambient glow
                  _buildGlowLayer(
                    size: orbSize * 2.2,
                    colors: colors,
                    opacity: 0.08 + glowPulse * (isActive ? 0.08 : 0.03),
                    blur: 50,
                  ),

                  // Layer 2: Medium glow ring
                  _buildGlowLayer(
                    size: orbSize * 1.5,
                    colors: colors,
                    opacity: 0.12 + glowPulse * (isActive ? 0.12 : 0.04),
                    blur: 30,
                  ),

                  // Layer 3: Tight glow halo
                  _buildGlowLayer(
                    size: orbSize * 1.15,
                    colors: colors,
                    opacity: 0.25 + glowPulse * (isActive ? 0.15 : 0.05),
                    blur: 15,
                  ),

                  // Main orb body with rotating gradient
                  Container(
                    width: orbSize,
                    height: orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        transform: GradientRotation(rotate),
                        colors: [
                          colors[0],
                          colors[1],
                          colors[2],
                          colors[0],
                        ],
                        stops: const [0.0, 0.33, 0.67, 1.0],
                      ),
                    ),
                  ),

                  // Glass overlay for depth
                  Container(
                    width: orbSize,
                    height: orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.35),
                        radius: 0.9,
                        colors: [
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15),
                        ],
                        stops: const [0.0, 0.3, 0.6, 1.0],
                      ),
                    ),
                  ),

                  // Rim highlight
                  Container(
                    width: orbSize,
                    height: orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.15 + glowPulse * 0.1,
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),

                  // Listening: expanding pulse rings
                  if (widget.state == VoiceOrbState.listening)
                    ..._buildPulseRings(orbSize, colors[1]),

                  // Processing: spinning arc
                  if (widget.state == VoiceOrbState.processing)
                    _buildSpinArc(orbSize, colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowLayer({
    required double size,
    required List<Color> colors,
    required double opacity,
    required double blur,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: opacity),
            blurRadius: blur,
            spreadRadius: blur * 0.3,
          ),
          BoxShadow(
            color: colors.last.withValues(alpha: opacity * 0.6),
            blurRadius: blur * 0.7,
            spreadRadius: blur * 0.15,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPulseRings(double orbSize, Color color) {
    return List.generate(2, (i) {
      // Stagger each ring using breathe controller offset
      final t = (_breatheController.value + i * 0.5) % 1.0;
      final ringScale = 1.0 + t * 0.4;
      final ringOpacity = (1.0 - t) * 0.3;

      return Container(
        width: orbSize * ringScale,
        height: orbSize * ringScale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: ringOpacity),
            width: 2.0 - t * 1.0,
          ),
        ),
      );
    });
  }

  Widget _buildSpinArc(double orbSize, List<Color> colors) {
    return SizedBox(
      width: orbSize * 1.18,
      height: orbSize * 1.18,
      child: Transform.rotate(
        angle: _rotateController.value * 2 * math.pi,
        child: CustomPaint(
          painter: _ArcPainter(
            color: colors[0],
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Two arcs on opposite sides
    canvas.drawArc(rect, 0, math.pi * 0.6, false, paint);
    paint.color = color.withValues(alpha: 0.4);
    canvas.drawArc(rect, math.pi, math.pi * 0.4, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}
