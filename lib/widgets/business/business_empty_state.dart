import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../res/config/app_colors.dart';

/// Reusable empty state widget for business tabs.
/// Consolidates duplicate implementations from rooms_tab, menu_tab, products_tab.
class BusinessEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;
  final Color? buttonColor;
  final Widget? customButton;

  const BusinessEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
    this.buttonColor,
    this.customButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = iconColor ?? (isDarkMode ? AppColors.whiteAlpha(alpha: 0.24) : AppColors.lightGrayTint);
    final defaultButtonColor = buttonColor ?? AppTheme.primaryGreen;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in circle container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: defaultIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: defaultIconColor,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimaryDark : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            // Button
            if (customButton != null) ...[
              const SizedBox(height: 24),
              customButton!,
            ] else if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add, size: 20),
                label: Text(buttonText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: defaultButtonColor,
                  foregroundColor: AppColors.textPrimaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Factory for products empty state
  factory BusinessEmptyState.products({
    VoidCallback? onAddPressed,
  }) {
    return BusinessEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No Products Yet',
      subtitle: 'Add your first product to start selling and managing your inventory.',
      buttonText: 'Add Product',
      onButtonPressed: onAddPressed,
    );
  }

  /// Factory for menu items empty state
  factory BusinessEmptyState.menuItems({
    VoidCallback? onAddPressed,
  }) {
    return BusinessEmptyState(
      icon: Icons.restaurant_menu_outlined,
      title: 'No Menu Items Yet',
      subtitle: 'Add your first menu item to start receiving orders.',
      buttonText: 'Add Menu Item',
      onButtonPressed: onAddPressed,
    );
  }

  /// Factory for rooms empty state
  factory BusinessEmptyState.rooms({
    VoidCallback? onAddPressed,
  }) {
    return BusinessEmptyState(
      icon: Icons.hotel_outlined,
      title: 'No Rooms Yet',
      subtitle: 'Add your first room to start accepting bookings.',
      buttonText: 'Add Room',
      onButtonPressed: onAddPressed,
    );
  }

  /// Factory for services empty state
  factory BusinessEmptyState.services({
    VoidCallback? onAddPressed,
  }) {
    return BusinessEmptyState(
      icon: Icons.build_outlined,
      title: 'No Services Yet',
      subtitle: 'Add your services to let customers know what you offer.',
      buttonText: 'Add Service',
      onButtonPressed: onAddPressed,
    );
  }

  /// Factory for orders empty state
  factory BusinessEmptyState.orders() {
    return const BusinessEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Orders Yet',
      subtitle: 'Orders from your customers will appear here.',
    );
  }

  /// Factory for bookings empty state
  factory BusinessEmptyState.bookings() {
    return const BusinessEmptyState(
      icon: Icons.calendar_today_outlined,
      title: 'No Bookings Yet',
      subtitle: 'Room bookings from your guests will appear here.',
    );
  }

  /// Factory for gallery empty state
  factory BusinessEmptyState.gallery({
    VoidCallback? onAddPressed,
  }) {
    return BusinessEmptyState(
      icon: Icons.photo_library_outlined,
      title: 'No Photos Yet',
      subtitle: 'Add photos to showcase your business to customers.',
      buttonText: 'Add Photos',
      onButtonPressed: onAddPressed,
    );
  }

  /// Factory for reviews empty state
  factory BusinessEmptyState.reviews() {
    return const BusinessEmptyState(
      icon: Icons.star_outline,
      title: 'No Reviews Yet',
      subtitle: 'Reviews from your customers will appear here.',
    );
  }

  /// Factory for search no results
  factory BusinessEmptyState.noResults({
    String? searchTerm,
  }) {
    return BusinessEmptyState(
      icon: Icons.search_off,
      title: 'No Results Found',
      subtitle: searchTerm != null
          ? 'No items match "$searchTerm". Try a different search term.'
          : 'No items match your search criteria.',
    );
  }

  /// Factory for filtered no results
  factory BusinessEmptyState.noFilterResults({
    VoidCallback? onClearFilters,
  }) {
    return BusinessEmptyState(
      icon: Icons.filter_list_off,
      title: 'No Items Match Filters',
      subtitle: 'Try adjusting your filters to see more results.',
      buttonText: 'Clear Filters',
      onButtonPressed: onClearFilters,
    );
  }
}
