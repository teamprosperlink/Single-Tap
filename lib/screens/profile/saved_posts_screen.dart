import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/post_model.dart';
import '../product/product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(64, 64, 64, 1),
            border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            title: Text(
              'Saved Posts',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
            Expanded(
              child: userId == null
                  ? _buildEmptyState('Please sign in to view saved posts')
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(userId)
                          .collection('saved_posts')
                          .orderBy('savedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                            final savedAt =
                                (savedPost.data()
                                        as Map<String, dynamic>)['savedAt']
                                    as Timestamp?;

                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore
                                  .collection('posts')
                                  .doc(postId)
                                  .get(),
                              builder: (context, postSnapshot) {
                                if (!postSnapshot.hasData) {
                                  return _buildLoadingCard();
                                }

                                if (!postSnapshot.data!.exists) {
                                  _removeSavedPost(postId);
                                  return const SizedBox.shrink();
                                }

                                final post = PostModel.fromFirestore(
                                  postSnapshot.data!,
                                );

                                return _buildSavedPostCard(post, savedAt);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.bookmark_outline,
                size: 64,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any post to save it here',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }

  Widget _buildSavedPostCard(PostModel post, Timestamp? savedAt) {
    final allImageUrls = <String>[];
    if (post.images != null) {
      for (final url in post.images!) {
        if (url.isNotEmpty && !allImageUrls.contains(url)) {
          allImageUrls.add(url);
        }
      }
    }
    // Limit to max 10 images
    if (allImageUrls.length > 10)
      allImageUrls.removeRange(10, allImageUrls.length);

    final bool hasImage = allImageUrls.isNotEmpty;
    final bool hasDescription =
        post.description.isNotEmpty &&
        post.description != post.title &&
        post.description != post.originalPrompt;
    final bool hasPrice = post.price != null && post.price! > 0;

    int contentLevel = 0;
    if (hasImage) {
      contentLevel = 3;
    } else if (hasPrice && hasDescription) {
      contentLevel = 2;
    } else if (hasPrice || hasDescription) {
      contentLevel = 1;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = contentLevel == 3 ? screenHeight * 0.16 : 0.0;
    final cardPadding = contentLevel >= 2 ? 14.0 : 12.0;
    final actionType = post.actionType;

    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (savedAt != null)
                          Text(
                            'Saved ${timeago.format(savedAt.toDate())}',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Action type badge
                  if (actionType != 'neutral') ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: contentLevel >= 2 ? 8 : 6,
                        vertical: contentLevel >= 2 ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getActionColor(
                          actionType,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getActionColor(
                            actionType,
                          ).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        actionType == 'seeking'
                            ? 'Looking'
                            : actionType == 'offering'
                            ? 'Offering'
                            : actionType,
                        style: TextStyle(
                          color: _getActionColor(actionType),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Remove from saved button
                  _buildIconOnlyButton(
                    icon: Icons.bookmark_remove_rounded,
                    color: Colors.white,
                    onTap: () => _removeSavedPost(post.id),
                  ),
                ],
              ),

              SizedBox(height: contentLevel >= 2 ? 12 : 8),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Description
              if (hasDescription) ...[
                const SizedBox(height: 6),
                Text(
                  post.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Price
              if (hasPrice) ...[
                SizedBox(height: contentLevel >= 2 ? 8 : 6),
                Text(
                  '₹${post.price!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: contentLevel >= 2 ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.vibrantGreen,
                  ),
                ),
              ],

              // Post Images
              if (allImageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Main image
                GestureDetector(
                  onTap: () => _openImageViewer(allImageUrls, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: allImageUrls[0],
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiaryDark,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                // Additional images in grid
                if (allImageUrls.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 2nd image
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openImageViewer(allImageUrls, 1),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: allImageUrls[1],
                              height: screenHeight * 0.12,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: screenHeight * 0.12,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBackgroundDark(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: screenHeight * 0.12,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBackgroundDark(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textTertiaryDark,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 3rd image with overlay
                      if (allImageUrls.length > 2) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openImageViewer(allImageUrls, 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: screenHeight * 0.12,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: allImageUrls[2],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.glassBackgroundDark(
                                          alpha: 0.1,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color:
                                                AppColors.glassBackgroundDark(
                                                  alpha: 0.1,
                                                ),
                                            child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: AppColors.textTertiaryDark,
                                              size: 24,
                                            ),
                                          ),
                                    ),
                                    if (allImageUrls.length > 3)
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+${allImageUrls.length - 3}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'seeking':
        return AppColors.iosBlue;
      case 'offering':
        return AppColors.vibrantGreen;
      default:
        return Colors.grey;
    }
  }

  Widget _buildIconOnlyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    const double buttonSize = 32.0;
    const double iconSize = 16.0;
    const double borderRadius = 8.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  // Fullscreen image viewer with swipe and zoom
  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);
    int currentPage = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            title: Text(
              '${currentPage + 1} / ${imageUrls.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            centerTitle: true,
          ),
          body: PageView.builder(
            controller: pageController,
            itemCount: imageUrls.length,
            onPageChanged: (index) {
              setDialogState(() => currentPage = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPost(PostModel post) async {
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
        .set({'savedAt': FieldValue.serverTimestamp()});
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
