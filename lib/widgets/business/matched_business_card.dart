import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/business_model.dart';
import '../../screens/business/profile_view/business_profile_screen.dart';
import '../../config/app_theme.dart';
import '../../res/config/app_colors.dart';

/// A business card designed for displaying matched businesses in search results.
/// Features a prominent match percentage, quick action buttons, and rich business info.
///
/// Usage in match results:
/// ```dart
/// MatchedBusinessCard(
///   business: businessModel,
///   matchPercentage: 92.5,
///   distance: 2.3,
///   onMessage: () => _startConversation(businessModel),
///   onCall: () => _makeCall(businessModel),
/// )
/// ```
class MatchedBusinessCard extends StatelessWidget {
  final BusinessModel business;
  final double matchPercentage;
  final double? distance; // in kilometers
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onTap;
  final List<String>? popularItems; // For restaurants: popular menu items
  final String? priceRange; // e.g., "₹400 for two"

  const MatchedBusinessCard({
    super.key,
    required this.business,
    required this.matchPercentage,
    this.distance,
    this.onMessage,
    this.onCall,
    this.onTap,
    this.popularItems,
    this.priceRange,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ?? () => _navigateToProfile(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(isDarkMode),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackAlpha(alpha: isDarkMode ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with overlays
            _buildCoverSection(context, isDarkMode),

            // Business info section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name, rating, verification
                  _buildHeaderRow(isDarkMode),

                  const SizedBox(height: 4),

                  // Tagline/SubType
                  if (business.tagline != null || business.subType != null)
                    Text(
                      business.tagline ?? business.subType ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 12),

                  // Highlights row (distance, hours, price)
                  _buildHighlightsRow(isDarkMode),

                  // Popular items (for restaurants)
                  if (popularItems != null && popularItems!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPopularItems(isDarkMode),
                  ],

                  const SizedBox(height: 16),

                  // Quick action buttons
                  _buildActionButtons(context, isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection(BuildContext context, bool isDarkMode) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image
            if (business.coverImage != null && business.coverImage!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: business.coverImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildCoverPlaceholder(isDarkMode),
                errorWidget: (context, url, error) => _buildCoverPlaceholder(isDarkMode),
              )
            else
              _buildCoverPlaceholder(isDarkMode),

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

            // Match percentage badge (top right)
            Positioned(
              top: 12,
              right: 12,
              child: _buildMatchBadge(),
            ),

            // Category badge (top left)
            Positioned(
              top: 12,
              left: 12,
              child: _buildCategoryBadge(isDarkMode),
            ),

            // Logo and basic info (bottom)
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildLogo(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Open status
                        if (business.hours != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: business.hours!.isCurrentlyOpen
                                  ? AppTheme.successGreen.withValues(alpha: 0.9)
                                  : AppColors.error.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: AppColors.textPrimaryDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  business.hours!.isCurrentlyOpen
                                      ? 'Open Now'
                                      : 'Closed',
                                  style: const TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchBadge() {
    // Determine color based on match percentage
    Color badgeColor;
    if (matchPercentage >= 90) {
      badgeColor = AppTheme.primaryGreen; // Bright green
    } else if (matchPercentage >= 75) {
      badgeColor = AppColors.iosBlue; // Blue
    } else if (matchPercentage >= 60) {
      badgeColor = AppColors.warning;
    } else {
      badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 14,
            color: AppColors.textPrimaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            '${matchPercentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'Match',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blackAlpha(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            BusinessTypes.getIcon(business.businessType),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            business.businessType,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.textPrimaryDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          business.businessName.isNotEmpty
              ? business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 48,
          color: AppColors.textPrimaryDark.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: Text(
            business.businessName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimaryDark : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (business.isVerified)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 12, color: AppColors.textPrimaryDark),
                SizedBox(width: 2),
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
        const SizedBox(width: 8),
        // Rating
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: AppTheme.warningOrange, size: 14),
              const SizedBox(width: 2),
              Text(
                business.formattedRating,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                ' (${business.reviewCount})',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightsRow(bool isDarkMode) {
    final highlights = <Widget>[];

    // Distance
    if (distance != null) {
      highlights.add(_HighlightChip(
        icon: Icons.location_on,
        text: distance! < 1
            ? '${(distance! * 1000).toStringAsFixed(0)}m away'
            : '${distance!.toStringAsFixed(1)}km away',
        color: AppColors.iosBlue,
        isDarkMode: isDarkMode,
      ));
    }

    // Price range
    if (priceRange != null) {
      highlights.add(_HighlightChip(
        icon: Icons.currency_rupee,
        text: priceRange!,
        color: AppTheme.primaryGreen,
        isDarkMode: isDarkMode,
      ));
    }

    // Address (city only for privacy)
    if (business.address != null && business.address!.city != null) {
      highlights.add(_HighlightChip(
        icon: Icons.place,
        text: business.address!.city!,
        color: AppColors.purpleAccent,
        isDarkMode: isDarkMode,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: highlights,
    );
  }

  Widget _buildPopularItems(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POPULAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? AppColors.textPrimaryDark38 : Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          popularItems!.take(3).join(' • '),
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDarkMode) {
    return Row(
      children: [
        // Message button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: AppColors.textPrimaryDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Call button
        OutlinedButton.icon(
          onPressed: onCall,
          icon: const Icon(Icons.phone_outlined, size: 18),
          label: const Text('Call'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700],
            side: BorderSide(
              color: isDarkMode ? AppColors.textPrimaryDark24 : Colors.grey[300]!,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // View Profile button
        IconButton(
          onPressed: () => _navigateToProfile(context),
          icon: Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
          ),
          style: IconButton.styleFrom(
            backgroundColor: isDarkMode ? AppColors.textPrimaryDark10 : Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(businessId: business.id),
      ),
    );
  }
}

/// Compact highlight chip widget
class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isDarkMode;

  const _HighlightChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Smaller match card for grid or list views
class MatchedBusinessCardCompact extends StatelessWidget {
  final BusinessModel business;
  final double matchPercentage;
  final double? distance;
  final VoidCallback? onTap;

  const MatchedBusinessCardCompact({
    super.key,
    required this.business,
    required this.matchPercentage,
    this.distance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessProfileScreen(businessId: business.id),
                ),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(isDarkMode),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackAlpha(alpha: isDarkMode ? 0.2 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with match badge
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (business.coverImage != null)
                      CachedNetworkImage(
                        imageUrl: business.coverImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                          child: const Icon(Icons.storefront,
                              size: 32, color: AppColors.textPrimaryDark54),
                        ),
                      )
                    else
                      Container(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        child: const Icon(Icons.storefront,
                            size: 32, color: AppColors.textPrimaryDark54),
                      ),

                    // Match badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: matchPercentage >= 80
                              ? AppTheme.primaryGreen
                              : AppColors.iosBlue,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          '${matchPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.businessName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.textPrimaryDark : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (business.isVerified)
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Rating and distance
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: AppTheme.warningOrange),
                      const SizedBox(width: 2),
                      Text(
                        business.formattedRating,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[600],
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[500],
                        ),
                        Text(
                          '${distance!.toStringAsFixed(1)}km',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[500],
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
}
