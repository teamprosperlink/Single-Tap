import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'location_services/gemini_service.dart';
import '../models/post_model.dart';

/// Unified Post Service - Single source of truth for all post operations
///
/// This service:
/// - Creates posts in ONE collection only (posts)
/// - Ensures all posts have embeddings
/// - Handles intent analysis automatically
/// - Provides matching functionality
/// - No data fragmentation
class UnifiedPostService {
  static final UnifiedPostService _instance = UnifiedPostService._internal();
  factory UnifiedPostService() => _instance;
  UnifiedPostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();

  /// Create a new post with automatic AI processing
  Future<Map<String, dynamic>> createPost({
    required String originalPrompt,
    Map<String, dynamic>? clarificationAnswers,
    double? price,
    double? priceMin,
    double? priceMax,
    String? currency,
    List<String>? images,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile for location context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.data() ?? {};

      // Use provided location or user's profile location
      final postLocation = location ?? userProfile['location'];
      final postLatitude = latitude ?? userProfile['latitude']?.toDouble();
      final postLongitude = longitude ?? userProfile['longitude']?.toDouble();

      debugPrint(' Creating post: $originalPrompt');

      // Step 1: Analyze intent with AI
      final intentAnalysis = await _analyzeIntent(
        originalPrompt,
        clarificationAnswers ?? {},
      );

      debugPrint(' Intent analyzed: ${intentAnalysis['primary_intent']}');

      // Step 2: Generate title and description
      final title = intentAnalysis['title'] ?? _generateTitle(originalPrompt);
      final description = intentAnalysis['description'] ?? originalPrompt;

      // Step 3: Generate embedding for semantic matching
      final embeddingText = _createTextForEmbedding(
        title: title,
        description: description,
        location: postLocation,
        domain: intentAnalysis['domain'],
        actionType: intentAnalysis['action_type'],
      );

      final embedding = await _geminiService.generateEmbedding(embeddingText);

      debugPrint(' Embedding generated: ${embedding.length} dimensions');

      // Step 4: Extract keywords for search
      final keywords = _extractKeywords('$title $description');

      // Get user name and photo for display
      // Fallback to phone number for phone login users
      String? userName = userProfile['name'] ?? userProfile['displayName'];
      if (userName == null || userName.isEmpty || userName == 'User') {
        userName = userProfile['phone'];
      }
      final userPhoto =
          userProfile['photoUrl'] ??
          userProfile['photoURL'] ??
          userProfile['profileImageUrl'];

      // Step 5: Create PostModel
      final post = PostModel(
        id: '', // Will be set by Firestore
        userId: userId,
        originalPrompt: originalPrompt,
        title: title,
        description: description,
        intentAnalysis: intentAnalysis,
        embedding: embedding,
        keywords: keywords,
        images: images,
        metadata: {
          'createdBy': 'UnifiedPostService',
          'version': '2.0',
          'embeddingModel': 'gemini-embedding',
        },
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        location: postLocation,
        latitude: postLatitude,
        longitude: postLongitude,
        price: price,
        priceMin: priceMin,
        priceMax: priceMax,
        currency: currency ?? 'USD',
        clarificationAnswers: clarificationAnswers ?? {},
        viewCount: 0,
        matchedUserIds: [],
        userName: userName,
        userPhoto: userPhoto,
      );

      // Step 6: Validate post before storing
      _validatePost(post);

      // Step 7: Store in posts collection ONLY
      final docRef = await _firestore
          .collection('posts')
          .add(post.toFirestore());

      debugPrint(' Post created successfully: ${docRef.id}');

      return {
        'success': true,
        'postId': docRef.id,
        'post': post.toFirestore(),
        'message': 'Post created successfully',
      };
    } catch (e) {
      debugPrint(' Error creating post: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create post',
      };
    }
  }

  /// Analyze user intent with AI
  Future<Map<String, dynamic>> _analyzeIntent(
    String userInput,
    Map<String, dynamic> clarificationAnswers,
  ) async {
    try {
      final prompt =
          '''
Analyze this user request and extract intent information:
"$userInput"

${clarificationAnswers.isNotEmpty ? 'User provided clarifications: $clarificationAnswers' : ''}

Return ONLY valid JSON with this structure:
{
  "primary_intent": "what user wants (e.g., buying, selling, dating, friendship, etc.)",
  "action_type": "offering/seeking/neutral",
  "domain": "marketplace/social/jobs/housing/services/etc",
  "title": "short title (max 50 chars)",
  "description": "detailed description",
  "entities": {
    "item": "main item/service mentioned",
    "category": "category"
  },
  "search_keywords": ["keyword1", "keyword2", "keyword3"],
  "confidence": 0.0-1.0
}

Examples:
- "selling iPhone 13" → primary_intent: "sell iPhone 13", action_type: "offering", domain: "marketplace"
- "need plumber" → primary_intent: "plumber service", action_type: "seeking", domain: "services"
- "looking for friend" → primary_intent: "friendship", action_type: "seeking", domain: "social"
''';

      final response = await _geminiService.generateContent(prompt);

      if (response != null && response.isNotEmpty) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          return _parseIntentJson(jsonStr);
        }
      }

