# Flutter Performance Testing Guide 🚀

## Quick Start

### 1. Enable Performance Overlay in App
```dart
// In your main.dart
MaterialApp(
  showPerformanceOverlay: true, // Shows FPS graphs
  checkerboardRasterCacheImages: true, // Shows cached images
  checkerboardOffscreenLayers: true, // Shows rendering layers
)
```

### 2. Run Performance Tests

#### Windows:
```bash
.\scripts\performance_test.bat
```

#### Mac/Linux:
```bash
./scripts/performance_test.sh
```

## Performance Testing Tools

### 1. Built-in Performance Monitor
Navigate to the Performance Debug screen in the app to:
- View real-time FPS monitoring
- Track performance metrics
- Run stress tests
- Enable debug overlays

### 2. Flutter DevTools
```bash
# Install DevTools
flutter pub global activate devtools

# Run DevTools
flutter pub global run devtools

# Run app in profile mode
flutter run --profile
```

### 3. Performance Metrics Tracking

#### Use the PerformanceTracker in code:
```dart
// Start tracking
PerformanceTracker.startTracking('MyOperation');

// Your code here
await someExpensiveOperation();

// Stop tracking
PerformanceTracker.stopTracking('MyOperation');

// Get report
final report = PerformanceTracker.getReport();
```

#### Use the PerformanceAware mixin:
```dart
class _MyWidgetState extends State<MyWidget> with PerformanceAware {
  @override
  void initState() {
    super.initState();
    measureAsync('initState', () async {
      // Your initialization code
    });
  }
}
```

## Key Performance Metrics

### Target Metrics:
| Metric | Target | Critical |
|--------|--------|----------|
| Frame Rate | 60 FPS | < 30 FPS |
| Frame Build Time | < 16ms | > 32ms |
| Startup Time | < 2s | > 5s |
| Memory Usage | < 150MB | > 300MB |
| APK Size | < 30MB | > 50MB |

## Testing Checklist

### 1. Startup Performance
```bash
flutter run --trace-startup --profile
```
- [ ] App starts in < 2 seconds
- [ ] No blank screens during startup
- [ ] Splash screen displays immediately

### 2. Scroll Performance
- [ ] Chat list scrolls at 60 FPS
- [ ] Message list scrolls smoothly
- [ ] Images load without jank
- [ ] No dropped frames during scroll

### 3. Memory Testing
```bash
flutter run --profile
```
- [ ] Memory stays below 150MB during normal use
- [ ] No memory leaks when navigating
- [ ] Images are properly cached
- [ ] Unused resources are released

### 4. Network Performance
- [ ] API calls complete in < 2 seconds
- [ ] Images load progressively
- [ ] Offline mode works correctly
- [ ] Retry logic for failed requests

### 5. Animation Performance
- [ ] Transitions run at 60 FPS
- [ ] No jank during animations
- [ ] Smooth keyboard appearance
- [ ] Loading indicators don't freeze

## Common Performance Issues

### 1. Dropped Frames
**Symptoms:** Janky scrolling, stuttering animations
**Solutions:**
- Use `const` constructors
- Implement `RepaintBoundary`
- Cache expensive computations
- Use `ListView.builder` for long lists

### 2. Memory Leaks
**Symptoms:** Increasing memory usage, eventual crash
**Solutions:**
- Dispose controllers properly
- Cancel stream subscriptions
- Clear image cache periodically
- Use `weak` references where appropriate

### 3. Slow Startup
**Symptoms:** Long white screen, delayed splash
**Solutions:**
- Lazy load heavy dependencies
- Defer non-critical initialization
- Optimize asset loading
- Reduce initial widget tree complexity

### 4. Network Bottlenecks
**Symptoms:** Slow data loading, timeouts
**Solutions:**
- Implement pagination
- Use caching strategies
- Compress images
- Batch API requests

## Automated Performance Testing

### Integration Tests
```dart
// test/performance/scroll_performance_test.dart
testWidgets('scroll performance', (tester) async {
  await tester.pumpWidget(MyApp());
  
  final stopwatch = Stopwatch()..start();
  await tester.fling(find.byType(ListView), Offset(0, -500), 1000);
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  expect(stopwatch.elapsedMilliseconds, lessThan(1000));
});
```

### Run Integration Tests:
```bash
flutter test integration_test/performance_test.dart
```

## Profiling Commands

### Build Size Analysis:
```bash
flutter build apk --analyze-size
flutter build ios --analyze-size
```

### Bundle Analysis:
```bash
flutter build apk --split-debug-info=debug_info
flutter build apk --obfuscate
```

### Memory Profiling:
```bash
flutter run --profile --trace-skia
```

### CPU Profiling:
```bash
flutter run --profile --endless-trace-buffer
```

## Performance Monitoring in Production

### 1. Add Firebase Performance
```yaml
dependencies:
  firebase_performance: ^latest_version
```

### 2. Custom Traces
```dart
final trace = FirebasePerformance.instance.newTrace('custom_trace');
await trace.start();
// Your code
await trace.stop();
```

### 3. Network Monitoring
```dart
final metric = FirebasePerformance.instance
    .newHttpMetric('https://api.example.com', HttpMethod.Get);
await metric.start();
// Make request
metric.responseCode = 200;
await metric.stop();
```

## Best Practices

### 1. Widget Optimization
- Use `const` constructors where possible
- Implement `shouldRebuild` in custom painters
- Use `RepaintBoundary` for complex widgets
- Split large widgets into smaller ones

### 2. State Management
- Minimize rebuilds with selective listening
- Use `ValueListenableBuilder` for simple cases
- Implement proper equality checks
- Cache computed values

### 3. Asset Optimization
- Compress images before adding
- Use appropriate image formats (WebP for photos)
- Implement lazy loading for images
- Cache network images

### 4. Code Optimization
- Avoid expensive operations in `build()`
- Use `compute()` for heavy computations
- Implement pagination for lists
- Defer non-critical work

## Debugging Performance Issues

### 1. Enable Timeline Events
```dart
Timeline.startSync('MyOperation');
// Your code
Timeline.finishSync();
```

### 2. Debug Paint
```dart
debugPaintSizeEnabled = true; // Shows widget boundaries
debugPaintLayerBordersEnabled = true; // Shows layer boundaries
debugRepaintRainbowEnabled = true; // Shows repaint areas
```

### 3. Performance Overlay
```dart
PerformanceOverlay.allEnabled(); // Shows all performance metrics
```

## CI/CD Integration

### GitHub Actions Example:
```yaml
- name: Run Performance Tests
  run: |
    flutter test integration_test/performance_test.dart
    flutter build apk --analyze-size
```

## Resources

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter DevTools](https://docs.flutter.dev/development/tools/devtools/overview)
- [Performance Profiling](https://docs.flutter.dev/perf/ui-performance)
- [Memory Profiling](https://docs.flutter.dev/development/tools/devtools/memory)

## Support

For performance issues specific to this app:
1. Run the performance debug screen
2. Collect metrics using DevTools
3. Check the performance report
4. Review frame timing in Timeline view