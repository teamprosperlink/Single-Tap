import 'dart:async';
import 'package:flutter/foundation.dart';

class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();
  
  // Buffer size limits
  static const int maxBufferSize = 10 * 1024 * 1024; // 10MB max buffer
  static const int optimalBufferSize = 1024 * 1024; // 1MB optimal buffer
  
  // Track active buffers
  final Map<String, int> _activeBuffers = {};
  Timer? _cleanupTimer;
  
  void initialize() {
    // Start periodic cleanup
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _performCleanup();
    });
  }
  
  void registerBuffer(String id, int size) {
    _activeBuffers[id] = size;
    
    // Check total memory usage
    final totalSize = _activeBuffers.values.fold<int>(0, (sum, size) => sum + size);
    if (totalSize > maxBufferSize) {
      debugPrint('Warning: Total buffer size exceeds limit: $totalSize bytes');
      _performCleanup();
    }
  }
  
  void unregisterBuffer(String id) {
    _activeBuffers.remove(id);
  }
  
  void _performCleanup() {
    debugPrint('Performing memory cleanup. Active buffers: ${_activeBuffers.length}');
    
    // Force garbage collection hint
    if (!kIsWeb) {
      // This is a hint to the VM to perform GC
      // Note: This doesn't guarantee immediate collection
      _activeBuffers.clear();
    }
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    _activeBuffers.clear();
  }
  
  // Get optimal chunk size for data operations
  static int getOptimalChunkSize(int totalSize) {
    if (totalSize <= optimalBufferSize) {
      return totalSize;
    }
    
    // Split large data into smaller chunks
    return optimalBufferSize;
  }
  
  // Monitor memory pressure
  static bool isMemoryPressureHigh() {
    // This is a simplified check
    // In production, you'd want more sophisticated monitoring
    return false;
  }
}