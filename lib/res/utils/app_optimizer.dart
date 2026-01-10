import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// App-wide optimization utilities
class AppOptimizer {
  static final AppOptimizer _instance = AppOptimizer._internal();
  factory AppOptimizer() => _instance;
  AppOptimizer._internal();

  // Memory management
  static const int maxMemoryCacheSizeInMB = 100;
  static const int maxImageCacheCount = 50;

  // Firestore optimization settings
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize app-wide optimizations
  static Future<void> initialize() async {
    // Configure Firestore for offline persistence
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Configure image cache
    PaintingBinding.instance.imageCache.maximumSize = maxImageCacheCount;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        maxMemoryCacheSizeInMB * 1024 * 1024;

    // Clear old cache periodically
    _scheduleCacheClearance();
  }

  /// Clear image cache when memory is low
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  /// Schedule periodic cache clearance
  static void _scheduleCacheClearance() {
    // Clear cache every 30 minutes if app is active
    Future.delayed(const Duration(minutes: 30), () {
      if (PaintingBinding.instance.imageCache.currentSizeBytes >
          (maxMemoryCacheSizeInMB * 1024 * 1024 * 0.8)) {
        clearImageCache();
      }
      _scheduleCacheClearance();
    });
  }

  /// Optimize Firestore query with pagination
  static Query<Map<String, dynamic>> optimizeQuery(
    Query<Map<String, dynamic>> query, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query;
  }

  /// Batch write operations for better performance
  static Future<void> batchWrite(
    List<Future<void> Function(WriteBatch batch)> operations,
  ) async {
    const batchSize = 500; // Firestore limit
    final batches = <WriteBatch>[];

    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < operations.length)
          ? i + batchSize
          : operations.length;

      for (int j = i; j < end; j++) {
        await operations[j](batch);
      }

      batches.add(batch);
    }

    // Commit all batches
    await Future.wait(batches.map((batch) => batch.commit()));
  }

  /// Debounce function calls
  static Function debounce(Function function, Duration duration) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(duration, () => function());
    };
  }

  /// Throttle function calls
  static Function throttle(Function function, Duration duration) {
    bool canRun = true;
    return () {
      if (!canRun) return;
      function();
      canRun = false;
      Timer(duration, () => canRun = true);
    };
  }

  /// Memory efficient list builder
  static Widget buildOptimizedList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 100,
    );
  }

  /// Optimized image widget
  static Widget buildOptimizedImage(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: placeholder != null
          ? (context, url) => placeholder
          : (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget
          : (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error_outline, color: Colors.grey),
            ),
    );
  }

  /// Check and report memory usage
  static void checkMemoryUsage() {
    if (kDebugMode) {
      final imageCache = PaintingBinding.instance.imageCache;
      debugPrint(
        'Image Cache: ${imageCache.currentSize} images, '
        '${(imageCache.currentSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB',
      );
    }
  }

  /// Dispose resources
  static void dispose() {
    clearImageCache();
  }
}

/// Mixin for memory-aware widgets
mixin MemoryAwareMixin<T extends StatefulWidget> on State<T> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear unused resources when dependencies change
    if (mounted) {
      AppOptimizer.checkMemoryUsage();
    }
  }

  @override
  void dispose() {
    // Ensure proper cleanup
    super.dispose();
  }
}

/// Extension for efficient string operations
extension StringOptimization on String {
  /// Truncate string with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 3)}...';
  }

  /// Check if string is a valid URL
  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}

/// Timer management for preventing memory leaks
class TimerManager {
  static final Map<String, Timer> _timers = {};

  static void addTimer(String key, Timer timer) {
    cancelTimer(key);
    _timers[key] = timer;
  }

  static void cancelTimer(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  static void cancelAllTimers() {
    _timers.forEach((key, timer) => timer.cancel());
    _timers.clear();
  }
}
