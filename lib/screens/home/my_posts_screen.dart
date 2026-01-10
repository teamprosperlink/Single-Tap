import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/config/app_assets.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../widgets/other widgets/user_avatar.dart';
import 'edit_post_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user data
  String _currentUserName = '';
  String? _currentUserPhoto;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _currentUserName = data?['name'] ?? data?['displayName'] ?? 'You';
          _currentUserPhoto = data?['photoUrl'] ?? data?['photoURL'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Supper Posts',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Divider line
              Container(
                width: double.infinity,
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundDark(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder(alpha: 0.2)),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.iosBlue.withValues(alpha: 0.6),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.post_add_rounded, size: 18),
                          SizedBox(width: 4),
                          Text('My Posts'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_rounded, size: 18),
                          SizedBox(width: 4),
                          Text('Saved'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18),
                          SizedBox(width: 4),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image (same as feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay for readability
          Positioned.fill(child: Container(color: AppColors.darkOverlay())),

          // Tab content
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreatedPostsTab(),
                _buildSavedPostsTab(),
                _buildDeletePostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Saved Posts Tab
  Widget _buildSavedPostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Not Logged In',
        subtitle: 'Please login to see saved posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading saved posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Saved Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No Saved Posts',
            subtitle: 'Posts you save will appear here',
          );
        }

        final savedPosts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedPosts.length,
          itemBuilder: (context, index) {
            final doc = savedPosts[index];
            final data = doc.data() as Map<String, dynamic>;
            final postData = data['postData'] as Map<String, dynamic>? ?? {};
            return _buildPostCard(
              postId: doc.id,
              post: postData,
              isSaved: true,
              timestamp: data['savedAt'],
            );
          },
        );
      },
    );
  }

  // Created Posts Tab (View Only - no delete button)
  Widget _buildCreatedPostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.post_add_outlined,
        title: 'Not Logged In',
        subtitle: 'Please login to see your posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.post_add_outlined,
            title: 'No Posts Yet',
            subtitle: 'Create your first post to see it here',
          );
        }

        // Filter active posts client-side (isActive == true or isActive field missing)
        final allPosts = snapshot.data!.docs;
        final myPosts = allPosts.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Show posts where isActive is true OR isActive field doesn't exist
          return data['isActive'] == true || !data.containsKey('isActive');
        }).toList();

        if (myPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.post_add_outlined,
            title: 'No Posts Yet',
            subtitle: 'Create your first post to see it here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myPosts.length,
          itemBuilder: (context, index) {
            final doc = myPosts[index];
            final data = doc.data() as Map<String, dynamic>;
            // Add current user data to post for display
            final postWithUserData = Map<String, dynamic>.from(data);
            postWithUserData['userName'] = _currentUserName.isNotEmpty
                ? _currentUserName
                : (data['userName'] ?? 'You');
            postWithUserData['userPhoto'] =
                _currentUserPhoto ?? data['userPhoto'];
            return _buildViewOnlyPostCard(
              postId: doc.id,
              post: postWithUserData,
              timestamp: data['createdAt'],
            );
          },
        );
      },
    );
  }

  // View Only Post Card (for My Posts tab - no action buttons)
  Widget _buildViewOnlyPostCard({
    required String postId,
    required Map<String, dynamic> post,
    dynamic timestamp,
  }) {
    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description =
        (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    final imageUrl = (rawImageUrl != null && rawImageUrl.toString().isNotEmpty)
        ? rawImageUrl.toString()
        : (images.isNotEmpty &&
              images[0] != null &&
              images[0].toString().isNotEmpty)
        ? images[0].toString()
        : null;
    final price = post['price'];
    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];
    final hashtags = (post['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];
    final intentAnalysis = post['intentAnalysis'] as Map<String, dynamic>?;
    final actionType = intentAnalysis?['action_type'] as String?;

    // Get timestamp
    DateTime? time;
    if (timestamp != null && timestamp is Timestamp) {
      time = timestamp.toDate();
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

    // Calculate content level
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(
          color: AppColors.glassBorder(alpha: 0.4),
          width: contentLevel >= 2 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and action badge
            Row(
              children: [
                UserAvatar(
                  profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(userPhoto),
                  radius: contentLevel >= 2 ? 18 : 14,
                  fallbackText: userName,
                ),
                SizedBox(width: contentLevel >= 2 ? 10 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: contentLevel >= 2 ? 13 : 12,
                          color: Colors.white,
                        ),
                      ),
                      if (time != null)
                        Text(
                          timeago.format(time),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action type badge
                if (actionType != null && actionType != 'neutral') ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: contentLevel >= 2 ? 8 : 6,
                      vertical: contentLevel >= 2 ? 4 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getActionColor(actionType).withValues(alpha: 0.2),
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
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _getActionColor(actionType),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Edit and Delete buttons in header row (like feed_screen)
                _buildIconOnlyButton(
                  icon: Icons.edit_outlined,
                  color: Colors.white,
                  onTap: () => _editPost(postId, post),
                ),
                const SizedBox(width: 10),
                _buildIconOnlyButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.white,
                  onTap: () => _showSoftDeleteConfirmation(postId),
                ),
              ],
            ),

            SizedBox(height: contentLevel >= 2 ? 12 : 8),

            // Title
            Text(
              title,
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
                description,
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
                '₹${price.toString()}',
                style: TextStyle(
                  fontSize: contentLevel >= 2 ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.vibrantGreen,
                ),
              ),
            ],

            // Hashtags
            if (hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Post Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
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
            ],
          ],
        ),
      ),
    );
  }

  // Edit post navigation
  void _editPost(String postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(postId: postId, postData: post),
      ),
    );
  }

  // Delete Posts Tab (with delete button)
  Widget _buildDeletePostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'Not Logged In',
        subtitle: 'Please login to see your posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading deleted posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'No Deleted Posts',
            subtitle: 'Posts you delete will appear here',
          );
        }

        // Filter deleted posts client-side (isActive == false)
        final allPosts = snapshot.data!.docs;
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        final deletedPosts = <QueryDocumentSnapshot>[];
        final postsToAutoDelete = <String>[];

        for (final doc in allPosts) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isActive'] != false) continue;

          // Check if post is older than 30 days
          final deletedAt = data['deletedAt'];
          if (deletedAt != null && deletedAt is Timestamp) {
            final deletedDate = deletedAt.toDate();
            if (deletedDate.isBefore(thirtyDaysAgo)) {
              // Mark for auto-deletion
              postsToAutoDelete.add(doc.id);
              continue;
            }
          }
          deletedPosts.add(doc);
        }

        // Auto-delete posts older than 30 days
        if (postsToAutoDelete.isNotEmpty) {
          _autoDeleteOldPosts(postsToAutoDelete);
        }

        if (deletedPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'No Deleted Posts',
            subtitle: 'Posts you delete will appear here for 30 days',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deletedPosts.length,
          itemBuilder: (context, index) {
            final doc = deletedPosts[index];
            final data = doc.data() as Map<String, dynamic>;
            // Add current user data to post for display
            final postWithUserData = Map<String, dynamic>.from(data);
            postWithUserData['userName'] = _currentUserName.isNotEmpty
                ? _currentUserName
                : (data['userName'] ?? 'You');
            postWithUserData['userPhoto'] =
                _currentUserPhoto ?? data['userPhoto'];
            return _buildDeletedPostCard(
              postId: doc.id,
              post: postWithUserData,
              timestamp: data['createdAt'],
              deletedAt: data['deletedAt'],
            );
          },
        );
      },
    );
  }

  // Auto-delete posts older than 30 days
  Future<void> _autoDeleteOldPosts(List<String> postIds) async {
    for (final postId in postIds) {
      try {
        await _firestore.collection('posts').doc(postId).delete();
        debugPrint('Auto-deleted old post: $postId');
      } catch (e) {
        debugPrint('Error auto-deleting post $postId: $e');
      }
    }
  }

  // Deleted post card with remaining days info
  Widget _buildDeletedPostCard({
    required String postId,
    required Map<String, dynamic> post,
    dynamic timestamp,
    dynamic deletedAt,
  }) {
    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description =
        (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    final imageUrl = (rawImageUrl != null && rawImageUrl.toString().isNotEmpty)
        ? rawImageUrl.toString()
        : (images.isNotEmpty &&
              images[0] != null &&
              images[0].toString().isNotEmpty)
        ? images[0].toString()
        : null;
    final price = post['price'];
    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];
    final hashtags = (post['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];

    // Calculate remaining days
    int remainingDays = 30;
    if (deletedAt != null && deletedAt is Timestamp) {
      final deletedDate = deletedAt.toDate();
      final expiryDate = deletedDate.add(const Duration(days: 30));
      remainingDays = expiryDate.difference(DateTime.now()).inDays;
      if (remainingDays < 0) remainingDays = 0;
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(
          color: AppColors.glassBorder(alpha: 0.4),
          width: contentLevel >= 2 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and remaining days badge
            Row(
              children: [
                UserAvatar(
                  profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(userPhoto),
                  radius: contentLevel >= 2 ? 18 : 14,
                  fallbackText: userName,
                ),
                SizedBox(width: contentLevel >= 2 ? 10 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: contentLevel >= 2 ? 13 : 12,
                          color: Colors.white,
                        ),
                      ),
                      // Remaining days warning
                      Text(
                        remainingDays <= 7
                            ? '   $remainingDays days left'
                            : '$remainingDays days left',
                        style: AppTextStyles.caption.copyWith(
                          color: remainingDays <= 7
                              ? AppColors.error
                              : Colors.white70,
                          fontSize: 10,
                          fontWeight: remainingDays <= 7
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Restore and Delete buttons
                _buildIconOnlyButton(
                  icon: Icons.restore_rounded,
                  color: Colors.white,
                  onTap: () => _showRestoreConfirmation(postId),
                ),
                const SizedBox(width: 10),
                _buildIconOnlyButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.white,
                  onTap: () => _showDeleteConfirmation(postId),
                ),
              ],
            ),

            SizedBox(height: contentLevel >= 2 ? 12 : 8),

            // Title
            Text(
              title,
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
                description,
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
                '₹${price.toString()}',
                style: TextStyle(
                  fontSize: contentLevel >= 2 ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.vibrantGreen,
                ),
              ),
            ],

            // Hashtags
            if (hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Post Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
    required bool isSaved,
    dynamic timestamp,
  }) {
    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description =
        (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    final imageUrl = (rawImageUrl != null && rawImageUrl.toString().isNotEmpty)
        ? rawImageUrl.toString()
        : (images.isNotEmpty &&
              images[0] != null &&
              images[0].toString().isNotEmpty)
        ? images[0].toString()
        : null;
    final price = post['price'];
    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];
    final hashtags = (post['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];
    final intentAnalysis = post['intentAnalysis'] as Map<String, dynamic>?;
    final actionType = intentAnalysis?['action_type'] as String?;

    // Get timestamp
    DateTime? time;
    if (timestamp != null && timestamp is Timestamp) {
      time = timestamp.toDate();
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

    // Calculate content level
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(
          color: AppColors.glassBorder(alpha: 0.4),
          width: contentLevel >= 2 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and action badge
            Row(
              children: [
                UserAvatar(
                  profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(userPhoto),
                  radius: contentLevel >= 2 ? 18 : 14,
                  fallbackText: userName,
                ),
                SizedBox(width: contentLevel >= 2 ? 10 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: contentLevel >= 2 ? 13 : 12,
                          color: Colors.white,
                        ),
                      ),
                      if (time != null)
                        Text(
                          timeago.format(time),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action type badge
                if (actionType != null && actionType != 'neutral') ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: contentLevel >= 2 ? 8 : 6,
                      vertical: contentLevel >= 2 ? 4 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getActionColor(actionType).withValues(alpha: 0.2),
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
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _getActionColor(actionType),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Action buttons in header row (like feed_screen)
                if (isSaved) ...[
                  // Saved tab: Remove from saved button
                  _buildIconOnlyButton(
                    icon: Icons.bookmark_remove_rounded,
                    color: Colors.white,
                    onTap: () => _removeSavedPost(postId),
                  ),
                ] else ...[
                  // Delete tab: Restore and Delete buttons
                  _buildIconOnlyButton(
                    icon: Icons.restore_rounded,
                    color: Colors.white,
                    onTap: () => _showRestoreConfirmation(postId),
                  ),
                  const SizedBox(width: 10),
                  _buildIconOnlyButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.white,
                    onTap: () => _showDeleteConfirmation(postId),
                  ),
                ],
              ],
            ),

            SizedBox(height: contentLevel >= 2 ? 12 : 8),

            // Title
            Text(
              title,
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
                description,
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
                '₹${price.toString()}',
                style: TextStyle(
                  fontSize: contentLevel >= 2 ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.vibrantGreen,
                ),
              ),
            ],

            // Hashtags
            if (hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hashtags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Post Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
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
            ],
          ],
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

  // Icon-only button style (matching feed_screen)
  Widget _buildIconOnlyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Fixed size matching feed_screen for consistent look
    const double buttonSize = 32.0;
    const double iconSize = 16.0;
    const double borderRadius = 8.0;

    // Wrap in Material to absorb InkWell splash from parent
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: Icon(icon, size: 64, color: Colors.white38),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSavedPost(String postId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(postId)
          .delete();
    } catch (e) {
      debugPrint('Error removing saved post: $e');
    }
  }

  // Soft delete confirmation (for My Posts tab - moves to Delete tab)
  void _showSoftDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Post?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This post will be moved to Delete tab. You can restore it later.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _softDeletePost(postId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Soft delete - sets isActive to false (can be restored within 30 days)
  Future<void> _softDeletePost(String postId) async {
    try {
      debugPrint('Soft deleting post: $postId');

      // First check if document exists
      final docRef = _firestore.collection('posts').doc(postId);
      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint('Post does not exist: $postId');
        if (mounted) {
          SnackBarHelper.showError(context, 'Post not found');
        }
        return;
      }

      // Update isActive to false and set deletedAt timestamp
      await docRef.update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Post soft deleted successfully: $postId');

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post moved to Delete tab');
      }
    } catch (e) {
      debugPrint('Error soft deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to delete post: ${e.toString()}',
        );
      }
    }
  }

  // Permanent delete confirmation (for Delete tab - permanently removes)
  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Permanently?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. The post will be permanently deleted.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _permanentDeletePost(postId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete Forever',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Permanent delete - removes from Firestore completely
  Future<void> _permanentDeletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post deleted permanently');
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete post');
      }
    }
  }

  void _showRestoreConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restore_rounded,
                  color: Colors.blue.withValues(alpha: 0.8),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Restore Post?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This post will be restored and visible again in My Posts.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _restorePost(postId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Restore',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restorePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': true,
        'deletedAt': FieldValue.delete(), // Remove deletedAt field
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post restored successfully');
      }
    } catch (e) {
      debugPrint('Error restoring post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to restore post');
      }
    }
  }
}
