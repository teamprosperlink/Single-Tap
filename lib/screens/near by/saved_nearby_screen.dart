import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'near_by_post_detail_screen.dart';

// Floating card animation — same as networking screen
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

class SavedNearbyScreen extends StatefulWidget {
  const SavedNearbyScreen({super.key});

  @override
  State<SavedNearbyScreen> createState() => _SavedNearbyScreenState();
}

class _SavedNearbyScreenState extends State<SavedNearbyScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _unsavePost(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(postId)
          .delete();
    } catch (e) {
      debugPrint('Error unsaving post: $e');
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nearby Saved Posts',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
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
        child: uid == null
            ? _buildEmptyState('Please sign in to view saved posts')
            : StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(uid)
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

                  // Filter to only nearby-sourced saves that have postData,
                  // and exclude current user's own posts
                  final savedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (!data.containsKey('postData') || data['postData'] == null) return false;
                    final postData = data['postData'] as Map;
                    final postUserId = (postData['user_id'] ?? postData['userId'] ?? '').toString();
                    if (postUserId.isNotEmpty && postUserId == uid) return false;
                    return true;
                  }).toList();

                  if (savedDocs.isEmpty) {
                    return _buildEmptyState('No saved nearby posts yet');
                  }

                  return MasonryGridView.builder(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: 24,
                    ),
                    gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    itemCount: savedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = savedDocs[index];
                      final postId = doc.id;
                      final data = doc.data() as Map<String, dynamic>;
                      final post = Map<String, dynamic>.from(data['postData'] as Map);
                      return _FloatingCard(
                        animationIndex: index,
                        child: _buildSavedCard(postId: postId, post: post),
                      );
                    },
                  );
                },
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
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark icon on any nearby post to save it here',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard({
    required String postId,
    required Map<String, dynamic> post,
  }) {
    final rawModel = (post['model'] ?? '').toString();
    final rawBrand = (post['brand'] ?? '').toString();
    final rawTitle = (post['title'] ?? post['originalPrompt'] ?? 'No Title').toString();
    final title = _toTitleCase(rawModel.isNotEmpty ? rawModel : rawTitle);
    final brand = rawBrand.isNotEmpty ? _toTitleCase(rawBrand) : '';
    final feedCategory = (post['feedCategory'] ?? '').toString();

    final rawImgs = post['images'];
    final images = (rawImgs is List) ? rawImgs : <dynamic>[];
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

    String? priceText;
    for (final key in ['price', 'budget']) {
      final raw = post[key];
      if (raw == null || raw == '') continue;
      final priceNum = (raw is num)
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(RegExp(r'[₹$€£,\s]'), ''));
      if (priceNum != null && priceNum > 0) {
        priceText = priceNum == priceNum.roundToDouble()
            ? '\u20B9${priceNum.toInt()}'
            : '\u20B9${priceNum.toStringAsFixed(2)}';
        break;
      }
    }

    final rawDomain = post['domain'];
    String domainStr = '';
    if (rawDomain is List && rawDomain.isNotEmpty) {
      domainStr = rawDomain.first.toString();
    } else if (rawDomain is String && rawDomain.isNotEmpty) {
      domainStr = rawDomain;
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[900]),
                errorWidget: (_, __, ___) => _buildGradientPlaceholder(domainStr),
              )
            else
              _buildGradientPlaceholder(domainStr),

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

            // Full card tap area
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NearByPostDetailScreen(
                        postId: postId,
                        post: post,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top-left domain badge
            if (domainStr.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      domainStr,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // Top-right unsave button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _unsavePost(postId),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF007AFF),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

            // Bottom info bar
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
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
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (brand.isNotEmpty || feedCategory.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            if (brand.isNotEmpty)
                              Expanded(
                                child: Text(
                                  brand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.grey[400],
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            if (brand.isEmpty) const Spacer(),
                            if (feedCategory.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: feedCategory == 'sell'
                                      ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
                                      : feedCategory == 'buy'
                                          ? const Color(0xFFFF9800).withValues(alpha: 0.85)
                                          : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  feedCategory == 'sell'
                                      ? 'Selling'
                                      : feedCategory == 'buy'
                                          ? 'Buying'
                                          : _toTitleCase(feedCategory),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (priceText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          priceText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.green[400],
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientPlaceholder(String domain) {
    IconData icon;
    List<Color> colors;

    switch (domain.toLowerCase()) {
      case 'technology & electronics':
        icon = Icons.devices_rounded;
        colors = [const Color(0xFF1a237e), const Color(0xFF283593)];
        break;
      case 'fashion & accessories':
        icon = Icons.checkroom_rounded;
        colors = [const Color(0xFF880e4f), const Color(0xFFad1457)];
        break;
      case 'home & living':
        icon = Icons.home_rounded;
        colors = [const Color(0xFF1b5e20), const Color(0xFF2e7d32)];
        break;
      case 'automotive':
        icon = Icons.directions_car_rounded;
        colors = [const Color(0xFFbf360c), const Color(0xFFd84315)];
        break;
      default:
        icon = Icons.shopping_bag_rounded;
        colors = [const Color(0xFF1a1a2e), const Color(0xFF2d2d44)];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 48),
      ),
    );
  }
}
