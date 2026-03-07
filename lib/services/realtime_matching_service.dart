import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'ai_services/gemini_service.dart';
import 'unified_post_service.dart';
import '../models/post_model.dart';
import '../res/config/api_config.dart';

class RealtimeMatchingService {
  static final RealtimeMatchingService _instance =
      RealtimeMatchingService._internal();
  factory RealtimeMatchingService() => _instance;
  RealtimeMatchingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final GeminiService _geminiService = GeminiService();
  final UnifiedPostService _postService = UnifiedPostService();

  StreamSubscription? _postListener;
  final Map<String, Timer> _notificationTimers = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isInitialized = true;
    _listenForNewPosts(userId);
    debugPrint('RealtimeMatchingService initialized');
  }

  void _listenForNewPosts(String currentUserId) {
    _postListener = _firestore
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.now())
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null || data['userId'] == currentUserId) continue;
              await _checkPostMatch(change.doc, currentUserId);
            }
          }
        });

    debugPrint(' Listening for new posts in real-time');
  }

  /// Check if new post matches any of user's active posts.
  /// Delegates scoring to UnifiedPostService.scoreCandidate for consistency.
  Future<void> _checkPostMatch(
    DocumentSnapshot newPost,
    String currentUserId,
  ) async {
    try {
      final userPosts = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(50)
          .get();

      if (userPosts.docs.isEmpty) return;

      final newPostData = newPost.data() as Map<String, dynamic>;
      var newEmbedding = List<double>.from(newPostData['embedding'] ?? []);

      // Generate embedding if missing
      if (newEmbedding.isEmpty) {
        try {
          final text =
              '${newPostData['title'] ?? ''} ${newPostData['description'] ?? ''}';
          newEmbedding = await _geminiService.generateEmbedding(text);
          await newPost.reference.update({
            'embedding': newEmbedding,
            'embeddingUpdatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to generate embedding: $e');
          return;
        }
      }

      final newPostModel = PostModel.fromFirestore(newPost);

      for (var userPost in userPosts.docs) {
        final userPostData = userPost.data();
        var userEmbedding =
            List<double>.from(userPostData['embedding'] ?? []);

        // Generate embedding if missing for user's post
        if (userEmbedding.isEmpty) {
          try {
            final text =
                '${userPostData['title'] ?? ''} ${userPostData['description'] ?? ''}';
            userEmbedding = await _geminiService.generateEmbedding(text);
            await userPost.reference.update({
              'embedding': userEmbedding,
              'embeddingUpdatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            continue;
          }
        }

        final userPostModel = PostModel.fromFirestore(userPost);

        // Build search embedding the same way UnifiedPostService does
        final complementaryIntents = List<String>.from(
          userPostModel.intentAnalysis['complementary_intents'] ?? [],
        );
        List<double> searchEmbedding;
        if (complementaryIntents.isNotEmpty) {
          final searchText =
              '${complementaryIntents.join('. ')} ${userPostModel.searchKeywords.join(' ')}';
          searchEmbedding =
              await _geminiService.generateEmbedding(searchText);
        } else {
          searchEmbedding = userEmbedding;
        }

        // Use the EXACT same scoring as UnifiedPostService
        final score = _postService.scoreCandidate(
          sourcePost: userPostModel,
          candidate: newPostModel,
          searchEmbedding: searchEmbedding,
          sourceSide: _postService.inferSide(userPostModel),
          sourceSymmetric:
              userPostModel.intentAnalysis['is_symmetric'] == true,
          sourceKw: Set<String>.from(userPostModel.keywords ?? []),
          complementaryIntents: complementaryIntents,
        );

        if (score != null && score >= ApiConfig.matchRealtimeThreshold) {
          await _sendMatchNotification(
            currentUserId: currentUserId,
            matchedUserId: newPostData['userId'],
            matchedUserName: await _getUserName(newPostData['userId']),
            matchedIntent:
                newPostData['title'] ?? newPostData['description'] ?? '',
            similarity: score,
          );
          break; // One notification per new post is enough
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
    final notificationKey = '$currentUserId-$matchedUserId';
    if (_notificationTimers.containsKey(notificationKey)) {
      return;
    }

    _notificationTimers[notificationKey] = Timer(
      const Duration(minutes: 5),
      () {
        _notificationTimers.remove(notificationKey);
      },
    );

    await _firestore.collection('matches').add({
      'userId': currentUserId,
      'matchedUserId': matchedUserId,
      'matchedUserName': matchedUserName,
      'matchedIntent': matchedIntent,
      'similarity': similarity,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await _notificationService.showNotification(
      title: ' New Match Found!',
      body: '$matchedUserName: "$matchedIntent"',
      payload: jsonEncode({
        'type': 'match',
        'matchedUserId': matchedUserId,
        'matchedUserName': matchedUserName,
      }),
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

  Future<void> markMatchAsRead(String matchId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  void dispose() {
    _postListener?.cancel();
    for (final timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();
    _isInitialized = false;
  }
}
