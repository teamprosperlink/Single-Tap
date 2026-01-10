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
  final math.Random _random = math.Random();
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(widget.barCount, (_) => 0.1);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    )..addListener(_updateBars);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      setState(() {
        _barHeights = List.generate(widget.barCount, (_) => 0.1);
      });
    }
  }

  void _updateBars() {
    setState(() {
      for (int i = 0; i < _barHeights.length; i++) {
        // Simulate natural voice pattern - center bars are more active
        final centerDistance = (i - _barHeights.length / 2).abs();
        final centerFactor = 1 - (centerDistance / (_barHeights.length / 2));

        _barHeights[i] = (_random.nextDouble() * 0.7 + 0.3) * centerFactor;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          widget.barCount,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _buildBar(index),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(int index) {
    final height = widget.isActive
        ? _barHeights[index] * widget.height
        : widget.height * 0.1;

    // Color gradient based on position
    final color = Color.lerp(
      const Color(0xFF0EA5E9),
      const Color(0xFF8B5CF6),
      index / widget.barCount,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 3,
      height: height.clamp(widget.height * 0.1, widget.height),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.5)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
