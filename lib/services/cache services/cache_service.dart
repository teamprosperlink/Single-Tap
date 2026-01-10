import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../res/config/api_config.dart';

/// High-performance in-memory cache service for embeddings and match results
/// Implements LRU (Least Recently Used) eviction policy
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // LRU cache for embeddings
  final LinkedHashMap<String, CachedEmbedding> _embeddingCache =
      LinkedHashMap();

  // LRU cache for match results
  final LinkedHashMap<String, CachedMatches> _matchCache = LinkedHashMap();

  // LRU cache for messages
  final LinkedHashMap<String, CachedMessages> _messageCache = LinkedHashMap();
  static const int _maxMessageCacheSize = 20; // Cache last 20 conversations
  static const int _messagesPerConversation =
      50; // Store last 50 messages per conversation
  static const Duration _messageCacheDuration = Duration(minutes: 10);

  // Statistics
  int _embeddingHits = 0;
  int _embeddingMisses = 0;
  int _matchHits = 0;
  int _matchMisses = 0;
  int _messageHits = 0;
  int _messageMisses = 0;

  /// Store embedding in cache
  void cacheEmbedding(String text, List<double> embedding) {
    try {
      final key = _generateKey(text);

      // Remove if already exists (to update access time)
      if (_embeddingCache.containsKey(key)) {
        _embeddingCache.remove(key);
      }

      // Add to cache
      _embeddingCache[key] = CachedEmbedding(
        embedding: embedding,
        timestamp: DateTime.now(),
      );

      // Enforce cache size limit
      _enforceEmbeddingCacheLimit();
    } catch (e) {
      debugPrint('Error caching embedding: $e');
    }
  }

  /// Retrieve embedding from cache
  List<double>? getCachedEmbedding(String text) {
    try {
      final key = _generateKey(text);
      final cached = _embeddingCache[key];

      if (cached == null) {
        _embeddingMisses++;
        return null;
      }

      // Check if cache is still valid
      final age = DateTime.now().difference(cached.timestamp);
      if (age > ApiConfig.embeddingCacheDuration) {
        _embeddingCache.remove(key);
        _embeddingMisses++;
        return null;
      }

      // Move to end (most recently used)
      _embeddingCache.remove(key);
      _embeddingCache[key] = cached;

      _embeddingHits++;
      return cached.embedding;
    } catch (e) {
      debugPrint('Error retrieving cached embedding: $e');
      return null;
    }
  }

  /// Store match results in cache
  void cacheMatches(String postId, List<String> matchedPostIds, double score) {
    try {
      // Remove if already exists
      if (_matchCache.containsKey(postId)) {
        _matchCache.remove(postId);
      }

      // Add to cache
      _matchCache[postId] = CachedMatches(
        matchedPostIds: matchedPostIds,
        score: score,
        timestamp: DateTime.now(),
      );

      // Enforce cache size limit
      _enforceMatchCacheLimit();
    } catch (e) {
      debugPrint('Error caching matches: $e');
    }
  }

  /// Retrieve match results from cache
  CachedMatches? getCachedMatches(String postId) {
    try {
      final cached = _matchCache[postId];

      if (cached == null) {
        _matchMisses++;
        return null;
      }

      // Check if cache is still valid
      final age = DateTime.now().difference(cached.timestamp);
      if (age > ApiConfig.matchCacheDuration) {
        _matchCache.remove(postId);
        _matchMisses++;
        return null;
      }

      // Move to end (most recently used)
      _matchCache.remove(postId);
      _matchCache[postId] = cached;

      _matchHits++;
      return cached;
    } catch (e) {
      debugPrint('Error retrieving cached matches: $e');
      return null;
    }
  }

  /// Invalidate match cache for a specific post
  void invalidateMatchCache(String postId) {
    _matchCache.remove(postId);
  }

  /// Invalidate all match caches
  void invalidateAllMatchCaches() {
    _matchCache.clear();
  }

  /// Clear embedding cache
  void clearEmbeddingCache() {
    _embeddingCache.clear();
    _embeddingHits = 0;
    _embeddingMisses = 0;
  }

  /// Clear match cache
  void clearMatchCache() {
    _matchCache.clear();
    _matchHits = 0;
    _matchMisses = 0;
  }

  /// Store messages in cache
  void cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) {
    try {
      // Remove if already exists
      if (_messageCache.containsKey(conversationId)) {
        _messageCache.remove(conversationId);
      }

      // Add to cache (only store last N messages)
      final messagesToCache = messages.take(_messagesPerConversation).toList();
      _messageCache[conversationId] = CachedMessages(
        messages: messagesToCache,
        timestamp: DateTime.now(),
      );

      // Enforce cache size limit
      _enforceMessageCacheLimit();
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  /// Retrieve messages from cache
  List<Map<String, dynamic>>? getCachedMessages(String conversationId) {
    try {
      final cached = _messageCache[conversationId];

      if (cached == null) {
        _messageMisses++;
        return null;
      }

      // Check if cache is still valid
      final age = DateTime.now().difference(cached.timestamp);
      if (age > _messageCacheDuration) {
        _messageCache.remove(conversationId);
        _messageMisses++;
        return null;
      }

      // Move to end (most recently used)
      _messageCache.remove(conversationId);
      _messageCache[conversationId] = cached;

      _messageHits++;
      return cached.messages;
    } catch (e) {
      debugPrint('Error retrieving cached messages: $e');
      return null;
    }
  }

  /// Invalidate message cache for a specific conversation
  void invalidateMessageCache(String conversationId) {
    _messageCache.remove(conversationId);
  }

  /// Clear message cache
  void clearMessageCache() {
    _messageCache.clear();
    _messageHits = 0;
    _messageMisses = 0;
  }

  /// Enforce message cache size limit (LRU eviction)
  void _enforceMessageCacheLimit() {
    while (_messageCache.length > _maxMessageCacheSize) {
      // Remove oldest (first) entry
      _messageCache.remove(_messageCache.keys.first);
    }
  }

  /// Clear all caches
  void clearAll() {
    clearEmbeddingCache();
    clearMatchCache();
    clearMessageCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    return {
      'embedding_cache': {
        'size': _embeddingCache.length,
        'hits': _embeddingHits,
        'misses': _embeddingMisses,
        'hit_rate': _embeddingHits + _embeddingMisses > 0
            ? _embeddingHits / (_embeddingHits + _embeddingMisses)
            : 0.0,
      },
      'match_cache': {
        'size': _matchCache.length,
        'hits': _matchHits,
        'misses': _matchMisses,
        'hit_rate': _matchHits + _matchMisses > 0
            ? _matchHits / (_matchHits + _matchMisses)
            : 0.0,
      },
      'message_cache': {
        'size': _messageCache.length,
        'hits': _messageHits,
        'misses': _messageMisses,
        'hit_rate': _messageHits + _messageMisses > 0
            ? _messageHits / (_messageHits + _messageMisses)
            : 0.0,
      },
    };
  }

  /// Generate cache key from text
  String _generateKey(String text) {
    return text.trim().toLowerCase().hashCode.toString();
  }

  /// Enforce embedding cache size limit (LRU eviction)
  void _enforceEmbeddingCacheLimit() {
    while (_embeddingCache.length > ApiConfig.maxCacheSize) {
      // Remove oldest (first) entry
      _embeddingCache.remove(_embeddingCache.keys.first);
    }
  }

  /// Enforce match cache size limit (LRU eviction)
  void _enforceMatchCacheLimit() {
    while (_matchCache.length > ApiConfig.maxCacheSize) {
      // Remove oldest (first) entry
      _matchCache.remove(_matchCache.keys.first);
    }
  }

  /// Warm up cache with frequently used embeddings
  Future<void> warmupCache(
    List<String> texts,
    Future<List<double>> Function(String) generateEmbedding,
  ) async {
    try {
      for (final text in texts) {
        if (!_embeddingCache.containsKey(_generateKey(text))) {
          final embedding = await generateEmbedding(text);
          cacheEmbedding(text, embedding);
        }
      }
    } catch (e) {
      debugPrint('Error warming up cache: $e');
    }
  }

  /// Preload cache with batch embeddings
  void preloadEmbeddings(Map<String, List<double>> embeddings) {
    for (final entry in embeddings.entries) {
      cacheEmbedding(entry.key, entry.value);
    }
  }
}

/// Cached embedding data class
class CachedEmbedding {
  final List<double> embedding;
  final DateTime timestamp;

  CachedEmbedding({required this.embedding, required this.timestamp});
}

/// Cached match results data class
class CachedMatches {
  final List<String> matchedPostIds;
  final double score;
  final DateTime timestamp;

  CachedMatches({
    required this.matchedPostIds,
    required this.score,
    required this.timestamp,
  });
}

/// Cached messages data class
class CachedMessages {
  final List<Map<String, dynamic>> messages;
  final DateTime timestamp;

  CachedMessages({required this.messages, required this.timestamp});
}
