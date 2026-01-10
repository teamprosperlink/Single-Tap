import 'package:flutter/foundation.dart';

class PhotoCacheService {
  static final PhotoCacheService _instance = PhotoCacheService._internal();
  factory PhotoCacheService() => _instance;
  PhotoCacheService._internal();

  // Cache for photo URLs with timestamp
  final Map<String, CachedPhoto> _photoCache = {};

  // Cache duration (1 hour)
  static const Duration _cacheDuration = Duration(hours: 1);

  // Maximum cache size
  static const int _maxCacheSize = 100;

  // Get cached photo URL
  String? getCachedPhotoUrl(String userId) {
    final cached = _photoCache[userId];
    if (cached != null && !cached.isExpired) {
      debugPrint('Photo cache hit for user: $userId');
      return cached.url;
    }

    // Remove expired entry
    if (cached != null && cached.isExpired) {
      _photoCache.remove(userId);
    }

    return null;
  }

  // Cache photo URL
  void cachePhotoUrl(String userId, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return;

    // Maintain cache size limit
    if (_photoCache.length >= _maxCacheSize) {
      _removeOldestEntry();
    }

    _photoCache[userId] = CachedPhoto(url: photoUrl, timestamp: DateTime.now());

    debugPrint('Cached photo for user: $userId');
  }

  // Batch cache photo URLs
  void cacheMultiplePhotos(Map<String, String?> photos) {
    photos.forEach((userId, photoUrl) {
      if (photoUrl != null) {
        cachePhotoUrl(userId, photoUrl);
      }
    });
  }

  // Clear cache for a specific user
  void clearUserCache(String userId) {
    _photoCache.remove(userId);
  }

  // Clear all cache
  void clearAllCache() {
    _photoCache.clear();
    debugPrint('Photo cache cleared');
  }

  // Remove oldest cache entry
  void _removeOldestEntry() {
    if (_photoCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    _photoCache.forEach((key, value) {
      if (oldestTime == null || value.timestamp.isBefore(oldestTime!)) {
        oldestTime = value.timestamp;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      _photoCache.remove(oldestKey);
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    int expired = 0;
    int valid = 0;

    _photoCache.forEach((_, cached) {
      if (cached.isExpired) {
        expired++;
      } else {
        valid++;
      }
    });

    return {
      'total': _photoCache.length,
      'valid': valid,
      'expired': expired,
      'maxSize': _maxCacheSize,
    };
  }
}

class CachedPhoto {
  final String url;
  final DateTime timestamp;

  CachedPhoto({required this.url, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        PhotoCacheService._cacheDuration;
  }
}
