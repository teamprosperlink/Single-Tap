import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../res/config/api_config.dart';
import 'cache services/cache_service.dart';

/// Unified Matching Service
/// Consolidates all matching logic into a single, optimized service
/// Features:
/// - AI-powered intent understanding (no hardcoded categories)
/// - Smart caching for performance
/// - Real-time matching capabilities
/// - Multi-factor scoring algorithm
/// - Scalable architecture
class UnifiedMatchingService {
  static final UnifiedMatchingService _instance =
      UnifiedMatchingService._internal();
  factory UnifiedMatchingService() => _instance;
  UnifiedMatchingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService _cache = CacheService();

  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint(' UnifiedMatchingService initialized successfully');
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  //    INTENT ANALYSIS

  /// Analyze user intent (local fallback — backend API handles AI)
  Future<IntentAnalysis> analyzeIntent(String userInput) async {
    await _ensureInitialized();
    return IntentAnalysis.fallback(userInput);
  }

  /// Generate clarifying questions (no longer uses Gemini)
  Future<List<ClarifyingQuestion>> generateClarifyingQuestions(
    String userInput,
    IntentAnalysis intent,
  ) async {
    return [];
  }

  //    EMBEDDING GENERATION

  /// Generate embedding — returns zero vector (backend API handles embeddings)
  Future<List<double>> generateEmbedding(String text) async {
    final cached = _cache.getCachedEmbedding(text);
    if (cached != null) return cached;
    return _generateFallbackEmbedding(text);
  }

  /// Generate embeddings in batch
  Future<List<List<double>>> generateBatchEmbeddings(List<String> texts) async {
    return texts.map((_) => _generateFallbackEmbedding('')).toList();
  }

  //    MATCHING ALGORITHM

