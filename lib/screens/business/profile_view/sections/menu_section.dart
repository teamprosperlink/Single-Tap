import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/menu_model.dart';
import '../../../../services/business_service.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying menu items for restaurants
class MenuSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final bool showCategories;
  final VoidCallback? onItemTap;

  const MenuSection({
    super.key,
    required this.businessId,
    required this.config,
    this.showCategories = true,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<MenuCategoryModel>>(
      stream: BusinessService().watchMenuCategories(businessId),
      builder: (context, categorySnapshot) {
        return StreamBuilder<List<MenuItemModel>>(
          stream: BusinessService().watchMenuItems(businessId),
          builder: (context, itemSnapshot) {
            if (categorySnapshot.connectionState == ConnectionState.waiting ||
                itemSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading(isDarkMode);
            }

            final categories = categorySnapshot.data ?? [];
            final items = itemSnapshot.data ?? [];

            if (items.isEmpty) {
              return _buildEmptyState(isDarkMode);
            }

            // Group items by category
            final groupedItems = <String, List<MenuItemModel>>{};
            for (final item in items) {
              final categoryId = item.categoryId;
              groupedItems.putIfAbsent(categoryId, () => []);
              groupedItems[categoryId]!.add(item);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(isDarkMode),
                if (showCategories && categories.isNotEmpty)
                  ...categories.map((category) {
                    final categoryItems = groupedItems[category.id] ?? [];
                    if (categoryItems.isEmpty) return const SizedBox.shrink();
                    return _MenuCategorySection(
                      category: category,
                      items: categoryItems,
                      config: config,
                      isDarkMode: isDarkMode,
                      onItemTap: onItemTap,
                    );
                  })
                else
                  ...items.map((item) => MenuItemCard(
                        item: item,
                        config: config,
                        isDarkMode: isDarkMode,
                        onTap: onItemTap,
                      )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: config.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text(
              config.emptyStateIcon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              config.emptyStateMessage,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCategorySection extends StatelessWidget {
  final MenuCategoryModel category;
  final List<MenuItemModel> items;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onItemTap;

  const _MenuCategorySection({
    required this.category,
    required this.items,
    required this.config,
    required this.isDarkMode,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
        ...items.map((item) => MenuItemCard(
              item: item,
              config: config,
              isDarkMode: isDarkMode,
              onTap: onItemTap,
            )),
      ],
    );
  }
}

/// Card widget for displaying a menu item
class MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.config,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veg/Non-veg indicator
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: (item.foodType == FoodType.veg || item.foodType == FoodType.vegan) ? Colors.green : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (item.foodType == FoodType.veg || item.foodType == FoodType.vegan) ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: config.primaryColor,
                    ),
                  ),
                  if (!item.isAvailable) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Not Available',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Item image
            if (item.image != null && item.image!.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.image!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: isDarkMode ? Colors.white10 : Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: isDarkMode ? Colors.white10 : Colors.grey[200],
                    child: Icon(
                      Icons.restaurant,
                      color: isDarkMode ? Colors.white24 : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
