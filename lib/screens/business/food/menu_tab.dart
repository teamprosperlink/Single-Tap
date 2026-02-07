import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/menu_model.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';
import 'menu_item_form_screen.dart';
import 'menu_category_screen.dart';

/// Tab for managing restaurant/cafe menu
class MenuTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const MenuTab({
    super.key,
    required this.business,
    this.onRefresh,
  });

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> with SingleTickerProviderStateMixin {
  final BusinessService _businessService = BusinessService();
  String? _selectedCategoryId;
  String _filterType = 'all'; // all, available, unavailable, veg, nonVeg

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDarkMode),
            _buildCategoryTabs(isDarkMode),
            _buildFilterChips(isDarkMode),
            Expanded(child: _buildMenuItemsList(isDarkMode)),
          ],
        ),
      ),
      floatingActionButton: StreamBuilder<List<MenuItemModel>>(
        stream: _businessService.watchMenuItems(widget.business.id),
        builder: (context, snapshot) {
          final hasItems = (snapshot.data ?? []).isNotEmpty;

          // Only show FAB if there are items (empty state has its own button)
          if (!hasItems) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _addMenuItem,
            backgroundColor: const Color(0xFF00D67D),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Item',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Color(0xFF00D67D),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Manage your food items',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _manageCategories,
            icon: Icon(
              Icons.category_outlined,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
            tooltip: 'Manage Categories',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDarkMode) {
    return StreamBuilder<List<MenuCategoryModel>>(
      stream: _businessService.watchMenuCategories(widget.business.id),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create categories to organize your menu',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _manageCategories,
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Color(0xFF00D67D)),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: _selectedCategoryId == null,
                onTap: () => setState(() => _selectedCategoryId = null),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 8),
              ...categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryChip(
                    label: category.name,
                    isSelected: _selectedCategoryId == category.id,
                    onTap: () => setState(() => _selectedCategoryId = category.id),
                    isDarkMode: isDarkMode,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: _filterType == 'all',
              onTap: () => setState(() => _filterType = 'all'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Veg',
              isSelected: _filterType == 'veg',
              onTap: () => setState(() => _filterType = 'veg'),
              isDarkMode: isDarkMode,
              iconWidget: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Non-Veg',
              isSelected: _filterType == 'nonVeg',
              onTap: () => setState(() => _filterType = 'nonVeg'),
              isDarkMode: isDarkMode,
              iconWidget: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Available',
              isSelected: _filterType == 'available',
              onTap: () => setState(() => _filterType = 'available'),
              isDarkMode: isDarkMode,
              iconData: Icons.check_circle_outline,
              iconColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsList(bool isDarkMode) {
    return StreamBuilder<List<MenuItemModel>>(
      stream: _businessService.watchMenuItems(
        widget.business.id,
        categoryId: _selectedCategoryId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading menu items',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final allItems = snapshot.data ?? [];
        final items = _filterItems(allItems);

        if (items.isEmpty) {
          return _buildEmptyState(isDarkMode, allItems.isEmpty);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _MenuItemCard(
              item: item,
              isDarkMode: isDarkMode,
              onTap: () => _editMenuItem(item),
              onToggleAvailability: () => _toggleAvailability(item),
              onDelete: () => _deleteMenuItem(item),
            );
          },
        );
      },
    );
  }

  List<MenuItemModel> _filterItems(List<MenuItemModel> items) {
    switch (_filterType) {
      case 'veg':
        return items.where((i) => i.foodType == FoodType.veg || i.foodType == FoodType.vegan).toList();
      case 'nonVeg':
        return items.where((i) => i.foodType == FoodType.nonVeg).toList();
      case 'available':
        return items.where((i) => i.isAvailable).toList();
      default:
        return items;
    }
  }

  Widget _buildEmptyState(bool isDarkMode, bool noItemsAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              noItemsAtAll ? Icons.restaurant_menu_rounded : Icons.search_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            noItemsAtAll ? 'No Menu Items Yet' : 'No Matching Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noItemsAtAll
                ? 'Add your first menu item to get started'
                : 'Try a different filter or category',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          if (noItemsAtAll) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addMenuItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Menu Item'),
            ),
          ],
        ],
      ),
    );
  }

  void _addMenuItem() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemFormScreen(
          businessId: widget.business.id,
          categoryId: _selectedCategoryId,
          onSaved: () {
            Navigator.pop(context);
            widget.onRefresh?.call();
          },
        ),
      ),
    );
  }

  void _editMenuItem(MenuItemModel item) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemFormScreen(
          businessId: widget.business.id,
          item: item,
          onSaved: () {
            Navigator.pop(context);
            widget.onRefresh?.call();
          },
        ),
      ),
    );
  }

  void _manageCategories() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuCategoryScreen(
          businessId: widget.business.id,
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(MenuItemModel item) async {
    HapticFeedback.lightImpact();
    final updatedItem = item.copyWith(isAvailable: !item.isAvailable);
    await _businessService.updateMenuItem(widget.business.id, item.id, updatedItem);
  }

  Future<void> _deleteMenuItem(MenuItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _businessService.deleteMenuItem(widget.business.id, item.id);
      widget.onRefresh?.call();
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final IconData? iconData;
  final Color? iconColor;
  final Widget? iconWidget;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.iconData,
    this.iconColor,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null) ...[
              iconWidget!,
              const SizedBox(width: 6),
            ] else if (iconData != null) ...[
              Icon(
                iconData,
                size: 14,
                color: isSelected ? const Color(0xFF00D67D) : iconColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.isDarkMode,
    required this.onTap,
    required this.onToggleAvailability,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food type indicator and image
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        image: item.image != null
                            ? DecorationImage(
                                image: NetworkImage(item.image!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item.image == null
                          ? const Icon(
                              Icons.fastfood,
                              color: Color(0xFF00D67D),
                              size: 32,
                            )
                          : null,
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getFoodTypeColor(item.foodType),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (!item.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Unavailable',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            item.formattedPrice,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D67D),
                            ),
                          ),
                          if (item.hasDiscount && item.formattedOriginalPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.formattedOriginalPrice!,
                              style: TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                                color: isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.discountPercent}% off',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.tags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onTap();
                        break;
                      case 'toggle':
                        onToggleAvailability();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            item.isAvailable ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(item.isAvailable ? 'Mark Unavailable' : 'Mark Available'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getFoodTypeColor(FoodType type) {
    switch (type) {
      case FoodType.veg:
      case FoodType.vegan:
        return Colors.green;
      case FoodType.nonVeg:
        return Colors.red;
      case FoodType.egg:
        return Colors.amber;
    }
  }
}
