import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';

/// Hero section with cover image, logo, and business info
/// Uses SliverAppBar for collapsing effect
class HeroSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBack;

  const HeroSection({
    super.key,
    required this.business,
    required this.config,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.blackAlpha(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back, color: AppColors.textPrimaryDark, size: 20),
        ),
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.blackAlpha(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.share, color: AppColors.textPrimaryDark, size: 20),
          ),
          onPressed: () => _shareProfile(context),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.blackAlpha(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.more_vert, color: AppColors.textPrimaryDark, size: 20),
          ),
          onPressed: () => _showMoreOptions(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroContent(context, isDarkMode),
      ),
    );
  }

  Widget _buildHeroContent(BuildContext context, bool isDarkMode) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image
        _buildCoverImage(),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.transparent,
                AppColors.blackAlpha(alpha: 0.3),
                AppColors.blackAlpha(alpha: 0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Business info at bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildBusinessInfo(context, isDarkMode),
        ),
      ],
    );
  }

  Widget _buildCoverImage() {
    if (business.coverImage != null && business.coverImage!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: business.coverImage!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: config.primaryColor.withValues(alpha: 0.3),
          child: Center(
            child: CircularProgressIndicator(
              color: config.primaryColor,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderCover(),
      );
    }
    return _buildPlaceholderCover();
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.primaryColor,
            config.accentColor,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          config.primarySectionIcon,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildBusinessInfo(BuildContext context, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Logo
        _buildLogo(),
        const SizedBox(width: 12),

        // Name, tagline, rating
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Business name
              Text(
                business.businessName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: AppColors.blackAlpha(alpha: 0.45),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Tagline or subtype
              if (business.tagline != null || business.subType != null) ...[
                const SizedBox(height: 4),
                Text(
                  business.tagline ?? business.subType ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.whiteAlpha(alpha: 0.9),
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: AppColors.blackAlpha(alpha: 0.45),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 8),

              // Rating and review count
              Row(
                children: [
                  _buildRatingStars(),
                  const SizedBox(width: 8),
                  Text(
                    '${business.formattedRating} (${business.reviewCount} reviews)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.whiteAlpha(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (business.isVerified) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 12,
                            color: AppColors.textPrimaryDark,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.backgroundLightSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          business.businessName.isNotEmpty
              ? business.businessName[0].toUpperCase()
              : 'B',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: config.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < business.rating.floor()) {
          return Icon(Icons.star, size: 16, color: AppColors.iosYellow);
        } else if (index < business.rating) {
          return Icon(Icons.star_half, size: 16, color: AppColors.iosYellow);
        } else {
          return Icon(
            Icons.star_border,
            size: 16,
            color: AppColors.whiteAlpha(alpha: 0.5),
          );
        }
      }),
    );
  }

  void _shareProfile(BuildContext context) async {
    final shareText = _buildShareText();

    try {
      await Share.share(
        shareText,
        subject: 'Check out ${business.businessName} on Plink!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share. Please try again.')),
        );
      }
    }
  }

  String _buildShareText() {
    final buffer = StringBuffer();

    // Business name and type
    buffer.writeln(business.businessName);
    if (business.subType != null) {
      buffer.writeln(business.subType!);
    }
    buffer.writeln();

    // Rating
    if (business.reviewCount > 0) {
      buffer.writeln('⭐ ${business.formattedRating} (${business.reviewCount} reviews)');
    }

    // Address
    if (business.address != null && business.address!.formattedAddress.isNotEmpty) {
      buffer.writeln('📍 ${business.address!.formattedAddress}');
    }

    // Phone
    if (business.contact.phone != null) {
      buffer.writeln('📞 ${business.contact.phone}');
    }

    // Description
    if (business.description != null && business.description!.isNotEmpty) {
      buffer.writeln();
      final desc = business.description!.length > 150
          ? '${business.description!.substring(0, 150)}...'
          : business.description!;
      buffer.writeln(desc);
    }

    buffer.writeln();
    buffer.writeln('Found on Plink - Your local business discovery app');

    return buffer.toString();
  }

  void _copyDetails(BuildContext context) {
    final copyText = _buildShareText();
    Clipboard.setData(ClipboardData(text: copyText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.iosGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
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
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Details'),
              onTap: () {
                Navigator.pop(context);
                _copyDetails(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  Navigator.pop(context);
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
            onPressed: () => Navigator.pop(context),
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
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Block Business'),
        content: Text('You will no longer see ${business.businessName} in your feed. You can unblock from settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
