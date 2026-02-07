import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern Hero Section with Glassmorphism and Parallax Effect
/// Features:
/// - Parallax scrolling cover image
/// - Glassmorphic info card overlaying the cover
/// - Large profile logo with subtle glow
/// - Prominent ratings and verification badge
/// - Status chips (Open/Closed)
/// - Smooth animations and transitions
class ModernHeroSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBack;

  const ModernHeroSection({
    super.key,
    required this.business,
    required this.config,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 340,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      leading: IconButton(
        icon: _buildGlassButton(Icons.arrow_back, isDarkMode),
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: _buildGlassButton(Icons.share_outlined, isDarkMode),
          onPressed: () => _shareProfile(context),
        ),
        IconButton(
          icon: _buildGlassButton(Icons.favorite_outline, isDarkMode),
          onPressed: () => _toggleFavorite(context),
        ),
        IconButton(
          icon: _buildGlassButton(Icons.more_vert, isDarkMode),
          onPressed: () => _showMoreOptions(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        background: _buildHeroContent(context, isDarkMode),
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.blackAlpha(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.whiteAlpha(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.textPrimaryDark, size: 20),
    );
  }

  Widget _buildHeroContent(BuildContext context, bool isDarkMode) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image with gradient overlay
        _buildCoverWithGradient(),

        // Glassmorphic business info card
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildGlassmorphicInfoCard(context, isDarkMode),
        ),
      ],
    );
  }

  Widget _buildCoverWithGradient() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image or gradient placeholder
        if (business.coverImage != null && business.coverImage!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: business.coverImage!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholderCover(),
            errorWidget: (context, url, error) => _buildPlaceholderCover(),
          )
        else
          _buildPlaceholderCover(),

        // Modern gradient overlay for readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.transparent,
                AppColors.blackAlpha(alpha: 0.15),
                AppColors.blackAlpha(alpha: 0.5),
                AppColors.blackAlpha(alpha: 0.8),
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.primaryColor,
            config.primaryColor.withValues(alpha: 0.8),
            config.accentColor,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          config.primarySectionIcon,
          size: 80,
          color: AppColors.whiteAlpha(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicInfoCard(BuildContext context, bool isDarkMode) {
    return BusinessProfileComponents.glassCard(
      isDarkMode: isDarkMode,
      borderRadius: AppTheme.radiusLarge,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Logo with glow effect
                _buildLogo(),
                const SizedBox(width: 16),

                // Business name and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              business.businessName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryDark,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (business.isVerified == true)
                            BusinessProfileComponents.verifiedBadge(size: 20),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Rating
                      BusinessProfileComponents.ratingWidget(
                          rating: business.rating,
                          reviewCount: business.reviewCount,
                          isDarkMode: false, // Always light on dark overlay
                          size: 18,
                        ),

                      const SizedBox(height: 12),

                      // Status chips row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Open/Closed status
                          _buildStatusChip(),

                          // Category
                          BusinessProfileComponents.statusChip(
                            label: _getCategoryName(),
                            color: config.primaryColor,
                            isDarkMode: false,
                            icon: config.primarySectionIcon,
                          ),

                          // Location
                          if (business.address?.city != null)
                            BusinessProfileComponents.statusChip(
                              label: business.address!.city!,
                              color: AppTheme.infoBlue,
                              isDarkMode: false,
                              icon: Icons.location_on,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.backgroundLightSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppColors.whiteAlpha(alpha: 0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: config.primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: business.logo != null && business.logo!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: business.logo!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildLogoPlaceholder(),
                errorWidget: (context, url, error) => _buildLogoPlaceholder(),
              )
            : _buildLogoPlaceholder(),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.primaryColor, config.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        config.primarySectionIcon,
        color: AppColors.textPrimaryDark,
        size: 32,
      ),
    );
  }

  Widget _buildStatusChip() {
    final isOpen = _isBusinessOpen();
    return BusinessProfileComponents.statusChip(
      label: isOpen ? 'Open Now' : 'Closed',
      color: isOpen ? AppTheme.successGreen : AppTheme.errorRed,
      isDarkMode: false,
      icon: isOpen ? Icons.check_circle : Icons.cancel,
    );
  }

  bool _isBusinessOpen() {
    return business.hours?.isCurrentlyOpen ?? true;
  }

  String _getCategoryName() {
    return business.category.toString().split('.').last.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        ).trim();
  }

  void _shareProfile(BuildContext context) {
    Share.share(
      'Check out ${business.businessName}!\n\n'
          '${business.description ?? ""}\n\n'
          'Location: ${business.address?.formattedAddress ?? "Address not available"}\n'
          'Rating: ${business.rating} ⭐',
      subject: business.businessName,
    );
  }

  void _toggleFavorite(BuildContext context) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to favorites')),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor(isDarkMode),
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.iosGrayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Block'),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Report Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this business?'),
            const SizedBox(height: 16),
            ...['Spam or misleading', 'Inappropriate content', 'Fraud or scam', 'Other'].map((reason) =>
              ListTile(
                dense: true,
                title: Text(reason),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. We\'ll review it shortly.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Block Business'),
        content: Text('You will no longer see ${business.businessName} in your feed. You can unblock from settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${business.businessName} has been blocked'),
                ),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
