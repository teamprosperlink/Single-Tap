import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'location_services/gemini_service.dart';

class RealtimeMatchingService {
  static final RealtimeMatchingService _instance =
      RealtimeMatchingService._internal();
  factory RealtimeMatchingService() => _instance;
  RealtimeMatchingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final GeminiService _geminiService = GeminiService();

  StreamSubscription? _intentListener;
  StreamSubscription? _postListener;
  final Map<String, Timer> _notificationTimers = {};
  bool _isInitialized = false;

  // Initialize real-time listeners
  Future<void> initialize() async {
    if (_isInitialized) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isInitialized = true;

    // Listen for new posts from other users
    _listenForNewPosts(userId);

    debugPrint('RealtimeMatchingService initialized');
  }

  void _listenForNewPosts(String currentUserId) {
    _postListener = _firestore
        .collection('posts')
        .where('userId', isNotEqualTo: currentUserId)
        .where('createdAt', isGreaterThan: Timestamp.now())
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              await _checkPostMatch(change.doc, currentUserId);
            }
          }
        });

    debugPrint(' Listening for new posts in real-time');
  }

  Future<void> _checkPostMatch(
    DocumentSnapshot newPost,
    String currentUserId,
  ) async {
    try {
      // Get user's active posts
      final userPosts = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      if (userPosts.docs.isEmpty) return;

      final newPostData = newPost.data() as Map<String, dynamic>;
      var newEmbedding = List<double>.from(newPostData['embedding'] ?? []);

      // UPDATED: If embedding missing, generate it now
      if (newEmbedding.isEmpty) {
        debugPrint(
          '   New post ${newPost.id} missing embedding, generating...',
        );
        try {
          final text =
              '${newPostData['title'] ?? ''} ${newPostData['description'] ?? ''}';
          newEmbedding = await _geminiService.generateEmbedding(text);

          // Update document with embedding
          await newPost.reference.update({
            'embedding': newEmbedding,
            'embeddingUpdatedAt': FieldValue.serverTimestamp(),
          });

          debugPrint(' Embedding generated and saved for ${newPost.id}');
        } catch (e) {
          debugPrint(' Failed to generate embedding: $e');
          return; // Skip this post if embedding generation fails
        }
      }

      for (var userPost in userPosts.docs) {
        final userPostData = userPost.data();
        var userEmbedding = List<double>.from(userPostData['embedding'] ?? []);

        // UPDATED: Generate embedding if missing for user's post too
        if (userEmbedding.isEmpty) {
          debugPrint(
            ' User post ${userPost.id} missing embedding, generating...',
          );
          try {
            final text =
                '${userPostData['title'] ?? ''} ${userPostData['description'] ?? ''}';
            userEmbedding = await _geminiService.generateEmbedding(text);

            await userPost.reference.update({
              'embedding': userEmbedding,
              'embeddingUpdatedAt': FieldValue.serverTimestamp(),
            });

            debugPrint(' Embedding generated for user post ${userPost.id}');
          } catch (e) {
            debugPrint(' Failed to generate embedding: $e');
            continue; // Skip this comparison
          }
        }

        // Calculate similarity
        final similarity = _geminiService.calculateSimilarity(
          userEmbedding,
          newEmbedding,
        );

        if (similarity > 0.75) {
          // Match found! Send notification
          await _sendMatchNotification(
            currentUserId: currentUserId,
            matchedUserId: newPostData['userId'],
            matchedUserName: await _getUserName(newPostData['userId']),
            matchedIntent:
                newPostData['title'] ?? newPostData['description'] ?? '',
            similarity: similarity,
          );
        }
      }
    } catch (e) {
      debugPrint(' Error checking post match: $e');
    }
  }

  Future<void> _sendMatchNotification({
    required String currentUserId,
    required String matchedUserId,
    required String matchedUserName,
    required String matchedIntent,
    required double similarity,
  }) async {
    // Debounce notifications to prevent spam
    final notificationKey = '$currentUserId-$matchedUserId';
    if (_notificationTimers.containsKey(notificationKey)) {
      return; // Already sent recently
    }

    // Set timer to prevent duplicate notifications
    _notificationTimers[notificationKey] = Timer(
      const Duration(minutes: 5),
      () {
        _notificationTimers.remove(notificationKey);
      },
    );

    // Store the match in database
    await _firestore.collection('matches').add({
      'userId': currentUserId,
      'matchedUserId': matchedUserId,
      'matchedUserName': matchedUserName,
      'matchedIntent': matchedIntent,
      'similarity': similarity,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Send local notification
    await _notificationService.showNotification(
      title: ' New Match Found!',
      body: '$matchedUserName: "$matchedIntent"',
      payload: 'match:$matchedUserId',
    );
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['name'] ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  // Get unread matches for current user
  Stream<List<Map<String, dynamic>>> getUnreadMatches() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('matches')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Mark match as read
  Future<void> markMatchAsRead(String matchId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  // Clean up listeners
  void dispose() {
    _intentListener?.cancel();
    _postListener?.cancel();
    for (var timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();
    _isInitialized = false;
  }
}

// Background matching worker for handling large-scale matching
class BackgroundMatcher {
  static Future<void> runMatching() async {
    // This would be called periodically or triggered by Cloud Functions
    final firestore = FirebaseFirestore.instance;

    // Get all active intents
    final intents = await firestore
        .collection('intents')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .get();

    // Process in batches to avoid memory issues
    const batchSize = 100;
    for (int i = 0; i < intents.docs.length; i += batchSize) {
      final batch = intents.docs.skip(i).take(batchSize).toList();
      await _processBatch(batch);
    }
  }

  static Future<void> _processBatch(List<QueryDocumentSnapshot> batch) async {
    // Process matching logic for batch
    // This would be more efficient with a backend service
    for (var doc1 in batch) {
      for (var doc2 in batch) {
        if (doc1.id != doc2.id) {
          // Compare and store matches
          await _compareAndStoreMatch(doc1, doc2);
        }
      }
    }
  }

  static Future<void> _compareAndStoreMatch(
    QueryDocumentSnapshot doc1,
    QueryDocumentSnapshot doc2,
  ) async {
    // Implementation for comparing and storing matches
    // This would include similarity calculation and complementary matching
  }
}
