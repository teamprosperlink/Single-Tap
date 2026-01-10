import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../res/utils/performance_monitor.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Debug'),
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformanceMetrics,
            tooltip: 'Refresh Metrics',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              PerformanceTracker.clear();
              _loadPerformanceMetrics();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Performance metrics cleared')),
              );
            },
            tooltip: 'Clear Metrics',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDebugOptionsCard(isDarkMode),
          const SizedBox(height: 16),
          _buildPerformanceMetricsCard(isDarkMode),
          const SizedBox(height: 16),
          _buildFrameRateCard(isDarkMode),
          const SizedBox(height: 16),
          _buildMemoryCard(isDarkMode),
          const SizedBox(height: 16),
          _buildTestActionsCard(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildDebugOptionsCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Performance Overlay'),
              subtitle: const Text('Show FPS and frame timing'),
              value: _showPerformanceOverlay,
              onChanged: (value) {
                setState(() {
                  _showPerformanceOverlay = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Material Grid'),
              subtitle: const Text('Show material design grid'),
              value: _showMaterialGrid,
              onChanged: (value) {
                setState(() {
                  _showMaterialGrid = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Semantics Debugger'),
              subtitle: const Text('Show accessibility tree'),
              value: _showSemantics,
              onChanged: (value) {
                setState(() {
                  _showSemantics = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Checkerboard Images'),
              subtitle: const Text('Highlight cached images'),
              value: _checkerboardImages,
              onChanged: (value) {
                setState(() {
                  _checkerboardImages = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Checkerboard Layers'),
              subtitle: const Text('Highlight rendering layers'),
              value: _checkerboardLayers,
              onChanged: (value) {
                setState(() {
                  _checkerboardLayers = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (_performanceMetrics.isEmpty)
              Text(
                'No metrics collected yet',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetric(
                            'Avg',
                            '${metrics['average']}ms',
                            isDarkMode,
                          ),
                          _buildMetric(
                            'Min',
                            '${metrics['min']}ms',
                            isDarkMode,
                          ),
                          _buildMetric(
                            'Max',
                            '${metrics['max']}ms',
                            isDarkMode,
                          ),
                          _buildMetric(
                            'Count',
                            '${metrics['count']}',
                            isDarkMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, bool isDarkMode) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFrameRateCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frame Rate Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
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
      ),
    );
  }

  Widget _buildMemoryCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Run with --profile flag to see memory metrics',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
              icon: const Icon(Icons.memory),
              label: const Text('Force Memory Pressure'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestActionsCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Tests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _runScrollTest,
                  child: const Text('Test Scroll Performance'),
                ),
                ElevatedButton(
                  onPressed: _runAnimationTest,
                  child: const Text('Test Animation'),
                ),
                ElevatedButton(
                  onPressed: _runHeavyComputation,
                  child: const Text('Heavy Computation'),
                ),
                ElevatedButton(
                  onPressed: _runNetworkTest,
                  child: const Text('Network Stress Test'),
                ),
              ],
            ),
          ],
        ),
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
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Running computation...'),
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