      // Fallback if AI fails
      return _createFallbackIntent(userInput);
    } catch (e) {
      debugPrint('   Error analyzing intent: $e');
      return _createFallbackIntent(userInput);
    }
  }

  /// Parse intent JSON from AI response
  Map<String, dynamic> _parseIntentJson(String jsonStr) {
    try {
      // Clean JSON string
      jsonStr = jsonStr.replaceAll(RegExp(r'[\n\r\t]'), ' ');
      jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ');

      // Extract fields manually (safer than json.decode for AI output)
      final primaryIntentMatch = RegExp(
        r'"primary_intent":\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      final actionTypeMatch = RegExp(
        r'"action_type":\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      final domainMatch = RegExp(r'"domain":\s*"([^"]+)"').firstMatch(jsonStr);
      final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(jsonStr);
      final descriptionMatch = RegExp(
        r'"description":\s*"([^"]+)"',
      ).firstMatch(jsonStr);

      return {
        'primary_intent': primaryIntentMatch?.group(1) ?? 'general',
        'action_type': actionTypeMatch?.group(1) ?? 'neutral',
        'domain': domainMatch?.group(1) ?? 'general',
        'title': titleMatch?.group(1),
        'description': descriptionMatch?.group(1),
        'entities': {},
        'search_keywords': [],
        'confidence': 0.8,
      };
    } catch (e) {
      debugPrint('   Error parsing intent JSON: $e');
      return _createFallbackIntent(jsonStr);
    }
  }

  /// Create fallback intent when AI fails
  Map<String, dynamic> _createFallbackIntent(String userInput) {
    return {
      'primary_intent': userInput,
      'action_type': 'neutral',
      'domain': 'general',
      'title': userInput.length > 50
          ? '${userInput.substring(0, 47)}...'
          : userInput,
      'description': userInput,
      'entities': {},
      'search_keywords': userInput.toLowerCase().split(' '),
      'confidence': 0.5,
    };
  }

  /// Generate title from prompt
  String _generateTitle(String prompt) {
    if (prompt.length <= 50) return prompt;
    return '${prompt.substring(0, 47)}...';
  }

  /// Create text for embedding generation
  String _createTextForEmbedding({
    required String title,
    required String description,
    String? location,
    String? domain,
    String? actionType,
  }) {
    final parts = <String>[title, description];
    if (location != null && location.isNotEmpty) {
      parts.add('Location: $location');
    }
    if (domain != null && domain.isNotEmpty) {
      parts.add('Domain: $domain');
    }
    if (actionType != null && actionType.isNotEmpty) {
      parts.add('Action: $actionType');
    }
    return parts.join(' ');
  }

  /// Extract keywords from text
  List<String> _extractKeywords(String text) {
    final stopWords = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'must',
      'shall',
      'can',
      'need',
      'dare',
      'ought',
      'used',
      'to',
      'of',
      'in',
      'for',
      'on',
      'with',
      'at',
      'by',
      'from',
      'as',
      'into',
      'through',
      'during',
      'before',
      'after',
      'above',
      'below',
      'between',
      'under',
      'again',
      'further',
      'then',
      'once',
      'and',
      'but',
      'or',
      'nor',
      'so',
      'yet',
      'both',
      'either',
      'neither',
      'not',
      'only',
      'own',
      'same',
      'than',
      'too',
      'very',
      'just',
      'i',
      'me',
      'my',
      'myself',
      'we',
      'our',
      'ours',
      'you',
      'your',
      'he',
      'him',
      'his',
      'she',
      'her',
      'it',
      'its',
      'they',
      'them',
      'their',
      'what',
      'which',
      'who',
      'whom',
      'this',
      'that',
      'these',
      'those',
      'am',
    };

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toSet()
        .take(20)
        .toList();
  }

  /// Validate post before storing
  void _validatePost(PostModel post) {
    if (post.userId.isEmpty) {
      throw Exception('Post must have userId');
    }
    if (post.originalPrompt.isEmpty) {
      throw Exception('Post must have originalPrompt');
    }
    if (post.embedding == null || post.embedding!.isEmpty) {
      throw Exception('Post must have embedding');
    }
    if (post.title.isEmpty) {
      throw Exception('Post must have title');
    }
  }

  /// Find matching posts for a given post
  Future<List<PostModel>> findMatches(String postId) async {
    try {
      // Get the source post
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final sourcePost = PostModel.fromFirestore(postDoc);
      final sourceEmbedding = sourcePost.embedding ?? [];

      if (sourceEmbedding.isEmpty) {
        debugPrint(' Source post has no embedding, regenerating...');
        // Regenerate embedding
        final embeddingText = _createTextForEmbedding(
          title: sourcePost.title,
          description: sourcePost.description,
          location: sourcePost.location,
        );
        final newEmbedding = await _geminiService.generateEmbedding(
          embeddingText,
        );

        await postDoc.reference.update({
          'embedding': newEmbedding,
          'embeddingUpdatedAt': FieldValue.serverTimestamp(),
        });

        return findMatches(postId); // Retry with new embedding
      }

      debugPrint(' Finding matches for: ${sourcePost.title}');

      // Query active posts (exclude own posts)
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('userId', isNotEqualTo: sourcePost.userId)
          .limit(100)
          .get();

      List<PostModel> matches = [];

      for (var doc in querySnapshot.docs) {
        final candidatePost = PostModel.fromFirestore(doc);
        final candidateEmbedding = candidatePost.embedding ?? [];

        // Skip if no embedding
        if (candidateEmbedding.isEmpty) {
          debugPrint(' Skipping post ${doc.id} - no embedding');
          continue;
        }

        // Calculate semantic similarity
        final similarity = _geminiService.calculateSimilarity(
          sourceEmbedding,
          candidateEmbedding,
        );

        // Check if intents match (complementary)
        final intentMatch = sourcePost.matchesIntent(candidatePost);

        // Check if price matches
        final priceMatch = sourcePost.matchesPrice(candidatePost);

        // Calculate final match score
        final matchScore =
            (similarity * 0.6) +
            (intentMatch ? 0.3 : 0.0) +
            (priceMatch ? 0.1 : 0.0);

        // Only include good matches (score > 0.65)
        if (matchScore > 0.65) {
          matches.add(candidatePost.copyWith(similarityScore: matchScore));
          debugPrint(
            ' Match found: ${candidatePost.title} (score: ${matchScore.toStringAsFixed(2)})',
          );
        }
      }

      // Sort by match score
      matches.sort(
        (a, b) => (b.similarityScore ?? 0).compareTo(a.similarityScore ?? 0),
      );

      debugPrint(' Total matches found: ${matches.length}');

      return matches.take(20).toList();
    } catch (e) {
      debugPrint(' Error finding matches: $e');
      return [];
    }
  }

  /// Get user's active posts
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('  Error getting user posts: $e');
      return [];
    }
  }

  /// Deactivate a post (soft delete)
  Future<bool> deactivatePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('  Error deactivating post: $e');
      return false;
    }
  }

  /// Permanently delete a post
  Future<bool> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      return true;
    } catch (e) {
      debugPrint('  Error deleting post: $e');
      return false;
    }
  }

  /// Stream user's active posts
  Stream<List<PostModel>> streamUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Increment view count
  Future<void> incrementViewCount(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('   Error incrementing view count: $e');
    }
  }

  /// Add matched user ID
  Future<void> addMatchedUser(String postId, String matchedUserId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'matchedUserIds': FieldValue.arrayUnion([matchedUserId]),
      });
    } catch (e) {
      debugPrint('   Error adding matched user: $e');
    }
  }
}

