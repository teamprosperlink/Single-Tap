import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/utils/snackbar_helper.dart';
import 'edit_post_screen.dart';
import 'near_by_post_detail_screen.dart';

// Floating card animation — same as nearby screen
class _FloatingCard extends StatefulWidget {
  final Widget child;
  final int animationIndex;

  const _FloatingCard({required this.child, this.animationIndex = 0});

  @override
  State<_FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<_FloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    final ms = 1600 + (widget.animationIndex % 6) * 220;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    _controller.value = (widget.animationIndex * 0.17) % 1.0;
    _controller.repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

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
  bool _isAutoDeleting = false;

  // Image is compulsory — posts without images are hidden
  bool _hasImage(Map<String, dynamic> data) {
    final hasImageUrl = (data['imageUrl'] ?? '').toString().trim().isNotEmpty;
    final rawImages = data['images'];
    final hasImages = (rawImages is List)
        ? rawImages.any((img) => img != null && img.toString().trim().isNotEmpty)
        : false;
    return hasImageUrl || hasImages;
  }

  String _getTabCategory(Map<String, dynamic> post) {
    if (post['isDonation'] == true) return 'Donation';
    final cat = (post['category'] ?? post['intentAnalysis']?['domain'] ?? '').toString().toLowerCase();
    final text = '${post['title'] ?? ''} ${post['description'] ?? ''}'.toLowerCase();
    if (cat.contains('job') || cat.contains('work') || text.contains('job') || text.contains('hiring')) return 'Jobs';
    if (cat.contains('service') || text.contains('service') || text.contains('repair') || text.contains('cleaning')) return 'Services';
    return 'Products';
  }

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        title: const Text(
          'Nearby My Posts',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Colors.white,
              indicatorWeight: 1,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              isScrollable: false,
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'My Posts'),
                Tab(text: 'Saved'),
                Tab(text: 'Deleted'),
              ],
            ),
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
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 60,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyPostsTab(),
                  _buildSavedPostsTab(),
                  _buildDeletePostsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── My Posts Tab ──
  Widget _buildMyPostsTab() {
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
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading my posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            title: 'No Posts Yet',
            subtitle: 'Create your first post to see it here',
          );
        }

        final seen = <String>{};
        final myPosts = snapshot.data!.docs.where((d) {
          if (!seen.add(d.id)) return false;
          final data = d.data() as Map<String, dynamic>? ?? {};
          // Only show posts created from Nearby Create Post screen
          if (data['source'] != 'nearby_post') return false;
          if (!_hasImage(data)) return false;
          return true;
        }).toList();

        if (myPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            title: 'No Posts Yet',
            subtitle: 'Create your first post to see it here',
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childCount: myPosts.length,
                itemBuilder: (context, index) {
                  final doc = myPosts[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final postWithUser = Map<String, dynamic>.from(data);
                  postWithUser['userName'] = _currentUserName.isNotEmpty
                      ? _currentUserName
                      : (data['userName'] ?? 'You');
                  postWithUser['userPhoto'] =
                      _currentUserPhoto ?? data['userPhoto'];
                  return _FloatingCard(
                    animationIndex: index,
                    child: _buildPostCard(
                      postId: doc.id,
                      post: postWithUser,
                      cardType: _CardType.myPost,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Saved Posts Tab ──
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
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
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

        final seenSaved = <String>{};
        final savedPosts = snapshot.data!.docs.where((d) {
          if (!seenSaved.add(d.id)) return false;
          final data = d.data() as Map<String, dynamic>? ?? {};
          final postData = data['postData'] as Map<String, dynamic>? ?? {};
          // Only show posts created from Nearby Create Post screen
          if (postData['source'] != 'nearby_post') return false;
          if (!_hasImage(postData)) return false;
          return true;
        }).toList();

        if (savedPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No Saved Posts',
            subtitle: 'Posts you save will appear here',
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childCount: savedPosts.length,
                itemBuilder: (context, index) {
                  final doc = savedPosts[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final postData =
                      data['postData'] as Map<String, dynamic>? ?? {};
                  return _FloatingCard(
                    animationIndex: index,
                    child: _buildPostCard(
                      postId: doc.id,
                      post: postData,
                      cardType: _CardType.saved,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Delete Posts Tab ──
  Widget _buildDeletePostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.delete_outline_rounded,
        title: 'Not Logged In',
        subtitle: 'Please login to see your posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
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

        final allPosts = snapshot.data!.docs;
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        final deletedPosts = <QueryDocumentSnapshot>[];
        final postsToAutoDelete = <String>[];
        final seenDeleted = <String>{};

        for (final doc in allPosts) {
          if (!seenDeleted.add(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>? ?? {};

          // Only show posts created from Nearby Create Post screen
          if (data['source'] != 'nearby_post') continue;

          // Skip posts without images
          if (!_hasImage(data)) continue;

          final deletedAt = data['deletedAt'];
          if (deletedAt != null && deletedAt is Timestamp) {
            final deletedDate = deletedAt.toDate();
            if (deletedDate.isBefore(thirtyDaysAgo)) {
              postsToAutoDelete.add(doc.id);
              continue;
            }
          }

          deletedPosts.add(doc);
        }

        // Auto-delete posts older than 30 days
        if (postsToAutoDelete.isNotEmpty && !_isAutoDeleting) {
          _isAutoDeleting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _autoDeleteOldPosts(postsToAutoDelete).then((_) {
                if (mounted) _isAutoDeleting = false;
              });
            }
          });
        }

        if (deletedPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'No Deleted Posts',
            subtitle: 'Posts you delete will appear here for 30 days',
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childCount: deletedPosts.length,
                itemBuilder: (context, index) {
                  final doc = deletedPosts[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final postWithUser = Map<String, dynamic>.from(data);
                  postWithUser['userName'] = _currentUserName.isNotEmpty
                      ? _currentUserName
                      : (data['userName'] ?? 'You');
                  postWithUser['userPhoto'] =
                      _currentUserPhoto ?? data['userPhoto'];
                  return _FloatingCard(
                    animationIndex: index,
                    child: _buildPostCard(
                      postId: doc.id,
                      post: postWithUser,
                      cardType: _CardType.deleted,
                      deletedAt: data['deletedAt'],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Shared Post Card (masonry grid style — matches NearByScreen) ──
  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
    required _CardType cardType,
    dynamic deletedAt,
  }) {
    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];

    final allImageUrls = <String>[];
    if (rawImageUrl != null && rawImageUrl.toString().isNotEmpty) {
      allImageUrls.add(rawImageUrl.toString());
    }
    for (final img in images) {
      final url = img?.toString() ?? '';
      if (url.isNotEmpty && !allImageUrls.contains(url)) allImageUrls.add(url);
    }
    final imageUrl = allImageUrls.isNotEmpty ? allImageUrls[0] : null;
    final price = post['price'];
    final subCategory = (post['subCategory'] ?? '').toString();

    // Remaining days for deleted posts
    int? remainingDays;
    if (cardType == _CardType.deleted && deletedAt != null && deletedAt is Timestamp) {
      final deletedDate = deletedAt.toDate();
      final expiryDate = deletedDate.add(const Duration(days: 30));
      remainingDays = expiryDate.difference(DateTime.now()).inDays;
      if (remainingDays < 0) remainingDays = 0;
    }

    return Container(
        height: 240,
        margin: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full cover image
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white38,
                      size: 32,
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade800,
                  child: const Icon(
                    Icons.image_outlined,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),

              // Bottom gradient fade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                      stops: const [0.35, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Full card tap for navigation (BEFORE buttons so buttons win)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    Navigator.push(
                      context,
                      _ExpandRoute(
                        builder: (_) => NearByPostDetailScreen(
                          postId: postId,
                          post: post,
                          isDeleted: cardType == _CardType.deleted,
                          tabCategory: _getTabCategory(post),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Top-left badges
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Remaining days badge (deleted tab only)
                      if (cardType == _CardType.deleted && remainingDays != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: remainingDays <= 7
                                    ? AppColors.error.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$remainingDays days left',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Donation badge
                      if (post['isDonation'] == true) ...[
                        if (cardType == _CardType.deleted && remainingDays != null)
                          const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Donation',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom glassmorphism info bar (IgnorePointer — non-interactive)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            // Sub-category
                            if (subCategory.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subCategory,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            // Price
                            if (price != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '₹${_formatPrice(price)}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF00D67D),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top-right action buttons (LAST child = tested FIRST in hit testing)
              Positioned(
                top: 8,
                right: 8,
                child: _buildTopRightButtons(postId, post, cardType),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildTopRightButtons(
    String postId,
    Map<String, dynamic> post,
    _CardType cardType,
  ) {
    switch (cardType) {
      case _CardType.myPost:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _topRightButton(
              icon: Icons.edit_outlined,
              color: Colors.white,
              onTap: () => _editPost(postId, post),
            ),
            const SizedBox(width: 6),
            _topRightButton(
              icon: Icons.delete_outline_rounded,
              color: Colors.white,
              onTap: () => _showSoftDeleteConfirmation(postId),
            ),
          ],
        );
      case _CardType.saved:
        return _topRightButton(
          icon: Icons.bookmark_rounded,
          color: Colors.white,
          onTap: () => _unsavePost(postId),
        );
      case _CardType.deleted:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _topRightButton(
              icon: Icons.restore_rounded,
              color: Colors.white,
              onTap: () => _showRestoreConfirmation(postId),
            ),
            const SizedBox(width: 6),
            _topRightButton(
              icon: Icons.delete_forever_rounded,
              color: Colors.white,
              onTap: () => _showDeleteConfirmation(postId),
            ),
          ],
        );
    }
  }

  Widget _topRightButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF016CFF).withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final parsedPrice = double.tryParse(price.toString()) ?? 0;
    if (parsedPrice == parsedPrice.truncateToDouble()) {
      // Whole number — no decimals, add commas
      return parsedPrice.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return parsedPrice.toStringAsFixed(2);
  }

  // ── Actions ──

  Future<void> _editPost(String postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(postId: postId, postData: post),
      ),
    );
    if (result == true && mounted) {
      SnackBarHelper.showSuccess(context, 'Post updated');
    }
  }

  void _showSoftDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(15, 15, 15, 1)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Delete Post?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This post will be moved to the Delete tab and auto-deleted after 30 days.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _softDeletePost(postId);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.error,
                              ),
                              child: const Center(
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _softDeletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post moved to Delete tab');
      }
    } catch (e) {
      debugPrint('Error soft deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete post');
      }
    }
  }

  Future<void> _unsavePost(String postId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    HapticFeedback.lightImpact();
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(postId)
          .delete();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post unsaved');
      }
    } catch (e) {
      debugPrint('Error unsaving post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to unsave post');
      }
    }
  }

  void _showRestoreConfirmation(String postId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(15, 15, 15, 1)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restore_rounded,
                        color: AppColors.success,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Restore Post?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This post will be restored and visible again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _restorePost(postId);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.success,
                              ),
                              child: const Center(
                                child: Text(
                                  'Restore',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                  ),
                ),
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
        'deletedAt': FieldValue.delete(),
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post restored');
      }
    } catch (e) {
      debugPrint('Error restoring post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to restore post');
      }
    }
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(15, 15, 15, 1)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Delete Permanently?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This action cannot be undone. The post will be permanently deleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _permanentlyDeletePost(postId);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.error,
                              ),
                              child: const Center(
                                child: Text(
                                  'Delete Forever',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _permanentlyDeletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post deleted permanently');
      }
    } catch (e) {
      debugPrint('Error permanently deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete post');
      }
    }
  }

  Future<void> _autoDeleteOldPosts(List<String> postIds) async {
    final batch = _firestore.batch();
    for (final postId in postIds) {
      batch.delete(_firestore.collection('posts').doc(postId));
    }
    try {
      await batch.commit();
      debugPrint('Auto-deleted ${postIds.length} old posts');
    } catch (e) {
      debugPrint('Error auto-deleting posts: $e');
    }
  }

  // ── Empty State ──
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
              child: Icon(icon, size: 64, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardType { myPost, saved, deleted }

/// Slide-up from bottom — like iOS App Store card open.
class _ExpandRoute<T> extends PageRouteBuilder<T> {
  _ExpandRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            );

            // Open: slide in from left, Back: slide out to right
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(slideAnim);

            // Slight fade in at start
            final fadeAnimation = Tween<double>(
              begin: 0.5,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
        );
}
