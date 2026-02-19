import 'package:flutter/material.dart';

/// Types of quick actions available on a category profile.
enum QuickActionType {
  call,
  chat,
  SingleTap,
  book,
  order,
  enquire,
  website,
  map,
  share,
  message,
  directions,
}

/// Represents a quick action button on a profile.
class QuickAction {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final QuickActionType type;

  const QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    required this.type,
  });
}

/// Configuration for how a category profile page should be displayed.
class CategoryProfileConfig {
  final String category;
  final Color primaryColor;
  final Color accentColor;
  final List<QuickAction> quickActions;
  final bool showMenuSection;
  final bool showProductsSection;
  final bool showServicesSection;
  final bool showRoomsSection;
  final bool showPortfolioSection;
  final String primarySectionTitle;
  final IconData primarySectionIcon;
  final String emptyStateIcon;
  final String emptyStateMessage;
  final List<String> highlightFields;

  const CategoryProfileConfig({
    required this.category,
    required this.primaryColor,
    this.accentColor = Colors.blue,
    this.quickActions = const [],
    this.showMenuSection = false,
    this.showProductsSection = false,
    this.showServicesSection = false,
    this.showRoomsSection = false,
    this.showPortfolioSection = false,
    this.primarySectionTitle = 'Services',
    this.primarySectionIcon = Icons.business,
    this.emptyStateIcon = '📭',
    this.emptyStateMessage = 'No items yet',
    this.highlightFields = const [],
  });

  /// Get the profile configuration for a given category.
  /// Returns a default config if the category is not recognized.
  static CategoryProfileConfig getConfig(dynamic category) {
    final cat = category?.toString() ?? '';
    return CategoryProfileConfig(
      category: cat,
      primaryColor: Colors.blue,
      accentColor: Colors.blue,
      quickActions: [
        const QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone,
          color: Colors.green,
          isPrimary: true,
          type: QuickActionType.call,
        ),
        const QuickAction(
          id: 'chat',
          label: 'Chat',
          icon: Icons.chat,
          color: Colors.blue,
          type: QuickActionType.chat,
        ),
        const QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share,
          color: Colors.orange,
          type: QuickActionType.share,
        ),
      ],
      showMenuSection: false,
      showProductsSection: false,
      showServicesSection: true,
      showRoomsSection: false,
      showPortfolioSection: false,
    );
  }
}
