import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../home/product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Saved Posts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: userId == null
          ? _buildEmptyState('Please sign in to view saved posts')
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('saved_posts')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No saved posts yet');
                }

                final savedPosts = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: savedPosts.length,
                  itemBuilder: (context, index) {
                    final savedPost = savedPosts[index];
                    final postId = savedPost.id;
                    final savedAt = (savedPost.data() as Map<String, dynamic>)['savedAt'] as Timestamp?;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('posts').doc(postId).get(),
                      builder: (context, postSnapshot) {
                        if (!postSnapshot.hasData) {
                          return _buildLoadingCard();
                        }

                        if (!postSnapshot.data!.exists) {
                          // Post was deleted, remove from saved
                          _removeSavedPost(postId);
                          return const SizedBox.shrink();
                        }

                        final post = PostModel.fromFirestore(postSnapshot.data!);

                        return _buildSavedPostCard(post, savedAt);
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon on any post to save it here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }

  Widget _buildSavedPostCard(PostModel post, Timestamp? savedAt) {
    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post image or icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: post.images?.isNotEmpty == true
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: post.images!.first,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.white.withValues(alpha: 0.1),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.image_not_supported,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Icon(
                            _getPostIcon(post),
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 32,
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Post info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title ?? post.originalPrompt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (post.description != null) ...[
                          Text(
                            post.description!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            if (post.price != null && post.price! > 0) ...[
                              Text(
                                '\$${post.price!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (savedAt != null)
                              Text(
                                'Saved ${timeago.format(savedAt.toDate())}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Remove button
                  IconButton(
                    icon: const Icon(Icons.bookmark, color: Colors.blue),
                    onPressed: () => _removeSavedPost(post.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPostIcon(PostModel post) {
    final intent = post.intentAnalysis;
    if (intent == null) return Icons.article_outlined;

    final domain = intent['domain']?.toString().toLowerCase() ?? '';
    if (domain.contains('marketplace') || domain.contains('buy') || domain.contains('sell')) {
      return Icons.shopping_bag_outlined;
    } else if (domain.contains('job') || domain.contains('work')) {
      return Icons.work_outline;
    } else if (domain.contains('dating') || domain.contains('romance')) {
      return Icons.favorite_outline;
    } else if (domain.contains('friend') || domain.contains('social')) {
      return Icons.people_outline;
    } else if (domain.contains('lost') || domain.contains('found')) {
      return Icons.search;
    }
    return Icons.article_outlined;
  }

  void _openPost(PostModel post) async {
    // Convert post to item map for ProductDetailScreen
    final item = {
      'id': post.id,
      'title': post.title,
      'description': post.description,
      'price': post.price ?? 0,
      'images': post.images ?? [],
      'location': post.location ?? '',
      'userId': post.userId,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          item: item,
          category: post.categoryDisplay.toLowerCase(),
        ),
      ),
    );
  }

  Future<void> _removeSavedPost(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .doc(postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post removed from saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Static methods to save/unsave posts from anywhere in the app
class SavedPostsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if a post is saved
  static Future<bool> isPostSaved(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_posts')
        .doc(postId)
        .get();

    return doc.exists;
  }

  /// Save a post
  static Future<void> savePost(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_posts')
        .doc(postId)
        .set({
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unsave a post
  static Future<void> unsavePost(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_posts')
        .doc(postId)
        .delete();
  }

  /// Toggle save status
  static Future<bool> toggleSave(String postId) async {
    final isSaved = await isPostSaved(postId);
    if (isSaved) {
      await unsavePost(postId);
      return false;
    } else {
      await savePost(postId);
      return true;
    }
  }
}