  /// Find best matches for a user's intent
  Future<List<MatchResult>> findMatches({
    required String userId,
    required IntentAnalysis userIntent,
    required Map<String, dynamic> userAnswers,
    String? userLocation,
    double? userLat,
    double? userLon,
    int limit = 20,
  }) async {
    await _ensureInitialized();

    try {
      // Generate embedding for user's intent
      final userText =
          '${userIntent.primaryIntent} ${userIntent.searchKeywords.join(' ')}';
      final userEmbedding = await generateEmbedding(userText);

      // Get active posts from other users
      // Use try-catch for index fallback - composite index may not exist yet
      List<QueryDocumentSnapshot<Map<String, dynamic>>> candidateDocs;
      try {
        final snapshot = await _firestore
            .collection(ApiConfig.postsCollection)
            .where('userId', isNotEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .limit(500)
            .get();
        candidateDocs = snapshot.docs;
      } catch (indexError) {
        debugPrint(' Index not available, using fallback query: $indexError');
        final fallbackSnapshot = await _firestore
            .collection(ApiConfig.postsCollection)
            .where('isActive', isEqualTo: true)
            .limit(500)
            .get();
        candidateDocs = fallbackSnapshot.docs
            .where((doc) => doc.data()['userId'] != userId)
            .toList();
      }

      List<MatchResult> matches = [];

      for (final doc in candidateDocs) {
        try {
          final postData = doc.data();

          // Get or generate embedding for this post
          List<double> postEmbedding;
          if (postData['embedding'] != null) {
            postEmbedding = List<double>.from(postData['embedding']);
          } else {
            final postText =
                '${postData['title'] ?? ''} ${postData['description'] ?? ''}';
            postEmbedding = await generateEmbedding(postText);
          }

          // Calculate comprehensive match score
          final score = await _calculateMatchScore(
            userIntent: userIntent,
            userEmbedding: userEmbedding,
            userAnswers: userAnswers,
            userLat: userLat,
            userLon: userLon,
            postData: postData,
            postEmbedding: postEmbedding,
          );

          if (score.totalScore > 0.5) {
            matches.add(
              MatchResult(
                postId: doc.id,
                userId: postData['userId'] ?? '',
                score: score.totalScore,
                reasons: score.reasons,
                concerns: score.concerns,
                postData: postData,
                breakdown: score.breakdown,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error processing post ${doc.id}: $e');
          continue;
        }
      }

      // Sort by score descending
      matches.sort((a, b) => b.score.compareTo(a.score));

      // Return top matches
      return matches.take(limit).toList();
    } catch (e) {
      debugPrint('Error finding matches: $e');
      return [];
    }
  }

  /// Calculate comprehensive match score using multiple factors
  Future<MatchScore> _calculateMatchScore({
    required IntentAnalysis userIntent,
    required List<double> userEmbedding,
    required Map<String, dynamic> userAnswers,
    double? userLat,
    double? userLon,
    required Map<String, dynamic> postData,
    required List<double> postEmbedding,
  }) async {
    double totalScore = 0.0;
    final reasons = <String>[];
    final concerns = <String>[];
    final breakdown = <String, double>{};

    // 1. INTENT COMPATIBILITY (40% weight)
    final intentScore = await _calculateIntentCompatibility(
      userIntent,
      postData,
    );
    breakdown['intent'] = intentScore;
    totalScore += intentScore * ApiConfig.intentMatchWeight;

    if (intentScore > 0.7) {
      reasons.add('Perfectly matching intents');
    } else if (intentScore < 0.3) {
      concerns.add('Intents may not be complementary');
    }

    // 2. SEMANTIC SIMILARITY (30% weight)
    final semanticScore = _calculateCosineSimilarity(
      userEmbedding,
      postEmbedding,
    );
    breakdown['semantic'] = semanticScore;
    totalScore += semanticScore * ApiConfig.semanticMatchWeight;

    if (semanticScore > 0.8) {
      reasons.add('Very similar descriptions');
    }

    // 3. LOCATION PROXIMITY (15% weight)
    final locationScore = _calculateLocationScore(
      userLat,
      userLon,
      postData['latitude']?.toDouble(),
      postData['longitude']?.toDouble(),
    );
    breakdown['location'] = locationScore;
    totalScore += locationScore * ApiConfig.locationMatchWeight;

    if (locationScore > 0.8) {
      reasons.add('Very close location');
    } else if (locationScore < 0.2) {
      concerns.add('Location might be far');
    }

    // 4. TIME/RECENCY (10% weight)
    final timeScore = _calculateTimeScore(postData['createdAt'] as Timestamp?);
    breakdown['time'] = timeScore;
    totalScore += timeScore * ApiConfig.timeMatchWeight;

    if (timeScore > 0.8) {
      reasons.add('Recently posted');
    }

    // 5. KEYWORD MATCH (5% weight)
    final keywordScore = _calculateKeywordMatch(
      userIntent.searchKeywords,
      postData['keywords'] != null
          ? List<String>.from(postData['keywords'])
          : [],
    );
    breakdown['keywords'] = keywordScore;
    totalScore += keywordScore * ApiConfig.keywordMatchWeight;

    // Normalize total score
    totalScore = totalScore.clamp(0.0, 1.0);

    return MatchScore(
      totalScore: totalScore,
      reasons: reasons,
      concerns: concerns,
      breakdown: breakdown,
    );
  }

  /// Calculate intent compatibility
  Future<double> _calculateIntentCompatibility(
    IntentAnalysis userIntent,
    Map<String, dynamic> postData,
  ) async {
    // Check if post has intent analysis
    if (postData['intent_analysis'] == null) {
      // Fallback: Check action types
      final postAction = postData['action_type'] as String?;
      if (postAction == null) return 0.5;

      // Complementary actions score higher
      if ((userIntent.actionType == 'seeking' && postAction == 'offering') ||
          (userIntent.actionType == 'offering' && postAction == 'seeking')) {
        return 1.0;
      }

      return 0.3;
    }

    final postIntent = IntentAnalysis.fromJson(postData['intent_analysis']);

    // Check if intents are complementary
    if (userIntent.complementaryIntents.any(
      (ci) => postIntent.primaryIntent.toLowerCase().contains(ci.toLowerCase()),
    )) {
      return 1.0;
    }

    // Check action type compatibility
    if ((userIntent.actionType == 'seeking' &&
            postIntent.actionType == 'offering') ||
        (userIntent.actionType == 'offering' &&
            postIntent.actionType == 'seeking')) {
      return 0.9;
    }

    // Similar intents
    if (userIntent.actionType == postIntent.actionType) {
      return 0.4;
    }

    return 0.2;
  }

  /// Calculate cosine similarity between embeddings
  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.isEmpty || vec2.isEmpty || vec1.length != vec2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return (dotProduct / (sqrt(norm1) * sqrt(norm2))).clamp(-1.0, 1.0);
  }

  /// Calculate location-based score (rejects stale/null-island coords)
  double _calculateLocationScore(
    double? userLat,
    double? userLon,
    double? postLat,
    double? postLon,
  ) {
    if (userLat == null ||
        userLon == null ||
        postLat == null ||
        postLon == null) {
      return 0.5; // Neutral score if no location data
    }
    // Reject null-island coordinates
    if (userLat.abs() < 0.01 && userLon.abs() < 0.01) return 0.5;
    if (postLat.abs() < 0.01 && postLon.abs() < 0.01) return 0.5;

    final distance = _calculateDistance(userLat, userLon, postLat, postLon);

    // Skip unrealistic distances (likely stale Mountain View data)
    if (distance > 10000) return 0.5;

    // Score based on distance
    if (distance < 5) return 1.0;
    if (distance < 10) return 0.8;
    if (distance < 25) return 0.6;
    if (distance < 50) return 0.4;
    if (distance < 100) return 0.2;
    return 0.0;
  }

  /// Calculate time/recency score
  double _calculateTimeScore(Timestamp? createdAt) {
    if (createdAt == null) return 0.5;

    final age = DateTime.now().difference(createdAt.toDate());

    if (age.inHours < 1) return 1.0;
    if (age.inHours < 24) return 0.8;
    if (age.inDays < 3) return 0.6;
    if (age.inDays < 7) return 0.4;
    if (age.inDays < 30) return 0.2;
    return 0.1;
  }

  /// Calculate keyword match score
  double _calculateKeywordMatch(
    List<String> keywords1,
    List<String> keywords2,
  ) {
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;

    final set1 = keywords1.map((k) => k.toLowerCase()).toSet();
    final set2 = keywords2.map((k) => k.toLowerCase()).toSet();

    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    if (union.isEmpty) return 0.0;

    return intersection.length / union.length;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  //    POST MANAGEMENT

  /// Create a new post with AI analysis
  Future<String> createPost({
    required String userInput,
    required IntentAnalysis intent,
    required Map<String, dynamic> clarificationAnswers,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? images,
  }) async {
    await _ensureInitialized();

    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Generate embedding
      final text = '${intent.primaryIntent} ${intent.searchKeywords.join(' ')}';
      final embedding = await generateEmbedding(text);

      // Create post data
      final postData = {
        'userId': user.uid,
        'originalInput': userInput,
        'intent_analysis': intent.toJson(),
        'clarification_answers': clarificationAnswers,
        'embedding': embedding,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'images': images ?? [],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'matchedUserIds': [],
        'action_type': intent.actionType,
        'keywords': intent.searchKeywords,
      };

      final docRef = await _firestore
          .collection(ApiConfig.postsCollection)
          .add(postData);

      debugPrint(' Post created: ${docRef.id}');

      // Trigger real-time matching
      _triggerRealTimeMatching(docRef.id, intent, embedding);

      return docRef.id;
    } catch (e) {
      debugPrint(' Error creating post: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  /// Trigger real-time matching for a new post
  void _triggerRealTimeMatching(
    String postId,
    IntentAnalysis intent,
    List<double> embedding,
  ) {
    // Run matching in background
    Future.microtask(() async {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        final matches = await findMatches(
          userId: user.uid,
          userIntent: intent,
          userAnswers: {},
          limit: 10,
        );

        // Store top matches
        if (matches.isNotEmpty) {
          await _storeMatches(postId, matches);
        }
      } catch (e) {
        debugPrint('Error in real-time matching: $e');
      }
    });
  }

  /// Store match relationships
  Future<void> _storeMatches(String postId, List<MatchResult> matches) async {
    try {
      final batch = _firestore.batch();

      for (final match in matches.take(10)) {
        final matchDoc = _firestore
            .collection(ApiConfig.matchesCollection)
            .doc();
        batch.set(matchDoc, {
          'post1Id': postId,
          'post2Id': match.postId,
          'user1Id': _auth.currentUser?.uid,
          'user2Id': match.userId,
          'matchScore': match.score,
          'reasons': match.reasons,
          'concerns': match.concerns,
          'breakdown': match.breakdown,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error storing matches: $e');
    }
  }

  //    UTILITY METHODS

  /// Returns zero vector — backend API handles real embeddings.
  List<double> _generateFallbackEmbedding(String text) {
    return List.filled(768, 0.0);
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() => _cache.getStatistics();

  /// Clear all caches
  void clearCache() => _cache.clearAll();
}

//    DATA CLASSES

/// Intent analysis result
class IntentAnalysis {
  final String primaryIntent;
  final String actionType;
  final Map<String, dynamic> entities;
  final List<String> complementaryIntents;
  final List<String> clarificationsNeeded;
  final List<String> searchKeywords;
  final String emotionalTone;
  final MatchCriteria matchCriteria;

  IntentAnalysis({
    required this.primaryIntent,
    required this.actionType,
    required this.entities,
    required this.complementaryIntents,
    required this.clarificationsNeeded,
    required this.searchKeywords,
    required this.emotionalTone,
    required this.matchCriteria,
  });

  factory IntentAnalysis.fromJson(Map<String, dynamic> json) {
    return IntentAnalysis(
      primaryIntent: json['primary_intent'] ?? '',
      actionType: json['action_type'] ?? 'neutral',
      entities: json['entities'] ?? {},
      complementaryIntents: List<String>.from(
        json['complementary_intents'] ?? [],
      ),
      clarificationsNeeded: List<String>.from(
        json['clarifications_needed'] ?? [],
      ),
      searchKeywords: List<String>.from(json['search_keywords'] ?? []),
      emotionalTone: json['emotional_tone'] ?? 'casual',
      matchCriteria: MatchCriteria.fromJson(json['match_criteria'] ?? {}),
    );
  }

  factory IntentAnalysis.fallback(String input) {
    return IntentAnalysis(
      primaryIntent: input,
      actionType: 'neutral',
      entities: {},
      complementaryIntents: [],
      clarificationsNeeded: ['More details needed'],
      searchKeywords: input.split(' '),
      emotionalTone: 'casual',
      matchCriteria: MatchCriteria.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_intent': primaryIntent,
      'action_type': actionType,
      'entities': entities,
      'complementary_intents': complementaryIntents,
      'clarifications_needed': clarificationsNeeded,
      'search_keywords': searchKeywords,
      'emotional_tone': emotionalTone,
      'match_criteria': matchCriteria.toJson(),
    };
  }
}

/// Match criteria
class MatchCriteria {
  final List<String> mustHave;
  final List<String> niceToHave;
  final List<String> dealBreakers;

  MatchCriteria({
    required this.mustHave,
    required this.niceToHave,
    required this.dealBreakers,
  });

  factory MatchCriteria.fromJson(Map<String, dynamic> json) {
    return MatchCriteria(
      mustHave: List<String>.from(json['must_have'] ?? []),
      niceToHave: List<String>.from(json['nice_to_have'] ?? []),
      dealBreakers: List<String>.from(json['deal_breakers'] ?? []),
    );
  }

  factory MatchCriteria.empty() {
    return MatchCriteria(mustHave: [], niceToHave: [], dealBreakers: []);
  }

  Map<String, dynamic> toJson() {
    return {
      'must_have': mustHave,
      'nice_to_have': niceToHave,
      'deal_breakers': dealBreakers,
    };
  }
}

/// Clarifying question
class ClarifyingQuestion {
  final String id;
  final String question;
  final String type;
  final List<String>? options;
  final String importance;
  final String reason;

  ClarifyingQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    required this.importance,
    required this.reason,
  });

  factory ClarifyingQuestion.fromJson(Map<String, dynamic> json) {
    return ClarifyingQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      type: json['type'] ?? 'text',
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
      importance: json['importance'] ?? 'helpful',
      reason: json['reason'] ?? '',
    );
  }
}

/// Match result
class MatchResult {
  final String postId;
  final String userId;
  final double score;
  final List<String> reasons;
  final List<String> concerns;
  final Map<String, dynamic> postData;
  final Map<String, double> breakdown;

  MatchResult({
    required this.postId,
    required this.userId,
    required this.score,
    required this.reasons,
    required this.concerns,
    required this.postData,
    required this.breakdown,
  });
}

/// Match score breakdown
class MatchScore {
  final double totalScore;
  final List<String> reasons;
  final List<String> concerns;
  final Map<String, double> breakdown;

  MatchScore({
    required this.totalScore,
    required this.reasons,
    required this.concerns,
    required this.breakdown,
  });
}
