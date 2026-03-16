import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'unified_post_service.dart';
import '../models/post_model.dart';

class UniversalIntentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Wrapper method for unified processor
  Future<Map<String, dynamic>> processIntent(String text) async {
    return await processIntentAndMatch(text);
  }

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

      // Reject Mountain View / null-island from user profile
      final profileCity = (userProfile['city'] as String? ?? '').toLowerCase();
      final profileLat = userProfile['latitude']?.toDouble();
      final profileLng = userProfile['longitude']?.toDouble();
      final isMV = profileCity.contains('mountain view') ||
          (profileLat != null && profileLng != null &&
           (profileLat - 37.422).abs() < 0.05 && (profileLng + 122.084).abs() < 0.05);
      final isNI = profileLat != null && profileLng != null &&
          (profileLat as double).abs() < 0.01 && (profileLng as double).abs() < 0.01;

      // Create post using unified service (stores in posts collection only)
      final result = await unifiedService.createPost(
        originalPrompt: userInput,
        location: isMV ? null : userProfile['location'],
        latitude: (isMV || isNI) ? null : profileLat,
        longitude: (isMV || isNI) ? null : profileLng,
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

  // Helper to enrich matches with user profiles (parallel batch fetch)
  Future<List<Map<String, dynamic>>> _enrichMatchesWithProfiles(
    List<PostModel> matches,
  ) async {
    if (matches.isEmpty) return [];

    // Fetch all user profiles in parallel instead of sequentially
    final userIds = matches.map((m) => m.userId).toSet().toList();
    final profileFutures = userIds.map(
      (uid) => _firestore.collection('users').doc(uid).get(),
    );
    final profileDocs = await Future.wait(profileFutures);

    // Build userId -> profile map
    final profileMap = <String, Map<String, dynamic>?>{};
    for (int i = 0; i < userIds.length; i++) {
      if (profileDocs[i].exists) {
        profileMap[userIds[i]] = profileDocs[i].data();
      }
    }

    // Build enriched matches
    return matches
        .where((match) => profileMap.containsKey(match.userId))
        .map((match) => {
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
              'userProfile': profileMap[match.userId],
              'createdAt': match.createdAt,
            })
        .toList();
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
