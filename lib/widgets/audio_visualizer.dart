import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioVisualizer extends StatefulWidget {
  final bool isActive;
  final double height;
  final int barCount;

  const AudioVisualizer({
    super.key,
    this.isActive = false,
    this.height = 60,
    this.barCount = 40,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WavePainter(
            phase: _controller.value * 2 * math.pi,
            isActive: widget.isActive,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  final bool isActive;

  _WavePainter({required this.phase, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width * 0.6;
    final startX = (size.width - width) / 2;

    if (!isActive) {
      // Idle: thin subtle line with gradient
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.0),
            const Color(0xFF8B5CF6).withValues(alpha: 0.25),
            const Color(0xFF06B6D4).withValues(alpha: 0.25),
            const Color(0xFF06B6D4).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(startX, centerY - 1, width, 2))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + width, centerY),
        linePaint,
      );
      return;
    }

    // Active: smooth flowing sine wave
    _drawWave(canvas, size, centerY, startX, width,
        amplitude: 0.35, freq: 1.5, phaseOffset: 0,
        color1: const Color(0xFF8B5CF6), color2: const Color(0xFF06B6D4),
        opacity: 0.6, strokeWidth: 2.5);

    _drawWave(canvas, size, centerY, startX, width,
        amplitude: 0.22, freq: 2.2, phaseOffset: math.pi * 0.5,
        color1: const Color(0xFF06B6D4), color2: const Color(0xFF8B5CF6),
        opacity: 0.35, strokeWidth: 1.8);

    _drawWave(canvas, size, centerY, startX, width,
        amplitude: 0.15, freq: 3.0, phaseOffset: math.pi,
        color1: const Color(0xFF3B82F6), color2: const Color(0xFFA78BFA),
        opacity: 0.2, strokeWidth: 1.2);
  }

  void _drawWave(
    Canvas canvas, Size size, double centerY,
    double startX, double width, {
    required double amplitude,
    required double freq,
    required double phaseOffset,
    required Color color1,
    required Color color2,
    required double opacity,
    required double strokeWidth,
  }) {
    final path = Path();
    final maxAmp = size.height * amplitude;
    const steps = 100;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = startX + t * width;

      // Gaussian envelope so wave fades at edges
      final envelope = math.exp(-math.pow((t - 0.5) * 3.0, 2));
      final y = centerY + math.sin(t * math.pi * 2 * freq + phase + phaseOffset) * maxAmp * envelope;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color1.withValues(alpha: 0.0),
          color1.withValues(alpha: opacity),
          color2.withValues(alpha: opacity),
          color2.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(startX, 0, width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      phase != oldDelegate.phase || isActive != oldDelegate.isActive;
}
