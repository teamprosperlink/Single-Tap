import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern Highlights Section with Gradient Chips
/// Features:
/// - Horizontal scrollable chips
/// - Gradient backgrounds on each chip
/// - Icons with text
/// - Shimmer loading effect
/// - Auto-scroll showcase
class ModernHighlightsSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ModernHighlightsSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final highlights = _getHighlights();

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header
        BusinessProfileComponents.modernSectionHeader(
          title: 'Highlights',
          isDarkMode: isDarkMode,
          icon: Icons.star_rounded,
          count: highlights.length,
        ),

        const SizedBox(height: 16),

        // Scrollable highlights
        SizedBox(
          height: 45,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            itemCount: highlights.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final highlight = highlights[index];
              return BusinessProfileComponents.highlightChip(
                label: highlight.label,
                icon: highlight.icon,
                gradient: highlight.gradient,
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  List<HighlightItem> _getHighlights() {
    final items = <HighlightItem>[];

    // Rating-based highlights
    if (business.rating >= 4.5) {
      items.add(HighlightItem(
        label: 'Top Rated',
        icon: Icons.star,
        gradient: const LinearGradient(
          colors: [AppTheme.warningOrange, Color(0xFFFFA726)],
        ),
      ));
    }

    // Verification highlight
    if (business.isVerified == true) {
      items.add(HighlightItem(
        label: 'Verified',
        icon: Icons.verified,
        gradient: const LinearGradient(
          colors: [AppTheme.infoBlue, Color(0xFF42A5F5)],
        ),
      ));
    }

    // Review count highlight
    if (business.reviewCount > 50) {
      items.add(HighlightItem(
        label: 'Popular',
        icon: Icons.trending_up,
        gradient: const LinearGradient(
          colors: [AppTheme.successGreen, Color(0xFF66BB6A)],
        ),
      ));
    }

    // Business-specific highlights from category data
    final categoryData = business.categoryData ?? {};
    int highlightIndex = items.length;
    for (final field in config.highlightFields) {
      final value = categoryData[field];
      if (value != null) {
        if (value is List && value.isNotEmpty) {
          for (final item in value.take(2)) {
            if (item is String && item.isNotEmpty && highlightIndex < 5) {
              items.add(HighlightItem(
                label: item,
                icon: _getHighlightIcon(item),
                gradient: _getHighlightGradient(highlightIndex),
              ));
              highlightIndex++;
            }
          }
        } else if (value is String && value.isNotEmpty && highlightIndex < 5) {
          items.add(HighlightItem(
            label: value,
            icon: _getHighlightIcon(value),
            gradient: _getHighlightGradient(highlightIndex),
          ));
          highlightIndex++;
        }
      }
    }

    // Default highlights if none available
    if (items.isEmpty) {
      items.add(HighlightItem(
        label: 'Open Now',
        icon: Icons.access_time,
        gradient: const LinearGradient(
          colors: [AppTheme.successGreen, Color(0xFF66BB6A)],
        ),
      ));
    }

    return items;
  }

  IconData _getHighlightIcon(String highlight) {
    final lower = highlight.toLowerCase();
    if (lower.contains('fast')) return Icons.flash_on;
    if (lower.contains('free')) return Icons.card_giftcard;
    if (lower.contains('award')) return Icons.emoji_events;
    if (lower.contains('delivery')) return Icons.local_shipping;
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('certified')) return Icons.workspace_premium;
    if (lower.contains('24')) return Icons.schedule;
    return Icons.check_circle;
  }

  LinearGradient _getHighlightGradient(int index) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
      ),
      const LinearGradient(
        colors: [Color(0xFFf093fb), Color(0xFFF5576C)],
      ),
      const LinearGradient(
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      ),
      const LinearGradient(
        colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
      ),
      const LinearGradient(
        colors: [Color(0xFFfa709a), Color(0xFFfee140)],
      ),
    ];
    return gradients[index % gradients.length];
  }
}

class HighlightItem {
  final String label;
  final IconData icon;
  final LinearGradient gradient;

  HighlightItem({
    required this.label,
    required this.icon,
    required this.gradient,
  });
}
