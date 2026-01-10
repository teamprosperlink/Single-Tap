import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'location services/gemini_service.dart';
import 'unified_post_service.dart';
import '../res/config/api_config.dart';
import '../models/post_model.dart';

class UniversalIntentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();
  late final GenerativeModel _model; // ignore: unused_field

  UniversalIntentService() {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  // No more rigid role mappings - we use semantic matching now
  // The AI understands complementary intents naturally

  // Wrapper method for unified processor
  Future<Map<String, dynamic>> processIntent(String text) async {
    return await processIntentAndMatch(text);
  }

  // Find matches for a given intent
  Future<List<Map<String, dynamic>>> findMatches(
    Map<String, dynamic> intent,
  ) async {
    // Use the intent to find matches
    final intents = await FirebaseFirestore.instance
        .collection('intents')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(20)
        .get();

    List<Map<String, dynamic>> matches = [];
    final intentEmbedding = intent['embedding'] as List<double>?;

    if (intentEmbedding != null) {
      for (var doc in intents.docs) {
        final data = doc.data();
        final docEmbedding = List<double>.from(data['embedding'] ?? []);

        if (docEmbedding.isNotEmpty) {
          final similarity = _geminiService.calculateSimilarity(
            intentEmbedding,
            docEmbedding,
          );
          if (similarity > 0.65) {
            data['id'] = doc.id;
            data['similarity'] = similarity;
            matches.add(data);
          }
        }
      }
    }

    // Sort by similarity
    matches.sort(
      (a, b) => (b['similarity'] ?? 0).compareTo(a['similarity'] ?? 0),
    );
    return matches.take(10).toList();
  }

  // UPDATED: Process user intent and find matches using UnifiedPostService
  Future<Map<String, dynamic>> processIntentAndMatch(String userInput) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get user profile for context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.data() ?? {};

      debugPrint(' Processing intent: $userInput');

      // Import and use UnifiedPostService
      final unifiedService = UnifiedPostService();

      // Create post using unified service (stores in posts collection only)
      final result = await unifiedService.createPost(
        originalPrompt: userInput,
        location: userProfile['location'],
        latitude: userProfile['latitude']?.toDouble(),
        longitude: userProfile['longitude']?.toDouble(),
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to create post');
      }

      final postId = result['postId'];
      debugPrint(' Post created: $postId');

      // Find matches using unified service
      final matches = await unifiedService.findMatches(postId);
      debugPrint(' Found ${matches.length} matches');

      // Convert matches to format expected by UI
      final matchesWithProfile = await _enrichMatchesWithProfiles(matches);

      return {
        'success': true,
        'intent': result['post'],
        'postId': postId,
        'matches': matchesWithProfile,
      };
    } catch (e) {
      debugPrint(' Error processing intent: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper to enrich matches with user profiles
  Future<List<Map<String, dynamic>>> _enrichMatchesWithProfiles(
    List<PostModel> matches,
  ) async {
    List<Map<String, dynamic>> enrichedMatches = [];

    for (var match in matches) {
      // Get user profile
      final userDoc = await _firestore
          .collection('users')
          .doc(match.userId)
          .get();

      if (userDoc.exists) {
        final userProfile = userDoc.data();

        enrichedMatches.add({
          'id': match.id,
          'userId': match.userId,
          'title': match.title,
          'description': match.description,
          'originalPrompt': match.originalPrompt,
          'intentAnalysis': match.intentAnalysis,
          'location': match.location,
          'latitude': match.latitude,
          'longitude': match.longitude,
          'price': match.price,
          'matchScore': match.similarityScore ?? 0.0,
          'userProfile': userProfile,
          'createdAt': match.createdAt,
        });
      }
    }

    return enrichedMatches;
  }

  // UPDATED: Get user's active posts (changed from user_intents to posts)
  Future<List<Map<String, dynamic>>> getUserIntents(String userId) async {
    try {
      debugPrint(' Getting user posts from posts collection');

      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint(' Error getting user posts: $e');
      return [];
    }
  }

  // UPDATED: Deactivate a post (uses posts collection)
  Future<void> deactivateIntent(String intentId) async {
    try {
      debugPrint(' Deactivating post: $intentId');
      final unifiedService = UnifiedPostService();
      await unifiedService.deactivatePost(intentId);
      debugPrint(' Post deactivated');
    } catch (e) {
      debugPrint(' Error deactivating post: $e');
    }
  }

  // UPDATED: Permanently delete a post (uses posts collection)
  Future<bool> deleteIntent(String intentId) async {
    try {
      debugPrint(' Deleting post: $intentId');
      final unifiedService = UnifiedPostService();
      final result = await unifiedService.deletePost(intentId);

      if (result) {
        debugPrint(' Post deleted successfully');
      } else {
        debugPrint(' Post deletion failed');
      }

      return result;
    } catch (e) {
      debugPrint(' Error deleting post: $e');
      return false;
    }
  }
}
