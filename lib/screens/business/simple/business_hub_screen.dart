import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../models/user_profile.dart';
import '../../../models/catalog_item.dart';
import '../../../services/catalog_service.dart';
import '../../../services/account_type_service.dart';
import '../../../services/unified_post_service.dart';
import '../../../services/booking_service.dart';
import '../../../widgets/catalog_card_widget.dart';
import '../../../widgets/business/business_shimmer_widgets.dart';
import '../../../widgets/business/item_options_sheet.dart';
import 'business_info_edit.dart';
import 'catalog_item_form.dart';
import 'catalog_management_screen.dart';
import 'profile_views_screen.dart';
import 'bookings_screen.dart';
import 'reviews_screen.dart';
import 'public_business_profile_screen.dart';

class BusinessHubScreen extends StatefulWidget {
  const BusinessHubScreen({super.key});

  @override
  State<BusinessHubScreen> createState() => _BusinessHubScreenState();
}

class _BusinessHubScreenState extends State<BusinessHubScreen> {
  final _catalogService = CatalogService();
  final _accountService = AccountTypeService();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  Future<int>? _pendingCountFuture;
  Stream<List<CatalogItem>>? _catalogStream;

  @override
  void initState() {
    super.initState();
    final uid = _userId;
    if (uid != null) {
      UnifiedPostService().syncBusinessPost(uid);
      _pendingCountFuture = BookingService().getPendingCount(uid);
      _catalogStream = _catalogService.streamCatalog(uid);
    }
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CatalogItemForm()),
    );
  }

  void _editItem(CatalogItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CatalogItemForm(item: item)),
    );
  }

  void _showItemOptions(CatalogItem item) {
    ItemOptionsSheet.show(
      context,
      item: item,
      onEdit: () => _editItem(item),
      onToggleAvailability: () async {
        await _catalogService.toggleAvailability(item.userId, item.id, !item.isAvailable);
      },
      onDelete: () async {
        if (_userId != null) {
          await _catalogService.deleteItem(_userId!, item.id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(true),
        body: const Center(
          child:
              Text('Please sign in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor(true),
            body: const ShimmerDashboard(isDarkMode: true),
          );
        }

        final userData =
            userSnapshot.data?.data() as Map<String, dynamic>?;
        final isBusiness = userData?['businessProfile'] != null;

        if (!isBusiness) {
          return _buildEnableBusinessView();
        }

        final bp = userData?['businessProfile'] != null
            ? BusinessProfile.fromMap(
                Map<String, dynamic>.from(userData!['businessProfile']))
            : BusinessProfile();

        final location = userData?['location'] as String?;

        return _buildBusinessDashboard(bp, location);
      },
    );
  }

  // ── Non-business users: prompt to enable ──

  Widget _buildEnableBusinessView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Business'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryAction.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.storefront_rounded,
                    size: 40, color: AppTheme.primaryAction),
              ),
              const SizedBox(height: 24),
              Text(
                'Enable Business Mode',
                style: TextStyle(
                  color: AppTheme.textPrimary(isDark),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add products, services, and a catalog to your profile. Customers can browse and enquire directly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryText(isDark),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BusinessInfoEdit()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAction,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Get Started',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Business Dashboard ──

  Widget _buildBusinessDashboard(BusinessProfile bp, String? location) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Collapsing app bar with cover image
              _buildSliverAppBar(bp, location, isDark),

              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions(bp, isDark)),

              // Profile completeness (hidden when 100%)
              SliverToBoxAdapter(
                child: _buildProfileCompleteness(bp, isDark),
              ),

              // Catalog header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'My Catalog',
                        style: TextStyle(
                          color: AppTheme.textPrimary(isDark),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder<List<CatalogItem>>(
                        stream: _catalogStream,
                        builder: (context, snap) {
                          final count = snap.data?.length ?? 0;
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CatalogManagementScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Text(
                                  '$count items',
                                  style: TextStyle(
                                    color: AppTheme.secondaryText(isDark),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: AppTheme.iconMedium,
                                  color: AppTheme.secondaryText(isDark),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Catalog grid
              _buildCatalogGrid(isDark),

              // Bottom padding (nav bar 60 + FAB ~56 + safe area + margin)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + AppTheme.bottomPaddingWithFab,
                ),
              ),
            ],
          ),

          // Add Item button — positioned, no animation
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + AppTheme.bottomPaddingNoFab,
            child: Material(
              color: AppTheme.primaryAction,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              child: InkWell(
                onTap: _addItem,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Add Item',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SliverAppBar with cover image ──

  Widget _buildSliverAppBar(
      BusinessProfile bp, String? location, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.backgroundColor(isDark),
      surfaceTintColor: Colors.transparent,
      title: const Text('My Business',
          style: TextStyle(fontWeight: FontWeight.w600)),
      actions: [
        // Live toggle
        _buildLiveChip(bp),
        const SizedBox(width: 4),
        // Preview as customer
        IconButton(
          icon: const Icon(Icons.remove_red_eye_outlined, size: 22),
          tooltip: 'Preview as customer',
          onPressed: () => _previewProfile(),
        ),
        // Edit button
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 22),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessInfoEdit(businessProfile: bp),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image
            if (bp.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: bp.coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _coverGradient(),
                errorWidget: (_, __, ___) => _coverGradient(),
              )
            else
              _coverGradient(),

            // Dark gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Business info at bottom of header
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bp.businessName ?? 'My Business',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (bp.softLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withValues(alpha: 0.2),
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
                        const SizedBox(width: 8),
                      ],
                      if (bp.address != null || location != null) ...[
                        Icon(Icons.location_on_outlined,
                            size: AppTheme.iconSmall,
                            color:
                                Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            bp.address ?? location ?? '',
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
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

  Widget _buildLiveChip(BusinessProfile bp) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleLive(bp),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bp.isLive
                ? AppTheme.successStatus.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: bp.isLive
                ? Border.all(
                    color: AppTheme.successStatus.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bp.isLive) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.successStatus,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: AppTheme.successStatus,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Icon(Icons.circle_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text(
                  bp.isCurrentlyOpen ? 'Open' : 'Offline',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLive(BusinessProfile bp) async {
    await _accountService.toggleLiveStatus(!bp.isLive);
  }

  Future<void> _previewProfile() async {
    final uid = _userId;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists || !mounted) return;
    final profile = UserProfile.fromFirestore(doc);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicBusinessProfileScreen(userId: profile.uid),
      ),
    );
  }

  // ── Quick Actions ──

  Widget _buildQuickActions(BusinessProfile bp, bool isDark) {
    final cardBg = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _quickAction(
            icon: Icons.storefront_outlined,
            label: 'Catalog',
            color: AppTheme.quickActionCatalog,
            cardBg: cardBg,
            textColor: textColor,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CatalogManagementScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          FutureBuilder<int>(
            future: _pendingCountFuture ?? Future.value(0),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return _quickAction(
                icon: Icons.calendar_month_outlined,
                label: 'Bookings',
                color: AppTheme.quickActionBookings,
                cardBg: cardBg,
                textColor: textColor,
                isDark: isDark,
                badge: count > 0 ? count.toString() : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BookingsScreen()),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 10),
          _quickAction(
            icon: Icons.star_outline_rounded,
            label: 'Reviews',
            color: AppTheme.quickActionReviews,
            cardBg: cardBg,
            textColor: textColor,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReviewsScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          _quickAction(
            icon: Icons.visibility_outlined,
            label: 'Views',
            color: AppTheme.quickActionViews,
            cardBg: cardBg,
            textColor: textColor,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileViewsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardBg,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow(isDark),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Completeness ──

  Widget _buildProfileCompleteness(BusinessProfile bp, bool isDark) {
    final checks = [
      (bp.businessName != null && bp.businessName!.isNotEmpty, 'Business Name', 20),
      (bp.description != null && bp.description!.isNotEmpty, 'Description', 15),
      (bp.softLabel != null && bp.softLabel!.isNotEmpty, 'Category Label', 10),
      (bp.coverImageUrl != null, 'Cover Image', 10),
      (bp.contactPhone != null || bp.contactEmail != null, 'Contact Info', 15),
      (bp.address != null && bp.address!.isNotEmpty, 'Address', 10),
      (bp.hours != null, 'Business Hours', 10),
      (bp.socialLinks != null && bp.socialLinks!.isNotEmpty, 'Social Links', 10),
    ];

    final score = checks.fold<int>(0, (acc, c) => c.$1 ? acc + c.$3 : acc);
    if (score >= 100) return const SizedBox.shrink();

    final missing = checks.where((c) => !c.$1).map((c) => c.$2).toList();
    final cardBg = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryAction.withValues(alpha: 0.35),
        ),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_outlined,
                  size: 15, color: AppTheme.primaryAction),
              const SizedBox(width: 6),
              Text(
                'Profile $score% complete',
                style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BusinessInfoEdit(businessProfile: bp),
                  ),
                ),
                child: const Text(
                  'Complete profile \u2192',
                  style: TextStyle(
                    color: AppTheme.primaryAction,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.primaryAction),
              minHeight: 6,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Missing: ${missing.take(3).join(', ')}${missing.length > 3 ? '\u2026' : ''}',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Catalog Grid ──

  Widget _buildCatalogGrid(bool isDark) {
    if (_userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final textColor = AppTheme.textPrimary(isDark);

    return StreamBuilder<List<CatalogItem>>(
      stream: _catalogStream,
      builder: (context, snapshot) {
        // Still waiting for first data — show nothing to avoid layout jump
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final items = snapshot.data!;

        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        size: 32,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items yet',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first product or service\nto start your catalog',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + Add Item to get started',
                    style: TextStyle(
                      color: AppTheme.primaryAction.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return CatalogCardWidget(
                  item: item,
                  onTap: () => _editItem(item),
                  onLongPress: () => _showItemOptions(item),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}
