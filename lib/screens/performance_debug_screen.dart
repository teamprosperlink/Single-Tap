import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../res/utils/performance_monitor.dart';
import '../widgets/common widgets/app_background.dart';

class PerformanceDebugScreen extends StatefulWidget {
  const PerformanceDebugScreen({super.key});

  @override
  State<PerformanceDebugScreen> createState() => _PerformanceDebugScreenState();
}

class _PerformanceDebugScreenState extends State<PerformanceDebugScreen> {
  bool _showPerformanceOverlay = false;
  bool _showMaterialGrid = false;
  bool _showSemantics = false;
  bool _checkerboardImages = false;
  bool _checkerboardLayers = false;

  Map<String, dynamic> _performanceMetrics = {};

  @override
  void initState() {
    super.initState();
    _loadPerformanceMetrics();
  }

  void _loadPerformanceMetrics() {
    setState(() {
      _performanceMetrics = PerformanceTracker.getReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Performance Debug',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ),
        actions: const [],
      ),
      body: AppBackground(
        showParticles: false,
        overlayOpacity: 0.7,
        child: ListView(
          padding: const EdgeInsets.only(
            top: kToolbarHeight + 44,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          children: [
            _buildDebugOptionsCard(),
            const SizedBox(height: 16),
            _buildPerformanceMetricsCard(),
            const SizedBox(height: 16),
            _buildFrameRateCard(),
            const SizedBox(height: 16),
            _buildMemoryCard(),
            const SizedBox(height: 16),
            _buildTestActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Performance Overlay',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Show FPS and frame timing',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            value: _showPerformanceOverlay,
            activeThumbColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _showPerformanceOverlay = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text(
              'Material Grid',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Show material design grid',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            value: _showMaterialGrid,
            activeThumbColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _showMaterialGrid = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text(
              'Semantics Debugger',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Show accessibility tree',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            value: _showSemantics,
            activeThumbColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _showSemantics = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text(
              'Checkerboard Images',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Highlight cached images',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            value: _checkerboardImages,
            activeThumbColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _checkerboardImages = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text(
              'Checkerboard Layers',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Highlight rendering layers',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            value: _checkerboardLayers,
            activeThumbColor: Colors.blue,
            onChanged: (value) {
              setState(() {
                _checkerboardLayers = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_performanceMetrics.isEmpty)
            Text(
              'No metrics collected yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          else
            ..._performanceMetrics.entries.map((entry) {
              final metrics = entry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetric(
                          'Avg',
                          '${metrics['average']}ms',
                        ),
                        _buildMetric(
                          'Min',
                          '${metrics['min']}ms',
                        ),
                        _buildMetric(
                          'Max',
                          '${metrics['max']}ms',
                        ),
                        _buildMetric(
                          'Count',
                          '${metrics['count']}',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFrameRateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Frame Rate Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              final frameTime =
                  SchedulerBinding.instance.currentFrameTimeStamp;
              final fps = (1000000 / frameTime.inMicroseconds).clamp(0, 120);

              return Column(
                children: [
                  LinearProgressIndicator(
                    value: fps / 60,
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fps >= 55
                          ? Colors.green
                          : fps >= 30
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fps.toStringAsFixed(1)} FPS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: fps >= 55
                          ? Colors.green
                          : fps >= 30
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Memory Usage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Run with --profile flag to see memory metrics',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              // Trigger garbage collection hint
              // Note: This is just a hint, actual GC is controlled by Dart VM
              for (int i = 0; i < 10; i++) {
                List.generate(1000000, (index) => index);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Triggered memory pressure')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.memory),
            label: const Text('Force Memory Pressure'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Tests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _runScrollTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test Scroll Performance'),
              ),
              ElevatedButton(
                onPressed: _runAnimationTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test Animation'),
              ),
              ElevatedButton(
                onPressed: _runHeavyComputation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Heavy Computation'),
              ),
              ElevatedButton(
                onPressed: _runNetworkTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Network Stress Test'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _runScrollTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scroll Test')),
          body: ListView.builder(
            itemCount: 10000,
            itemBuilder: (context, index) {
              PerformanceTracker.startTracking('ScrollTest.buildItem');
              final widget = ListTile(
                title: Text('Item $index'),
                subtitle: Text('Subtitle for item $index'),
                leading: CircleAvatar(child: Text('$index')),
              );
              PerformanceTracker.stopTracking('ScrollTest.buildItem');
              return widget;
            },
          ),
        ),
      ),
    );
  }

  void _runAnimationTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnimationTestScreen()),
    );
  }

  void _runHeavyComputation() async {
    PerformanceTracker.startTracking('HeavyComputation');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 20),
            Text('Running computation...', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ],
        ),
      ),
    );

    // Simulate heavy computation
    await Future.delayed(const Duration(seconds: 2));
    int result = 0;
    for (int i = 0; i < 10000000; i++) {
      result += i;
    }

    PerformanceTracker.stopTracking('HeavyComputation');

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    _loadPerformanceMetrics();

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Computation result: $result')));
  }

  void _runNetworkTest() async {
    PerformanceTracker.startTracking('NetworkTest');

    // Simulate multiple network requests
    final futures = List.generate(10, (index) async {
      await Future.delayed(Duration(milliseconds: 100 + (index * 50)));
      return 'Response $index';
    });

    await Future.wait(futures);

    PerformanceTracker.stopTracking('NetworkTest');
    _loadPerformanceMetrics();

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Network test completed')));
  }
}

class AnimationTestScreen extends StatefulWidget {
  const AnimationTestScreen({super.key});

  @override
  State<AnimationTestScreen> createState() => _AnimationTestScreenState();
}

class _AnimationTestScreenState extends State<AnimationTestScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animation Test')),
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.5 + (_animation.value * 0.5),
              child: Transform.rotate(
                angle: _animation.value * 6.28,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [Colors.blue, Colors.purple, Colors.red],
                      transform: GradientRotation(_animation.value * 3.14),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'Performance\nTest',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
