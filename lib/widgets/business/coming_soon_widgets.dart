/// Reusable widgets for displaying "Coming Soon" features
///
/// This file provides UI components for features that are not yet available
/// but planned for future releases.
library;

import 'package:flutter/material.dart';
import 'package:supper/config/feature_flags.dart';
import 'package:supper/services/firebase_provider.dart';

// ============================================================================
// COMING SOON BADGE
// ============================================================================

/// A badge to display "Coming Soon" label
class ComingSoonBadge extends StatelessWidget {
  final String? customText;
  final Color? backgroundColor;
  final Color? textColor;
  final bool compact;

  const ComingSoonBadge({
    super.key,
    this.customText,
    this.backgroundColor,
    this.textColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: (backgroundColor ?? Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (backgroundColor ?? Colors.orange).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        customText ?? 'Coming Soon',
        style: TextStyle(
          color: textColor ?? Colors.orange.shade700,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================================
// COMING SOON DIALOG
// ============================================================================

/// Show a dialog explaining a coming soon feature
Future<void> showComingSoonDialog(
  BuildContext context,
  String featureName, {
  VoidCallback? onNotifyMe,
}) async {
  final featureInfo = FeatureFlags.getFeatureInfo(featureName);

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.schedule,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              featureInfo?.title ?? 'Coming Soon',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featureInfo != null) ...[
            Text(
              featureInfo.description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated Release: ${featureInfo.estimatedRelease}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'This feature is currently in development and will be available soon.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Maybe Later'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.notifications_active, size: 18),
          label: const Text('Notify Me'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            final userId = FirebaseProvider.currentUserId;
            if (userId != null) {
              await FeatureFlags.registerInterest(featureName, userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thanks! We\'ll notify you when ${featureInfo?.title ?? 'this feature'} is available.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            }
            if (onNotifyMe != null) {
              onNotifyMe();
            }
          },
        ),
      ],
    ),
  );
}

// ============================================================================
// FEATURE LOCKED CARD
// ============================================================================

/// A card showing a locked/coming soon feature
class FeatureLockedCard extends StatelessWidget {
  final String featureName;
  final VoidCallback? onTap;

  const FeatureLockedCard({
    super.key,
    required this.featureName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final featureInfo = FeatureFlags.getFeatureInfo(featureName);
    if (featureInfo == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? () => showComingSoonDialog(context, featureName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconData(featureInfo.icon),
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featureInfo.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          featureInfo.estimatedRelease,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ComingSoonBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                featureInfo.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Learn More'),
                    onPressed: () => showComingSoonDialog(context, featureName),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Map icon name strings to IconData
    final iconMap = {
      'people': Icons.people,
      'analytics': Icons.analytics,
      'card_membership': Icons.card_membership,
      'location_on': Icons.location_on,
      'calendar_today': Icons.calendar_today,
      'stars': Icons.stars,
      'receipt': Icons.receipt,
      'upload_file': Icons.upload_file,
      'sms': Icons.sms,
      'email': Icons.email,
      'rule': Icons.rule,
      'trending_up': Icons.trending_up,
      'table_restaurant': Icons.table_restaurant,
      'qr_code': Icons.qr_code,
      'delivery_dining': Icons.delivery_dining,
      'card_giftcard': Icons.card_giftcard,
      'segment': Icons.segment,
      'share': Icons.share,
      'shield': Icons.shield,
      'qr_code_scanner': Icons.qr_code_scanner,
    };
    return iconMap[iconName] ?? Icons.new_releases;
  }
}

// ============================================================================
// COMING SOON LIST TILE
// ============================================================================

/// A ListTile with coming soon styling and functionality
class ComingSoonListTile extends StatelessWidget {
  final String featureName;
  final IconData? leadingIcon;
  final VoidCallback? onTap;
  final bool showBadge;

  const ComingSoonListTile({
    super.key,
    required this.featureName,
    this.leadingIcon,
    this.onTap,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final featureInfo = FeatureFlags.getFeatureInfo(featureName);
    if (featureInfo == null) return const SizedBox.shrink();

    return Opacity(
      opacity: 0.7,
      child: ListTile(
        leading: leadingIcon != null
            ? Icon(leadingIcon, color: Colors.grey.shade600)
            : Icon(_getIconData(featureInfo.icon), color: Colors.grey.shade600),
        title: Text(
          featureInfo.title,
          style: TextStyle(color: Colors.grey.shade800),
        ),
        subtitle: Text(
          featureInfo.estimatedRelease,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: showBadge ? const ComingSoonBadge(compact: true) : null,
        enabled: true,
        onTap: onTap ?? () => showComingSoonDialog(context, featureName),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'people': Icons.people,
      'analytics': Icons.analytics,
      'card_membership': Icons.card_membership,
      'location_on': Icons.location_on,
      'calendar_today': Icons.calendar_today,
      'stars': Icons.stars,
      'receipt': Icons.receipt,
      'upload_file': Icons.upload_file,
      'sms': Icons.sms,
      'email': Icons.email,
      'rule': Icons.rule,
      'trending_up': Icons.trending_up,
      'table_restaurant': Icons.table_restaurant,
      'qr_code': Icons.qr_code,
      'delivery_dining': Icons.delivery_dining,
      'card_giftcard': Icons.card_giftcard,
      'segment': Icons.segment,
      'share': Icons.share,
      'shield': Icons.shield,
      'qr_code_scanner': Icons.qr_code_scanner,
    };
    return iconMap[iconName] ?? Icons.new_releases;
  }
}

// ============================================================================
// COMING SOON SECTION
// ============================================================================

/// A section showing multiple coming soon features
class ComingSoonSection extends StatelessWidget {
  final String title;
  final FeatureCategory? category;
  final List<String>? specificFeatures;

  const ComingSoonSection({
    super.key,
    this.title = 'Coming Soon',
    this.category,
    this.specificFeatures,
  });

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, FeatureInfo>> features;

    if (specificFeatures != null) {
      // Show specific features
      features = specificFeatures!
          .where((name) => FeatureFlags.getFeatureInfo(name) != null)
          .map((name) => MapEntry(name, FeatureFlags.getFeatureInfo(name)!))
          .toList();
    } else if (category != null) {
      // Show features by category
      features = FeatureFlags.getFeaturesByCategory(category!);
    } else {
      // Show all coming soon features
      features = FeatureFlags.getComingSoonFeatures();
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.upcoming, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final entry = features[index];
            return ComingSoonListTile(featureName: entry.key);
          },
        ),
      ],
    );
  }
}

// ============================================================================
// COMING SOON BOTTOM SHEET
// ============================================================================

/// Show a bottom sheet with all coming soon features
Future<void> showComingSoonBottomSheet(BuildContext context) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.upcoming, color: Colors.orange.shade700, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Features',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Features we\'re working on',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Feature list
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Group by category
                  for (final category in FeatureCategory.values) ...[
                    if (FeatureFlags.getFeaturesByCategory(category).isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      ...FeatureFlags.getFeaturesByCategory(category)
                          .map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FeatureLockedCard(featureName: entry.key),
                              )),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// CONDITIONAL WIDGET WRAPPER
// ============================================================================

/// Wrap a widget to show it only if feature is enabled, otherwise show coming soon
class ConditionalFeatureWidget extends StatelessWidget {
  final bool featureEnabled;
  final String featureName;
  final Widget child;
  final Widget? comingSoonWidget;

  const ConditionalFeatureWidget({
    super.key,
    required this.featureEnabled,
    required this.featureName,
    required this.child,
    this.comingSoonWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (featureEnabled) {
      return child;
    }

    return comingSoonWidget ?? FeatureLockedCard(featureName: featureName);
  }
}
