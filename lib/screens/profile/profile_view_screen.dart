import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';

import '../../widgets/catalog_card_widget.dart';
import '../../models/catalog_item.dart';
import '../../services/catalog_service.dart';
import '../business/simple/catalog_item_detail.dart';
import '../chat/enhanced_chat_screen.dart';
import '../business/simple/write_review_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfileViewScreen extends StatefulWidget {
  final UserProfile userProfile;
  final PostModel? post;

  const ProfileViewScreen({super.key, required this.userProfile, this.post});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  bool get _isOwnProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.userProfile.uid;

  Future<void> _logProfileViewWithFirestoreData(String viewerUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(viewerUid).get();
      final data = doc.data();
      final name = data?['name'] as String? ??
          data?['displayName'] as String? ?? 'Someone';
      final photo = data?['profileImageUrl'] as String? ??
          data?['photoUrl'] as String?;
      CatalogService().logProfileView(
        profileOwnerId: widget.userProfile.uid,
        viewerId: viewerUid,
        viewerName: name,
        viewerPhotoUrl: photo,
      );
    } catch (e) {
      debugPrint('logProfileView failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.userProfile.isBusiness && !_isOwnProfile) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _logProfileViewWithFirestoreData(currentUser.uid);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.userProfile.isBusiness)
                    _buildBusinessCoverSection()
                  else
                    _buildImageSection(),
                  _buildProfileInfo(),
                  if (widget.post != null) _buildPostDetails(),
                  if (widget.userProfile.isBusiness) _buildCatalogSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            _buildTopBar(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Row(
              children: [
                if (widget.userProfile.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Online',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: _showMoreOptions,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCoverSection() {
    final bp = widget.userProfile.businessProfile ?? BusinessProfile();

    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bp.coverImageUrl != null && bp.coverImageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: bp.coverImageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _businessCoverGradient(),
              errorWidget: (_, __, ___) => _businessCoverGradient(),
            )
          else
            _businessCoverGradient(),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          // Business name + info overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bp.businessName ?? widget.userProfile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (bp.hours != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: bp.isCurrentlyOpen
                              ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                              : Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bp.isCurrentlyOpen ? 'Open' : 'Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (bp.softLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const SizedBox(width: 8),
                    ],
                    if (bp.averageRating > 0) ...[
                      const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '${bp.averageRating.toStringAsFixed(1)} (${bp.totalReviews})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.userProfile.location != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          widget.userProfile.location!,
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
    );
  }

  Widget _businessCoverGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final images = widget.post?.images ?? [];
    final profileImage = widget.userProfile.profileImageUrl;

    // Build the default fallback avatar widget
    Widget buildDefaultAvatar() {
      final initial = widget.userProfile.name.isNotEmpty
          ? widget.userProfile.name[0].toUpperCase()
          : '?';
      return Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.3),
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.userProfile.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              if (widget.userProfile.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.userProfile.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    // On Flutter Web, Google profile photos often fail due to CORS/rate limiting
    // Check if all images are Google photos and skip loading if on web
    bool hasNonGoogleImages = false;
    final allImages = <String>[];

    // Check profile image
    if (profileImage != null && profileImage.isNotEmpty) {
      if (!profileImage.contains('googleusercontent.com')) {
        hasNonGoogleImages = true;
      }
      final fixedProfileImage = PhotoUrlHelper.fixGooglePhotoUrl(profileImage);
      if (fixedProfileImage != null && fixedProfileImage.isNotEmpty) {
        allImages.add(fixedProfileImage);
      }
    }

    // Check post images
    for (final img in images) {
      if (!img.contains('googleusercontent.com')) {
        hasNonGoogleImages = true;
      }
      final fixedImg = PhotoUrlHelper.fixGooglePhotoUrl(img);
      if (fixedImg != null && fixedImg.isNotEmpty) {
        allImages.add(fixedImg);
      }
    }

    // On web, if all images are Google photos, just show fallback immediately
    // to avoid CORS errors and rate limiting
    if (kIsWeb && !hasNonGoogleImages) {
      return buildDefaultAvatar();
    }

    if (allImages.isEmpty) {
      return buildDefaultAvatar();
    }

    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemCount: allImages.length,
            itemBuilder: (context, index) {
              final imageUrl = allImages[index];

              // Validate URL before loading
              if (imageUrl.isEmpty) {
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          index == 0 ? 'No Profile Image' : 'No Image',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Build fallback widget showing user initial
              Widget buildFallbackAvatar() {
                final initial = widget.userProfile.name.isNotEmpty
                    ? widget.userProfile.name[0].toUpperCase()
                    : '?';
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.userProfile.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Use Image.network for Flutter Web to handle CORS better
              // CachedNetworkImage uses CanvasKit which has stricter CORS
              if (kIsWeb) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Check for rate limiting (429)
                    if (error.toString().contains('429')) {
                      PhotoUrlHelper.markAsRateLimited(imageUrl);
                    } else {
                      PhotoUrlHelper.markAsFailed(imageUrl);
                    }
                    return buildFallbackAvatar();
                  },
                );
              }

              return CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) {
                  // Check for rate limiting (429)
                  if (error.toString().contains('429')) {
                    PhotoUrlHelper.markAsRateLimited(url);
                  } else {
                    PhotoUrlHelper.markAsFailed(url);
                  }
                  return buildFallbackAvatar();
                },
              );
            },
          ),
          if (allImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  allImages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade700;
    final bp = widget.userProfile.isBusiness
        ? widget.userProfile.businessProfile
        : null;

    return Container(
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Personal info (hidden for business owners) ──
          if (bp == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.userProfile.name,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.userProfile.accountType !=
                      AccountType.personal) ...[
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        widget.userProfile.accountType.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (widget.userProfile.location != null)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 20, color: subtitleColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.userProfile.location!,
                            style:
                                TextStyle(fontSize: 16, color: subtitleColor),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  if (widget.post != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.post!.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── Business info (integrated) ──
          if (bp != null) ...[

            // Cover image
            if (bp.coverImageUrl != null)
              ClipRRect(
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: bp.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1a1a2e), const Color(0xFF0f3460)]
                              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1a1a2e), const Color(0xFF0f3460)]
                              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business name
                  if (bp.businessName != null &&
                      bp.businessName!.isNotEmpty) ...[
                    Text(
                      bp.businessName!,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Open/Closed + Category label pills
                  Row(
                    children: [
                      if (bp.hours != null)
                        _statusPill(bp.isCurrentlyOpen),
                      if (bp.softLabel != null) ...[
                        const SizedBox(width: 8),
                        _labelPill(bp.softLabel!),
                      ],
                    ],
                  ),

                  // Description
                  if (bp.description != null &&
                      bp.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bp.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: subtitleColor,
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Contact action row
                  if (bp.contactPhone != null ||
                      bp.contactEmail != null ||
                      bp.website != null) ...[
                    const SizedBox(height: 16),
                    _buildContactActionRow(bp, isDark),
                  ],

                  // Address
                  if (bp.address != null && bp.address!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _tappableRow(
                      Icons.location_on_outlined,
                      bp.address!,
                      isDark,
                      onTap: () {
                        final encoded = Uri.encodeComponent(bp.address!);
                        launchUrl(
                          Uri.parse(
                              'https://maps.google.com/?q=$encoded'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],

                  // Today's hours
                  if (bp.hours != null) ...[
                    const SizedBox(height: 4),
                    _tappableRow(
                      Icons.access_time,
                      'Today: ${bp.hours!.todayHours}',
                      isDark,
                    ),
                  ],

                  // Social links
                  if (bp.socialLinks != null &&
                      bp.socialLinks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSocialLinksRow(bp.socialLinks!, isDark),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          if (widget.post != null)
            Text(
              widget.post!.description,
              style: TextStyle(
                  fontSize: 16, height: 1.5, color: subtitleColor),
            ),
          if (widget.post?.price != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price',
                      style: TextStyle(fontSize: 16, color: textColor)),
                  Text(
                    '${widget.post!.currency ?? '\$'}${widget.post!.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.post?.metadata != null) ...[
            const SizedBox(height: 20),
            Text(
              'Additional Details',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            ...widget.post!.metadata.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(fontSize: 15, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOpen ? 'Open Now' : 'Closed',
        style: TextStyle(
          color: isOpen ? const Color(0xFF22C55E) : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _labelPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF3B82F6),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildContactActionRow(BusinessProfile bp, bool isDark) {
    Widget actionBtn(
        IconData icon, String label, Color color, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final btns = <Widget>[];
    if (bp.contactPhone != null) {
      btns.add(actionBtn(
        Icons.phone_outlined,
        'Call',
        const Color(0xFF22C55E),
        () => launchUrl(Uri.parse('tel:${bp.contactPhone}')),
      ));
    }
    if (bp.contactEmail != null) {
      btns.add(actionBtn(
        Icons.email_outlined,
        'Email',
        const Color(0xFF3B82F6),
        () => launchUrl(Uri.parse('mailto:${bp.contactEmail}')),
      ));
    }
    if (bp.website != null) {
      final url = bp.website!.startsWith('http')
          ? bp.website!
          : 'https://${bp.website}';
      btns.add(actionBtn(
        Icons.language,
        'Website',
        const Color(0xFF8B5CF6),
        () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
    }
    if (btns.isEmpty) return const SizedBox.shrink();

    // When only 1 button, don't let it stretch full width
    if (btns.length == 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 120, child: btns[0]),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < btns.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: btns[i]),
        ],
      ],
    );
  }

  Widget _tappableRow(IconData icon, String text, bool isDark,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  decoration:
                      onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new,
                size: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  String _buildSocialUrl(String platform, String value) {
    if (value.startsWith('http')) return value;
    // Strip leading @ if present
    final handle = value.startsWith('@') ? value.substring(1) : value;
    switch (platform) {
      case 'instagram':
        return 'https://instagram.com/$handle';
      case 'facebook':
        return 'https://facebook.com/$handle';
      case 'twitter':
        return 'https://x.com/$handle';
      case 'linkedin':
        return 'https://linkedin.com/in/$handle';
      case 'youtube':
        return 'https://youtube.com/@$handle';
      default:
        return 'https://$value';
    }
  }

  Widget _buildSocialLinksRow(Map<String, String> socialLinks, bool isDark) {
    const iconMap = {
      'instagram': FontAwesomeIcons.instagram,
      'facebook': FontAwesomeIcons.facebookF,
      'twitter': FontAwesomeIcons.xTwitter,
      'linkedin': FontAwesomeIcons.linkedinIn,
      'youtube': FontAwesomeIcons.youtube,
    };
    const colorMap = {
      'instagram': Color(0xFFE1306C),
      'facebook': Color(0xFF1877F2),
      'twitter': Color(0xFF1DA1F2),
      'linkedin': Color(0xFF0A66C2),
      'youtube': Color(0xFFFF0000),
    };

    final available =
        socialLinks.entries.where((e) => e.value.isNotEmpty).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Follow',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: available.map((e) {
            final icon = iconMap[e.key] ?? Icons.link;
            final color = colorMap[e.key] ?? Colors.grey;
            final url = _buildSocialUrl(e.key, e.value);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(icon, color: color, size: 20),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCatalogSection() {
    return FutureBuilder<List<CatalogItem>>(
      future: CatalogService().getAvailableItems(widget.userProfile.uid, limit: 6),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: cardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Catalog',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    if (items.length >= 6)
                      TextButton(
                        onPressed: _showAllCatalogItems,
                        child: const Text('See All',
                            style: TextStyle(color: Color(0xFF3B82F6))),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CatalogCardWidget(
                      item: item,
                      compact: true,
                      onTap: () {
                        CatalogItemDetail.show(
                          context,
                          item: item,
                          businessUser: widget.userProfile,
                          onEnquire: () {
                            Navigator.pop(context); // Close bottom sheet
                            _startChatWithEnquiry(item);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startChatWithEnquiry(CatalogItem item) {
    final message = 'Hi! I\'m interested in your ${item.name} (${item.formattedPrice})';
    CatalogService().incrementBusinessStat(widget.userProfile.uid, 'enquiryCount');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(
          otherUser: widget.userProfile,
          initialMessage: message,
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_isOwnProfile) return const SizedBox.shrink();
    final isBusiness = widget.userProfile.isBusiness;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: isBusiness
            ? Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF2C2C2E)
                            : null,
                        foregroundColor: isDark ? Colors.white : null,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final bp = widget.userProfile.businessProfile;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WriteReviewScreen(
                              businessUserId: widget.userProfile.uid,
                              businessName: bp?.businessName ??
                                  widget.userProfile.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _enquire,
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Enquire'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startChat,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('Start Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _startChat() {
    // Create initial message with post context
    String? initialMessage;
    if (widget.post != null) {
      initialMessage =
          'Hi! I\'m interested in your post: "${widget.post!.title}"';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(
          otherUser: widget.userProfile,
          initialMessage: initialMessage,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share, color: Colors.blue),
              ),
              title: const Text(
                'Share Profile',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Share this profile with friends',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.report, color: Colors.orange),
              ),
              title: const Text(
                'Report User',
                style: TextStyle(color: Colors.orange),
              ),
              subtitle: Text(
                'Report inappropriate behavior',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportUser();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.block, color: Colors.red),
              ),
              title: const Text(
                'Block User',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: Text(
                'Stop all communication',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    final name = widget.userProfile.name;
    final bio = widget.userProfile.bio;
    final location = widget.userProfile.location ?? '';

    String shareText = 'Check out $name on Supper!\n';
    if (bio.isNotEmpty) shareText += '\n$bio\n';
    if (location.isNotEmpty) shareText += '\nLocation: $location\n';
    shareText += '\nDownload Supper to connect: https://supper.app';

    Share.share(shareText, subject: 'Check out $name on Supper!');
  }

  void _enquire() {
    final bp = widget.userProfile.businessProfile;
    final name = (bp?.businessName?.isNotEmpty == true)
        ? bp!.businessName!
        : widget.userProfile.name;
    final message = 'Hi! I\'m interested in your services at $name';
    CatalogService()
        .incrementBusinessStat(widget.userProfile.uid, 'enquiryCount');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(
          otherUser: widget.userProfile,
          initialMessage: message,
        ),
      ),
    );
  }

  void _showAllCatalogItems() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllCatalogSheet(
        userId: widget.userProfile.uid,
        businessUser: widget.userProfile,
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you reporting ${widget.userProfile.name}?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            _buildReportOption('Inappropriate content'),
            _buildReportOption('Spam or scam'),
            _buildReportOption('Harassment'),
            _buildReportOption('Fake profile'),
            _buildReportOption('Other'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(
        reason,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
      ),
      dense: true,
      onTap: () async {
        Navigator.pop(context);
        try {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == null) return;

          await FirebaseFirestore.instance.collection('reports').add({
            'reporterId': currentUserId,
            'reportedUserId': widget.userProfile.uid,
            'reportedUserName': widget.userProfile.name,
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Report submitted. Thank you for keeping Supper safe.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit report: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block ${widget.userProfile.name}? They won\'t be able to message you or see your profile.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .collection('blocked')
                    .doc(widget.userProfile.uid)
                    .set({
                      'name': widget.userProfile.name,
                      'blockedAt': FieldValue.serverTimestamp(),
                    });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${widget.userProfile.name} has been blocked.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pop(context); // Go back from profile view
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to block user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AllCatalogSheet extends StatelessWidget {
  final String userId;
  final UserProfile businessUser;

  const _AllCatalogSheet({required this.userId, required this.businessUser});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    businessUser.businessProfile?.businessName ?? 'Catalog',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: isDark ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CatalogItem>>(
                future: CatalogService().getAvailableItems(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No items available',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CatalogCardWidget(
                        item: item,
                        onTap: () {
                          CatalogItemDetail.show(
                            context,
                            item: item,
                            businessUser: businessUser,
                            onEnquire: () {
                              // Capture navigator before pops to avoid stale context
                              final nav = Navigator.of(context);
                              nav.pop(); // close CatalogItemDetail
                              nav.pop(); // close _AllCatalogSheet
                              CatalogService().incrementBusinessStat(
                                  businessUser.uid, 'enquiryCount');
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => EnhancedChatScreen(
                                    otherUser: businessUser,
                                    initialMessage:
                                        'Hi! I\'m interested in your ${item.name} (${item.formattedPrice})',
                                  ),
                                ),
                              );
                            },
                          );
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
}
