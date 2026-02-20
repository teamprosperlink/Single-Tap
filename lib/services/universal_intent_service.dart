import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'unified_post_service.dart';
import '../models/post_model.dart';

class UniversalIntentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Process user intent and find matches using UnifiedPostService
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

        // Resolve user name — prefer post-stored name, fall back to profile fields
        final resolvedName =
            (match.userName?.isNotEmpty == true ? match.userName : null) ??
            userProfile?['name'] ??
            userProfile?['displayName'] ??
            userProfile?['phone'] ??
            'User';

        enrichedMatches.add({
          'id': match.id,
          'userId': match.userId,
          'userName': resolvedName,
          'title': match.title,
          'description': match.description,
          'text': match.originalPrompt, // used by MatchCardWithActions
          'originalPrompt': match.originalPrompt,
          'intentAnalysis': match.intentAnalysis,
          'location': match.location ?? userProfile?['location'],
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
