import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showOverlay = false,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  double _fps = 60.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  // Memory tracking
  final int _memoryUsage = 0; // ignore: unused_field

  // Frame timing
  final Duration _lastFrameDuration = Duration.zero; // ignore: unused_field
  int _droppedFrames = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showOverlay) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (!mounted) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);

    _frameCount++;

    // Calculate FPS every second
    if (elapsed.inMilliseconds >= 1000) {
      setState(() {
        _fps = (_frameCount * 1000) / elapsed.inMilliseconds;
        _frameCount = 0;
        _lastTime = now;

        // Track if frames are dropped (FPS < 55)
        if (_fps < 55) {
          _droppedFrames++;
        }
      });
    }

    if (widget.showOverlay && mounted) {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showOverlay)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _fps >= 55
                    ? Colors.green.withValues(alpha: 0.8)
                    : _fps >= 30
                    ? Colors.orange.withValues(alpha: 0.8)
                    : Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FPS: ${_fps.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_droppedFrames > 0)
                    Text(
                      'Dropped: $_droppedFrames',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Widget to measure specific operation performance
class PerformanceTracker {
  static final Map<String, List<int>> _measurements = {};
  static final Map<String, Stopwatch> _activeTimers = {};

  /// Start tracking a performance metric
  static void startTracking(String operation) {
    _activeTimers[operation] = Stopwatch()..start();
  }

  /// Stop tracking and record the measurement
  static void stopTracking(String operation) {
    final timer = _activeTimers[operation];
    if (timer != null) {
      timer.stop();
      _measurements[operation] ??= [];
      _measurements[operation]!.add(timer.elapsedMilliseconds);
      _activeTimers.remove(operation);

      // Keep only last 100 measurements
      if (_measurements[operation]!.length > 100) {
        _measurements[operation]!.removeAt(0);
      }
    }
  }

  /// Get average time for an operation
  static double getAverageTime(String operation) {
    final times = _measurements[operation];
    if (times == null || times.isEmpty) return 0;

    final sum = times.reduce((a, b) => a + b);
    return sum / times.length;
  }

  /// Get performance report
  static Map<String, dynamic> getReport() {
    final report = <String, dynamic>{};

    _measurements.forEach((operation, times) {
      if (times.isNotEmpty) {
        final avg = times.reduce((a, b) => a + b) / times.length;
        final max = times.reduce((a, b) => a > b ? a : b);
        final min = times.reduce((a, b) => a < b ? a : b);

        report[operation] = {
          'average': avg.toStringAsFixed(2),
          'max': max,
          'min': min,
          'count': times.length,
        };
      }
    });

    return report;
  }

  /// Clear all measurements
  static void clear() {
    _measurements.clear();
    _activeTimers.clear();
  }

  /// Print performance report to console
  static void printReport() {
    debugPrint('=== Performance Report ===');
    final report = getReport();
    report.forEach((operation, metrics) {
      debugPrint('$operation:');
      debugPrint('  Average: ${metrics['average']}ms');
      debugPrint('  Max: ${metrics['max']}ms');
      debugPrint('  Min: ${metrics['min']}ms');
      debugPrint('  Count: ${metrics['count']}');
    });
    debugPrint('========================');
  }
}

/// Mixin to add performance tracking to widgets
mixin PerformanceAware<T extends StatefulWidget> on State<T> {
  final Map<String, Stopwatch> _timers = {};

  void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  void stopTimer(String name, {bool log = true}) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      if (log) {
        debugPrint(
          '${widget.runtimeType} - $name: ${timer.elapsedMilliseconds}ms',
        );
      }
      PerformanceTracker.stopTracking('${widget.runtimeType}.$name');
    }
  }

  Future<R> measureAsync<R>(String name, Future<R> Function() operation) async {
    startTimer(name);
    try {
      final result = await operation();
      return result;
    } finally {
      stopTimer(name);
    }
  }

  R measureSync<R>(String name, R Function() operation) {
    startTimer(name);
    try {
      final result = operation();
      return result;
    } finally {
      stopTimer(name);
    }
  }
}
