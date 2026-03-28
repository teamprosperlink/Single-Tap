import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/business/business_shimmer_widgets.dart';
import '../../../models/user_profile.dart';
import '../../../models/catalog_item.dart';
import '../../../models/review_model.dart';
import '../../../services/catalog_service.dart';
import '../../../services/review_service.dart';
import '../../../widgets/catalog_card_widget.dart';
import '../../chat/enhanced_chat_screen.dart';
import 'catalog_item_detail.dart';
import 'reviews_screen.dart';
import 'write_review_screen.dart';
import 'booking_request_screen.dart';

class PublicBusinessProfileScreen extends StatefulWidget {
  final String userId;

  const PublicBusinessProfileScreen({super.key, required this.userId});

  @override
  State<PublicBusinessProfileScreen> createState() =>
      _PublicBusinessProfileScreenState();
}

class _PublicBusinessProfileScreenState
    extends State<PublicBusinessProfileScreen> {
  final _catalogService = CatalogService();
  final _reviewService = ReviewService();

  UserProfile? _profile;
  List<CatalogItem> _catalogItems = [];
  RatingSummary _ratingSummary = RatingSummary.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!doc.exists || !mounted) return;

      final profile = UserProfile.fromFirestore(doc);
      final allItems =
          await _catalogService.getCatalog(widget.userId, limit: 50);
      final items = allItems.where((i) => i.isAvailable).toList();
      final summary = await _reviewService.getRatingSummary(widget.userId);

      // Log profile view (skips self) — fetch viewer's Firestore profile
      // for accurate name/photo instead of Firebase Auth fields
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid != widget.userId) {
        final viewerDoc = await FirebaseFirestore.instance
            .collection('users').doc(currentUser.uid).get();
        final vData = viewerDoc.data();
        _catalogService.logProfileView(
          profileOwnerId: widget.userId,
          viewerId: currentUser.uid,
          viewerName: vData?['name'] as String? ??
              vData?['displayName'] as String? ?? 'User',
          viewerPhotoUrl: vData?['profileImageUrl'] as String? ??
              vData?['photoUrl'] as String?,
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _catalogItems = items;
        _ratingSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.backgroundColor(isDark);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: ShimmerProfileHeader(isDarkMode: isDark),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Business')),
        body: Center(
          child: Text('Business not found',
              style:
                  TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
        ),
      );
    }

    final bp = _profile!.businessProfile ?? BusinessProfile();

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(bp, isDark),
          SliverToBoxAdapter(child: _buildActionRow(bp, isDark)),
          if (bp.description != null && bp.description!.isNotEmpty)
            SliverToBoxAdapter(child: _buildAboutSection(bp, isDark)),
          if (_catalogItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader('Catalog', '${_catalogItems.length} items', isDark)),
            _buildCatalogGrid(isDark),
          ],
          SliverToBoxAdapter(child: _buildBusinessHours(bp, isDark)),
          SliverToBoxAdapter(child: _buildReviewsSection(isDark)),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ),
        ],
      ),
    );
  }

  // ── SliverAppBar with cover image ──

  Widget _buildSliverAppBar(BusinessProfile bp, bool isDark) {
    final isOpen = bp.isCurrentlyOpen;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor(isDark),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (bp.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: bp.coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _coverGradient(),
                errorWidget: (_, __, ___) => _coverGradient(),
              )
            else
              _coverGradient(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),

            // Business info
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bp.businessName ?? 'Business',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppTheme.successStatus.withValues(alpha: 0.9)
                              : Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (bp.softLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bp.softLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (bp.averageRating > 0) ...[
                        const Icon(Icons.star, size: 14, color: AppTheme.warningStatus),
                        const SizedBox(width: 3),
                        Text(
                          bp.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${bp.totalReviews})',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (bp.address != null || _profile?.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: AppTheme.iconSmall,
                            color: Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            bp.address ?? _profile?.location ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.coverGradient,
      ),
    );
  }

  // ── Action Row ──

  Widget _buildActionRow(BusinessProfile bp, bool isDark) {
    final cardBg = AppTheme.cardColor(isDark);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      child: Row(
        children: [
          _actionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Message',
            color: AppTheme.primaryAction,
            isDark: isDark,
            onTap: _openChat,
          ),
          _actionButton(
            icon: Icons.calendar_month_outlined,
            label: 'Book',
            color: AppTheme.successStatus,
            isDark: isDark,
            onTap: _bookService,
          ),
          if (bp.contactPhone != null && bp.contactPhone!.isNotEmpty)
            _actionButton(
              icon: Icons.phone_outlined,
              label: 'Call',
              color: AppTheme.warningStatus,
              isDark: isDark,
              onTap: () => _callBusiness(bp.contactPhone!),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.08),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat({CatalogItem? item}) {
    if (_profile == null) return;
    String? initialMessage;
    if (item != null) {
      initialMessage = "Hi, I'm interested in ${item.name}"
          "${item.price != null ? ' (${item.formattedPrice})' : ''}";
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(
          otherUser: _profile!,
          initialMessage: initialMessage,
          source: item != null ? 'Catalog' : 'Business',
        ),
      ),
    );
  }

  void _bookService() {
    // Find the first available service item, or first product
    final services = _catalogItems
        .where((i) => i.type == CatalogItemType.service && i.isAvailable)
        .toList();
    final target = services.isNotEmpty ? services.first : _catalogItems.firstOrNull;

    if (target == null || _profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookable items available')),
      );
      return;
    }

    if (target.type == CatalogItemType.service) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingRequestScreen(
            item: target,
            businessUser: _profile!,
          ),
        ),
      );
    } else {
      CatalogItemDetail.show(
        context,
        item: target,
        businessUser: _profile!,
        onEnquire: () => _openChat(item: target),
      );
    }
  }

  void _callBusiness(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── About Section ──

  Widget _buildAboutSection(BusinessProfile bp, bool isDark) {
    final cardBg = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bp.description!,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──

  Widget _buildSectionHeader(String title, String? trailing, bool isDark) {
    final textColor = AppTheme.textPrimary(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  // ── Catalog Grid ──

  Widget _buildCatalogGrid(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _catalogItems[index];
            return CatalogCardWidget(
              item: item,
              onTap: () {
                CatalogItemDetail.show(
                  context,
                  item: item,
                  businessUser: _profile!,
                  onEnquire: () => _openChat(item: item),
                );
              },
            );
          },
          childCount: _catalogItems.length,
        ),
      ),
    );
  }

  // ── Business Hours ──

  Widget _buildBusinessHours(BusinessProfile bp, bool isDark) {
    if (bp.hours == null) return const SizedBox.shrink();

    final cardBg = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);

    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // 0=Monday

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Business Hours',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bp.isCurrentlyOpen
                      ? AppTheme.successStatus.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bp.isCurrentlyOpen ? 'Open Now' : 'Closed',
                  style: TextStyle(
                    color: bp.isCurrentlyOpen
                        ? AppTheme.successStatus
                        : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(7, (i) {
            final dayHours = bp.hours!.schedule[days[i]];
            final isToday = i == todayIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      dayLabels[i],
                      style: TextStyle(
                        color: isToday ? AppTheme.primaryAction : subtitleColor,
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    dayHours != null && !dayHours.isClosed
                        ? dayHours.formatted
                        : 'Closed',
                    style: TextStyle(
                      color: dayHours != null && !dayHours.isClosed
                          ? (isToday ? AppTheme.primaryAction : textColor)
                          : subtitleColor,
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (isToday) ...[
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryAction,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Reviews Section ──

  Widget _buildReviewsSection(bool isDark) {
    final cardBg = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reviews',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_ratingSummary.totalReviews > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 14, color: AppTheme.warningStatus),
                const SizedBox(width: 3),
                Text(
                  '${_ratingSummary.averageRating.toStringAsFixed(1)} (${_ratingSummary.totalReviews})',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
              const Spacer(),
              if (_ratingSummary.totalReviews > 0)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReviewsScreen()),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: AppTheme.primaryAction,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ReviewModel>>(
            stream: _reviewService.streamReviews(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return _buildEmptyReviews(isDark);
              }

              // Show top 3 reviews
              final displayReviews = reviews.take(3).toList();

              return Column(
                children: [
                  ...displayReviews.map((r) => _buildReviewCard(r, isDark)),
                  if (reviews.length > 3) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReviewsScreen()),
                      ),
                      child: Text(
                        'View all ${reviews.length} reviews',
                        style: const TextStyle(
                          color: AppTheme.primaryAction,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildWriteReviewButton(isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review, bool isDark) {
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryAction.withValues(alpha: 0.15),
                backgroundImage: review.reviewerPhoto != null
                    ? NetworkImage(review.reviewerPhoto!)
                    : null,
                child: review.reviewerPhoto == null
                    ? Text(
                        review.reviewerName.isNotEmpty
                            ? review.reviewerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryAction,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      review.formattedDate,
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating.round() ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppTheme.warningStatus,
                  ),
                ),
              ),
            ],
          ),
          if (review.reviewText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.reviewText,
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (review.businessResponse != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Response',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.businessResponse!,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReviews(bool isDark) {
    return Column(
      children: [
        Icon(Icons.rate_review_outlined,
            size: 36,
            color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 8),
        Text(
          'No reviews yet',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _buildWriteReviewButton(isDark),
      ],
    );
  }

  Widget _buildWriteReviewButton(bool isDark) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId == widget.userId) {
      return const SizedBox.shrink();
    }

    final bp = _profile?.businessProfile;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final hasReviewed =
              await _reviewService.hasUserReviewed(widget.userId, currentUserId);
          if (!mounted) return;
          if (hasReviewed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have already reviewed this business')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WriteReviewScreen(
                businessUserId: widget.userId,
                businessName: bp?.businessName ?? 'Business',
              ),
            ),
          );
        },
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Write a Review'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warningStatus,
          side: BorderSide(
            color: AppTheme.warningStatus.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
