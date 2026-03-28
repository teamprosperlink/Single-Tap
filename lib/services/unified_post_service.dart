import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import 'location_services/gemini_service.dart';

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

      // Use provided location or user's profile location (reject Mountain View)
      final profileCity = (userProfile['city'] as String? ?? '').toLowerCase();
      final profileLat = userProfile['latitude']?.toDouble();
      final profileLng = userProfile['longitude']?.toDouble();
      final isMV = profileCity.contains('mountain view') ||
          (profileLat != null && profileLng != null &&
           (profileLat - 37.422).abs() < 0.05 && (profileLng + 122.084).abs() < 0.05);
      final isNI = profileLat != null && profileLng != null &&
          (profileLat as double).abs() < 0.01 && (profileLng as double).abs() < 0.01;
      final postLocation = location ?? (isMV ? null : userProfile['location']);
      final postLatitude = latitude ?? ((isMV || isNI) ? null : profileLat);
      final postLongitude = longitude ?? ((isMV || isNI) ? null : profileLng);

      debugPrint(' Creating post: $originalPrompt');

      // Step 1: Analyze intent (local fallback — backend API handles AI)
      final intentAnalysis = _createFallbackIntent(originalPrompt);

      debugPrint(' Intent analyzed: ${intentAnalysis['primary_intent']}');

      // Step 2: Generate title and description
      final title = intentAnalysis['title'] ?? _generateTitle(originalPrompt);
      final description = intentAnalysis['description'] ?? originalPrompt;

      // Embedding not needed — backend /search-and-match handles matching
      final List<double> embedding = [];

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

  /// Create intent from user input (local parsing — backend API handles AI).
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

  /// Cosine similarity between two embedding vectors (pure math, no API)
  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.isEmpty || vec2.isEmpty || vec1.length != vec2.length) return 0.0;
    double dot = 0.0, norm1 = 0.0, norm2 = 0.0;
    for (int i = 0; i < vec1.length; i++) {
      dot += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return (dot / (sqrt(norm1) * sqrt(norm2))).clamp(-1.0, 1.0);
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

  // ── Business post sync ──────────────────────────────────────────────────

  /// Sync a business profile as a discoverable post in the posts collection.
  Future<void> syncBusinessPost(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) return;
      if (userData['accountType'] != 'business') return;

      final bp = userData['businessProfile'] as Map<String, dynamic>?;
      if (bp == null) return;

      final businessName = bp['businessName'] as String? ?? '';
      if (businessName.isEmpty) return;

      final description = bp['description'] as String? ?? '';
      final softLabel = bp['softLabel'] as String? ?? '';
      final address = bp['address'] as String? ?? '';

      // Get available catalog items
      final catalogSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('catalog')
          .where('isAvailable', isEqualTo: true)
          .limit(50)
          .get();

      final catalogNames = <String>[];
      for (final doc in catalogSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        if (name.isNotEmpty) catalogNames.add(name);
      }
      final catalogSummary = catalogNames.join(', ');

      // Build rich text for embedding
      final embeddingParts = <String>[businessName];
      if (softLabel.isNotEmpty) embeddingParts.add(softLabel);
      if (description.isNotEmpty) embeddingParts.add(description);
      if (catalogSummary.isNotEmpty) {
        embeddingParts.add('Services and Products: $catalogSummary');
      }

      final embeddingText = '$businessName $softLabel $description $catalogSummary';

      final gemini = GeminiService();
      final embedding = await gemini.generateEmbedding(embeddingText);
      final keywords = _extractKeywords(
        '$businessName $softLabel $description $catalogSummary',
      );

      final userPhoto = userData['photoUrl'] ??
          userData['photoURL'] ??
          userData['profileImageUrl'];

      final postTitle = softLabel.isNotEmpty
          ? softLabel
          : catalogSummary.isNotEmpty
              ? 'Offering: $catalogSummary'
              : businessName;

      final postDescription = description.isNotEmpty
          ? description
          : catalogSummary.isNotEmpty
              ? catalogSummary
              : 'Business services';

      final postData = {
        'userId': userId,
        'originalPrompt': embeddingParts.join('. '),
        'title': postTitle,
        'description': postDescription,
        'intentAnalysis': {
          'primary_intent': 'Business offering $softLabel services/products',
          'action_type': 'offering',
          'domain': softLabel.isNotEmpty ? softLabel.toLowerCase() : 'services',
          'service_type': 'in_person',
          'is_symmetric': false,
          'exchange_model': 'paid',
          'complementary_intents': [
            'looking for $softLabel',
            'need $softLabel services',
            if (catalogNames.isNotEmpty) 'looking for ${catalogNames.first}',
          ],
          'search_keywords': keywords,
        },
        'embedding': embedding,
        'keywords': keywords,
        'metadata': {
          'createdBy': 'BusinessProfileSync',
          'version': '2.0',
          'isBusinessPost': true,
          'businessName': businessName,
          'softLabel': softLabel,
          'catalogItemCount': catalogSnap.docs.length,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'isActive': true,
        'location': userData['location'] ?? address,
        'latitude': userData['latitude'],
        'longitude': userData['longitude'],
        'viewCount': 0,
        'matchedUserIds': [],
        'clarificationAnswers': {},
        'userName': businessName,
        'userPhoto': userPhoto,
        'action_type': 'offering',
      };

      await _firestore
          .collection('posts')
          .doc('business_$userId')
          .set(postData);

      debugPrint(
        ' Business post synced for $businessName (${catalogNames.length} catalog items)',
      );
    } catch (e) {
      debugPrint('Error syncing business post: $e');
    }
  }

  /// Re-sync the current user's business post if it was created with an older
  /// version (stale embeddings / missing domain). Called on business hub load.
  Future<void> resyncIfStale(String userId) async {
    try {
      final doc = await _firestore.collection('posts').doc('business_$userId').get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final version = metadata?['version'] as String?;
      if (version != '2.0') {
        debugPrint('Business post stale (version=$version), re-syncing...');
        await syncBusinessPost(userId);
      }
    } catch (e) {
      debugPrint('Error checking business post staleness: $e');
    }
  }

  /// Search business posts by semantic similarity to a user's query.
  /// Returns card-format maps compatible with HomeScreen's _buildItemCard().
  Future<List<Map<String, dynamic>>> searchBusinessPosts({
    required String query,
    required List<double> queryEmbedding,
    double? userLat,
    double? userLng,
    int limit = 5,
    double similarityThreshold = 0.45,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    try {
      // Query active posts – filter isBusinessPost client-side because
      // Firestore can't filter on nested map fields in a composite index.
      final snap = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .limit(100)
          .get();

      // Extract query keywords for keyword-overlap scoring
      final queryTerms = query
          .toLowerCase()
          .split(RegExp(r'[\s,;.!?()"\-_/]+'))
          .where((w) => w.length > 1)
          .toSet();

      final scored = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();

        // Must be a business post
        final metadata = data['metadata'] as Map<String, dynamic>?;
        if (metadata == null || metadata['isBusinessPost'] != true) continue;

        // Skip own business
        final postUserId = data['userId'] as String? ?? '';
        if (postUserId == currentUid) continue;

        // Require non-empty embedding
        final rawEmb = data['embedding'];
        if (rawEmb == null) continue;
        final embedding = List<double>.from(rawEmb);
        if (embedding.isEmpty || embedding.every((v) => v == 0.0)) continue;

        // Cosine similarity
        final similarity = _calculateCosineSimilarity(queryEmbedding, embedding);
        if (similarity < similarityThreshold) continue;

        // Keyword overlap score
        final postKeywords = (data['keywords'] as List<dynamic>?)
                ?.map((e) => e.toString().toLowerCase())
                .toSet() ??
            <String>{};
        final postText =
            '${data['originalPrompt'] ?? ''} ${data['title'] ?? ''} ${data['description'] ?? ''}'
                .toLowerCase();
        final allPostTerms = {
          ...postKeywords,
          ...postText
              .split(RegExp(r'[\s,;.!?()"\-_/]+'))
              .where((w) => w.length > 1),
        };
        final overlap = queryTerms.intersection(allPostTerms).length;
        final keywordScore =
            queryTerms.isEmpty ? 0.0 : (overlap / queryTerms.length).clamp(0.0, 1.0);

        // Location proximity bonus
        double locationBonus = 0.0;
        if (userLat != null && userLng != null) {
          final postLat = (data['latitude'] as num?)?.toDouble();
          final postLng = (data['longitude'] as num?)?.toDouble();
          if (postLat != null && postLng != null && (postLat != 0 || postLng != 0)) {
            final distKm = _haversineKm(userLat, userLng, postLat, postLng);
            if (distKm <= 10) {
              locationBonus = 1.0;
            } else if (distKm <= 25) {
              locationBonus = 0.7;
            } else if (distKm <= 50) {
              locationBonus = 0.4;
            }
            // Beyond 50 km → 0 bonus
          }
        }

        // Composite score
        final composite =
            (similarity * 0.65) + (keywordScore * 0.15) + (locationBonus * 0.20);
        if (composite < 0.40) continue;

        // Build card map
        final businessName =
            metadata['businessName'] as String? ?? data['userName'] as String? ?? '';
        final softLabel = metadata['softLabel'] as String? ?? '';

        scored.add({
          '_compositeScore': composite,
          // Card fields expected by _buildItemCard
          'name': businessName,
          'category': softLabel,
          'match_type': 'business',
          'similarity_score': composite,
          'match_score': '${(composite * 100).round()}%',
          'listing_id': doc.id,
          'user_id': postUserId,
          'userId': postUserId,
          'image': data['userPhoto'] as String? ?? '',
          'images': <String>[],
          'price': '',
          'location': '', // will be set by caller after merge
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          '_raw_location': {
            'lat': data['latitude'],
            'lng': data['longitude'],
          },
          '_isBusinessCard': true,
          '_businessUserId': postUserId,
          'smart_message': 'Business offering: ${data['title'] ?? businessName}',
          'userName': businessName,
          'userPhoto': data['userPhoto'] as String? ?? '',
          'brand': '',
          'model': '',
          'item_type': softLabel,
          'description': data['description'] as String? ?? '',
        });
      }

      // Sort by composite score descending and cap at limit
      scored.sort((a, b) =>
          (b['_compositeScore'] as double).compareTo(a['_compositeScore'] as double));
      return scored.take(limit).toList();
    } catch (e) {
      debugPrint('Error searching business posts: $e');
      return [];
    }
  }

  /// Haversine distance in kilometres between two coordinates.
  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
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
      var sourceEmbedding = sourcePost.embedding ?? [];

      if (sourceEmbedding.isEmpty) {
        debugPrint(' Source post has no embedding — skipping embedding-based matching');
        // No client-side embedding generation; backend API handles embeddings
      }

      debugPrint(' Finding matches for: ${sourcePost.title}');

      // Query active posts (exclude own posts)
      // Use try-catch for index fallback - composite index may not exist yet
      List<QueryDocumentSnapshot<Map<String, dynamic>>> candidateDocs;
      try {
        final querySnapshot = await _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .where('userId', isNotEqualTo: sourcePost.userId)
            .limit(100)
            .get();
        candidateDocs = querySnapshot.docs;
      } catch (indexError) {
        debugPrint(' Index not available, using fallback query: $indexError');
        // Fallback: query only by isActive and filter userId client-side
        final fallbackSnapshot = await _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(200)
            .get();
        candidateDocs = fallbackSnapshot.docs
            .where((doc) => doc.data()['userId'] != sourcePost.userId)
            .toList();
      }

      // Filter out dummy/invalid posts before matching
      candidateDocs.removeWhere((doc) {
        final data = doc.data();
        if (data['isDummyPost'] == true) return true;
        final uid = data['userId'] as String? ?? '';
        if (uid.isEmpty || uid.startsWith('dummy_')) return true;
        return false;
      });

      debugPrint(' Candidate posts to compare: ${candidateDocs.length} (after removing dummy)');

      List<PostModel> matches = [];

      // Extract search terms from source post for keyword matching
      final sourceTerms = _extractSearchTerms(sourcePost);

      // Pre-compute source search words for title relevance check
      final sourceWords = sourcePost.originalPrompt
          .toLowerCase()
          .split(RegExp(r'[\s,;.!?()"\-_/]+'))
          .where((w) => w.length > 2)
          .toSet();

      // Pre-compute source action direction (moved out of loop)
      const sameDirectionPairs = {
        'seeking', 'buying', 'requesting', 'looking', 'rent_seeking', 'job_seeking',
      };
      const offeringDirectionPairs = {
        'offering', 'selling', 'giving', 'hiring', 'renting',
      };
      const symmetricActions = {
        'meetup', 'dating', 'friendship', 'connecting', 'neutral',
      };
      final sourceAction = sourcePost.actionType.toLowerCase();
      final sourceIsSeeking = sameDirectionPairs.contains(sourceAction);
      final sourceIsOffering = offeringDirectionPairs.contains(sourceAction);
      final sourceIsSymmetric = symmetricActions.contains(sourceAction);

      int dbgNoEmbed = 0, dbgLowSim = 0, dbgDirection = 0, dbgLowScore = 0;

      for (var doc in candidateDocs) {
        final candidatePost = PostModel.fromFirestore(doc);
        final candidateEmbedding = candidatePost.embedding ?? [];

        if (candidateEmbedding.isEmpty) { dbgNoEmbed++; continue; }

        // Calculate semantic similarity (local cosine similarity)
        final similarity = _calculateCosineSimilarity(
          sourceEmbedding,
          candidateEmbedding,
        );

        if (similarity < 0.50) { dbgLowSim++; continue; }

        // Check intent direction
        final candidateAction = candidatePost.actionType.toLowerCase();
        final candidateIsSeeking = sameDirectionPairs.contains(candidateAction);
        final candidateIsOffering = offeringDirectionPairs.contains(candidateAction);
        final isSymmetric = sourceIsSymmetric || symmetricActions.contains(candidateAction);

        if (!isSymmetric &&
            ((sourceIsSeeking && candidateIsSeeking) ||
             (sourceIsOffering && candidateIsOffering))) {
          dbgDirection++;
          continue;
        }

        // Title/prompt relevance bonus: gives extra score when the search
        // term appears in the candidate's title/prompt/keywords.
        // This helps rank "iPhone" posts higher when searching "iPhone"
        // without blocking broad queries like "jobs".
        final candidateTitle = (candidatePost.title).toLowerCase();
        final candidatePrompt = (candidatePost.originalPrompt).toLowerCase();
        final candidateKeywords = (candidatePost.keywords ?? []).join(' ').toLowerCase();
        final hasTitleOverlap = sourceWords.any(
            (w) => candidateTitle.contains(w) || candidatePrompt.contains(w) || candidateKeywords.contains(w));
        final titleBonus = hasTitleOverlap ? 0.10 : 0.0;

        // Calculate keyword overlap score
        final candidateTerms = _extractSearchTerms(candidatePost);
        final commonTerms = sourceTerms.intersection(candidateTerms);
        final keywordScore = sourceTerms.isEmpty
            ? 0.0
            : (commonTerms.length / sourceTerms.length).clamp(0.0, 1.0);

        final intentMatch = sourcePost.matchesIntent(candidatePost);
        final priceMatch = sourcePost.matchesPrice(candidatePost);

        final matchScore =
            (similarity * 0.50) +
            (keywordScore * 0.10) +
            (titleBonus * 0.10) +
            (intentMatch ? 0.20 : 0.0) +
            (priceMatch ? 0.10 : 0.0);

        if (matchScore > 0.45) {
          matches.add(candidatePost.copyWith(similarityScore: matchScore));
        } else {
          dbgLowScore++;
        }
      }

      debugPrint(' MATCH FILTER: noEmbed=$dbgNoEmbed lowSim=$dbgLowSim direction=$dbgDirection lowScore=$dbgLowScore');

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

  /// Extract significant search terms from a post for keyword matching.
  Set<String> _extractSearchTerms(PostModel post) {
    final parts = <String>[
      post.originalPrompt,
      post.title,
      ...(post.keywords ?? []),
    ];
    // Common stop words to ignore
    const stopWords = {
      'i', 'a', 'an', 'the', 'is', 'am', 'are', 'was', 'for', 'and', 'or',
      'to', 'in', 'on', 'at', 'of', 'my', 'me', 'do', 'so', 'it', 'be',
      'we', 'he', 'she', 'this', 'that', 'with', 'from', 'not', 'but',
      'have', 'has', 'had', 'can', 'will', 'just', 'get', 'got', 'want',
      'need', 'looking', 'find', 'search', 'buy', 'sell', 'new', 'used',
    };
    return parts
        .join(' ')
        .toLowerCase()
        .split(RegExp(r'[\s,;.!?()"\-_/]+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toSet();
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
