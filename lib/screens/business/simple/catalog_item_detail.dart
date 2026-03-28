import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../models/catalog_item.dart';
import '../../../models/user_profile.dart';
import '../../../services/catalog_service.dart';
import 'booking_request_screen.dart';

class CatalogItemDetail extends StatelessWidget {
  final CatalogItem item;
  final UserProfile businessUser;
  final VoidCallback? onEnquire;

  const CatalogItemDetail({
    super.key,
    required this.item,
    required this.businessUser,
    this.onEnquire,
  });

  static void show(
    BuildContext context, {
    required CatalogItem item,
    required UserProfile businessUser,
    VoidCallback? onEnquire,
  }) {
    // Increment view count
    CatalogService().incrementItemView(item.userId, item.id);
    CatalogService().incrementBusinessStat(item.userId, 'catalogViews');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => CatalogItemDetail(
          item: item,
          businessUser: businessUser,
          onEnquire: onEnquire,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final images = item.allImages;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image carousel or placeholder
                if (images.isNotEmpty)
                  _ImageCarousel(images: images, isDark: isDark)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _placeholder(isDark),
                    ),
                  ),

                const SizedBox(height: 16),

                // Type chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.type == CatalogItemType.service
                            ? AppTheme.primaryAction.withValues(alpha: 0.15)
                            : AppTheme.secondaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.type == CatalogItemType.service
                            ? 'Service'
                            : 'Product',
                        style: TextStyle(
                          color: item.type == CatalogItemType.service
                              ? AppTheme.primaryAction
                              : AppTheme.secondaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!item.isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorStatus.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Currently Unavailable',
                          style: TextStyle(
                            color: AppTheme.errorStatus,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Name
                Text(
                  item.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                // Price
                Text(
                  item.formattedPrice,
                  style: TextStyle(
                    color: item.price != null
                        ? AppTheme.primaryAction
                        : subtitleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // Duration for services
                if (item.type == CatalogItemType.service &&
                    item.formattedDuration != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        item.formattedDuration!,
                        style: TextStyle(color: subtitleColor, fontSize: 14),
                      ),
                    ],
                  ),
                ],

                // Description
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Business info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : AppTheme.backgroundColor(false),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: businessUser.profileImageUrl != null
                            ? NetworkImage(businessUser.profileImageUrl!)
                            : null,
                        child: businessUser.profileImageUrl == null
                            ? Text(
                                businessUser.name.isNotEmpty
                                    ? businessUser.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessUser.businessProfile?.businessName ??
                                  businessUser.name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (businessUser.businessProfile?.softLabel != null)
                              Text(
                                businessUser.businessProfile!.softLabel!,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Book Now (services) or Enquire (products)
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: item.isAvailable
                              ? () {
                                  if (item.type == CatalogItemType.service) {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingRequestScreen(
                                          item: item,
                                          businessUser: businessUser,
                                        ),
                                      ),
                                    );
                                  } else {
                                    onEnquire?.call();
                                  }
                                }
                              : null,
                          icon: Icon(
                            item.type == CatalogItemType.service
                                ? Icons.calendar_month_outlined
                                : Icons.chat_outlined,
                            size: 20,
                          ),
                          label: Text(
                            item.type == CatalogItemType.service
                                ? 'Book Now'
                                : 'Enquire',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                item.type == CatalogItemType.service
                                ? AppTheme.primaryAction
                                : AppTheme.secondaryAccent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE0E0E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    // Call button
                    if (businessUser.businessProfile?.contactPhone != null) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            final phone =
                                businessUser.businessProfile!.contactPhone!;
                            launchUrl(Uri.parse('tel:$phone'));
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          child: Icon(
                            Icons.phone_outlined,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          item.type == CatalogItemType.service
              ? Icons.home_repair_service_outlined
              : Icons.shopping_bag_outlined,
          size: 48,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

/// Swipeable image carousel with dot indicators.
class _ImageCarousel extends StatefulWidget {
  final List<String> images;
  final bool isDark;

  const _ImageCarousel({required this.images, required this.isDark});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showFullScreen(context, index),
                    splashColor: Colors.white.withValues(alpha: 0.08),
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: widget.isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF0F0F0),
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Dot indicators
            if (widget.images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (i) => Container(
                      width: i == _current ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            // Image counter
            if (widget.images.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_current + 1}/${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Full-screen zoomable image gallery.
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(true),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.images.length > 1
            ? Text(
                '${_current + 1} of ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white38,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
