import 'package:flutter/material.dart';
import 'dart:math' as math;

class FloatingParticle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  Color color;

  FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.color,
  });
}

class FloatingParticles extends StatefulWidget {
  final int particleCount;

  const FloatingParticles({super.key, this.particleCount = 8});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<FloatingParticle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initializeParticles();

    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        _updateParticles();
      });
    });
  }

  void _initializeParticles() {
    _particles = List.generate(widget.particleCount, (index) {
      return FloatingParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 3 + _random.nextDouble() * 8,
        speedX: (_random.nextDouble() - 0.5) * 0.0005,
        speedY: (_random.nextDouble() - 0.5) * 0.0005,
        color: Colors.white.withValues(
          alpha: 0.03 + _random.nextDouble() * 0.07,
        ),
      );
    });
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.x += particle.speedX;
      particle.y += particle.speedY;

      // Wrap around edges
      if (particle.x < 0) particle.x = 1;
      if (particle.x > 1) particle.x = 0;
      if (particle.y < 0) particle.y = 1;
      if (particle.y > 1) particle.y = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlesPainter(
        particles: _particles,
        animationValue: _controller.value,
      ),
      size: Size.infinite,
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<FloatingParticle> particles;
  final double animationValue;

  _ParticlesPainter({required this.particles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      // Add subtle glow effect
      final glowPaint = Paint()
        ..color = particle.color.withValues(alpha: particle.color.a * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final position = Offset(
        particle.x * size.width,
        particle.y * size.height,
      );

      // Draw glow
      canvas.drawCircle(position, particle.size * 2, glowPaint);
      // Draw particle
      canvas.drawCircle(position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}
