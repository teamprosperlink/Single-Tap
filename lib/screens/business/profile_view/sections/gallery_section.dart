import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying image gallery grid
class GallerySection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;
  final int maxImages;

  const GallerySection({
    super.key,
    required this.business,
    required this.config,
    this.maxImages = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final images = business.images;

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayImages = images.take(maxImages).toList();
    final hasMore = images.length > maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, isDarkMode, images.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: displayImages.length,
            itemBuilder: (context, index) {
              final isLast = index == displayImages.length - 1 && hasMore;
              return _GalleryItem(
                imageUrl: displayImages[index],
                isDarkMode: isDarkMode,
                showMoreOverlay: isLast,
                remainingCount: images.length - maxImages,
                onTap: () => _openGallery(context, images, index),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDarkMode, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white10 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          if (count > maxImages)
            TextButton(
              onPressed: () => _openGallery(context, business.images, 0),
              child: Text(
                'See All',
                style: TextStyle(
                  color: config.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openGallery(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: initialIndex,
          businessName: business.businessName,
        ),
      ),
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final String imageUrl;
  final bool isDarkMode;
  final bool showMoreOverlay;
  final int remainingCount;
  final VoidCallback onTap;

  const _GalleryItem({
    required this.imageUrl,
    required this.isDarkMode,
    this.showMoreOverlay = false,
    this.remainingCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDarkMode ? Colors.white10 : Colors.grey[200],
              ),
              errorWidget: (context, url, error) => Container(
                color: isDarkMode ? Colors.white10 : Colors.grey[200],
                child: Icon(
                  Icons.image,
                  color: isDarkMode ? Colors.white24 : Colors.grey[400],
                ),
              ),
            ),
            if (showMoreOverlay)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full screen gallery viewer
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String businessName;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
    required this.businessName,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
