import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supper/models/business_model.dart';
import 'package:supper/res/config/app_colors.dart';

/// Dashboard cover image header widget (LinkedIn-style)
/// Displays business cover image with logo, name, and category badge
class DashboardCoverHeader extends StatelessWidget {
  final BusinessModel business;
  final Color categoryColor;
  final IconData categoryIcon;
  final String categoryLabel;
  final VoidCallback? onEditCover;

  const DashboardCoverHeader({
    super.key,
    required this.business,
    required this.categoryColor,
    required this.categoryIcon,
    required this.categoryLabel,
    this.onEditCover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image
          _buildCoverImage(),

          // Gradient overlay for text legibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.transparent,
                  AppColors.blackAlpha(alpha: 0.2),
                  AppColors.blackAlpha(alpha: 0.7),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Edit cover button (top-right)
          if (onEditCover != null)
            Positioned(
              top: 12,
              right: 12,
              child: _buildEditButton(),
            ),

          // Business info at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildBusinessInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    if (business.coverImage != null && business.coverImage!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: business.coverImage!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderCover(),
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
            categoryColor,
            categoryColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          categoryIcon,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onEditCover?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.blackAlpha(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.camera_alt_outlined,
          color: AppColors.textPrimaryDark,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildBusinessInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Business logo
        _buildLogo(),
        const SizedBox(width: 12),

        // Business name and category
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Business name
              Text(
                business.businessName,
                style: TextStyle(
                  fontSize: 20,
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

              const SizedBox(height: 6),

              // Category badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcon,
                          size: 12,
                          color: AppColors.textPrimaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (business.isVerified) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.backgroundLightSecondary,
        borderRadius: BorderRadius.circular(12),
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
      color: categoryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          business.businessName.isNotEmpty
              ? business.businessName[0].toUpperCase()
              : 'B',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: categoryColor,
          ),
        ),
      ),
    );
  }
}
