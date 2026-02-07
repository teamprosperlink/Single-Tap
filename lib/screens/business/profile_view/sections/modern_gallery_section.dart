import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern Gallery Section with Staggered Grid
/// Features:
/// - Staggered grid layout
/// - Hero image (larger first image)
/// - Rounded corners with shadows
/// - Lightbox viewer
/// - Category tags on images
/// - +N more indicator
class ModernGallerySection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ModernGallerySection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gallery = business.images;

    if (gallery.isEmpty) return const SizedBox.shrink();

    // Show max 7 images (1 hero + 6 smaller)
    final displayImages = gallery.take(7).toList();
    final hasMore = gallery.length > 7;
    final moreCount = gallery.length - 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header
        BusinessProfileComponents.modernSectionHeader(
          title: 'Gallery',
          isDarkMode: isDarkMode,
          icon: Icons.photo_library,
          count: gallery.length,
          actionLabel: 'View All',
          onAction: () => _viewAllGallery(context, gallery),
        ),

        const SizedBox(height: 16),

        // Gallery grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: _buildGalleryGrid(context, displayImages, hasMore, moreCount, isDarkMode),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGalleryGrid(
    BuildContext context,
    List<String> images,
    bool hasMore,
    int moreCount,
    bool isDarkMode,
  ) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Hero image (first image - larger)
        _buildHeroImage(context, images[0], 0, isDarkMode),

        if (images.length > 1) ...[
          const SizedBox(height: 12),

          // Grid of smaller images
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: images.length - 1,
            itemBuilder: (context, index) {
              final imageIndex = index + 1;
              final isLast = imageIndex == images.length - 1;

              return _buildGridImage(
                context,
                images[imageIndex],
                imageIndex,
                isLast && hasMore,
                moreCount,
                isDarkMode,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHeroImage(
    BuildContext context,
    String imageUrl,
    int index,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () => _openLightbox(context, index),
      child: Hero(
        tag: 'gallery_$index',
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(isDarkMode),
              errorWidget: (context, url, error) => _buildPlaceholder(isDarkMode),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridImage(
    BuildContext context,
    String imageUrl,
    int index,
    bool isLast,
    int moreCount,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () => _openLightbox(context, index),
      child: Hero(
        tag: 'gallery_$index',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(isDarkMode),
                  errorWidget: (context, url, error) => _buildPlaceholder(isDarkMode),
                ),
              ),

              // "+N more" overlay on last image
              if (isLast)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+$moreCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'More',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDarkMode) {
    return Container(
      color: AppTheme.cardColor(isDarkMode),
      child: Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: AppTheme.secondaryText(isDarkMode),
        ),
      ),
    );
  }

  void _openLightbox(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _GalleryLightbox(
          images: business.images,
          initialIndex: index,
          businessName: business.businessName,
        ),
      ),
    );
  }

  void _viewAllGallery(BuildContext context, List<String> images) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _GalleryLightbox(
          images: images,
          initialIndex: 0,
          businessName: business.businessName,
        ),
      ),
    );
  }
}

/// Full-screen gallery lightbox viewer
class _GalleryLightbox extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String businessName;

  const _GalleryLightbox({
    required this.images,
    required this.initialIndex,
    required this.businessName,
  });

  @override
  State<_GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<_GalleryLightbox> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image viewer
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: 'gallery_$index',
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.images[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top bar
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentIndex + 1} / ${widget.images.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom indicator
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.images.length > 10 ? 10 : widget.images.length,
                    (index) {
                      if (index == 9 && widget.images.length > 10) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '...',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentIndex ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentIndex
                              ? AppTheme.primaryGreen
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