/// Extension to add copyWith method to PostModel
extension PostModelExtension on PostModel {
  PostModel copyWith({
    String? id,
    String? userId,
    String? originalPrompt,
    String? title,
    String? description,
    Map<String, dynamic>? intentAnalysis,
    List<String>? images,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    List<double>? embedding,
    List<String>? keywords,
    double? similarityScore,
    String? location,
    double? latitude,
    double? longitude,
    double? price,
    double? priceMin,
    double? priceMax,
    String? currency,
    int? viewCount,
    List<String>? matchedUserIds,
    Map<String, dynamic>? clarificationAnswers,
    String? gender,
    String? ageRange,
    String? condition,
    String? brand,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      title: title ?? this.title,
      description: description ?? this.description,
      intentAnalysis: intentAnalysis ?? this.intentAnalysis,
      images: images ?? this.images,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      embedding: embedding ?? this.embedding,
      keywords: keywords ?? this.keywords,
      similarityScore: similarityScore ?? this.similarityScore,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      price: price ?? this.price,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      currency: currency ?? this.currency,
      viewCount: viewCount ?? this.viewCount,
      matchedUserIds: matchedUserIds ?? this.matchedUserIds,
      clarificationAnswers: clarificationAnswers ?? this.clarificationAnswers,
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
    );
  }
}
