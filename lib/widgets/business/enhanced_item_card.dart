import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/app_components.dart';

/// Enhanced item card with modern UI for menu items, products, rooms, etc.
/// Provides consistent, beautiful design across all business categories
class EnhancedItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? price;
  final String? imageUrl;
  final bool isAvailable;
  final Widget? badge;
  final Widget? trailingWidget;
  final VoidCallback onTap;
  final VoidCallback? onToggleAvailability;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color? accentColor;

  const EnhancedItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.price,
    this.imageUrl,
    this.isAvailable = true,
    this.badge,
    this.trailingWidget,
    required this.onTap,
    this.onToggleAvailability,
    this.onEdit,
    this.onDelete,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppTheme.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                // Image/Icon Section
                _buildImageSection(isDarkMode, color),
                const SizedBox(width: AppTheme.spacing12),

                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: AppTheme.fontSubtitle,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText(isDarkMode),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            badge!,
                          ],
                        ],
                      ),

                      // Subtitle
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: AppTheme.fontRegular,
                            color: AppTheme.secondaryText(isDarkMode),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Price and Status Row
                      Row(
                        children: [
                          if (price != null) ...[
                            Text(
                              price!,
                              style: TextStyle(
                                fontSize: AppTheme.fontSubtitle,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const Spacer(),
                          ],

                          // Availability Status
                          AppComponents.statusBadge(
                            text: isAvailable ? 'Available' : 'Unavailable',
                            color: isAvailable
                                ? AppTheme.successGreen
                                : AppTheme.errorRed,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions Section
                if (onToggleAvailability != null ||
                    onEdit != null ||
                    onDelete != null) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.secondaryText(isDarkMode),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    itemBuilder: (context) => [
                      if (onToggleAvailability != null)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                isAvailable
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: AppTheme.iconMedium,
                                color: AppTheme.secondaryText(isDarkMode),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isAvailable
                                    ? 'Mark Unavailable'
                                    : 'Mark Available',
                              ),
                            ],
                          ),
                        ),
                      if (onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: AppTheme.iconMedium,
                                color: AppTheme.infoBlue,
                              ),
                              const SizedBox(width: 12),
                              const Text('Edit'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: AppTheme.iconMedium,
                                color: AppTheme.errorRed,
                              ),
                              const SizedBox(width: 12),
                              const Text('Delete'),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'toggle':
                          onToggleAvailability?.call();
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                  ),
                ] else if (trailingWidget != null)
                  trailingWidget!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDarkMode, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Icon(
              Icons.image_outlined,
              color: color.withValues(alpha: 0.5),
              size: 32,
            )
          : null,
    );
  }
}

/// Enhanced stats grid for dashboard overview
class EnhancedStatsGrid extends StatelessWidget {
  final List<StatItem> stats;
  final bool isDarkMode;

  const EnhancedStatsGrid({
    super.key,
    required this.stats,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spacing12,
        mainAxisSpacing: AppTheme.spacing12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return AppComponents.statsCard(
          icon: stat.icon,
          label: stat.label,
          value: stat.value,
          color: stat.color,
          isDarkMode: isDarkMode,
        );
      },
    );
  }
}

class StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Enhanced filter chip bar
class EnhancedFilterBar extends StatelessWidget {
  final List<FilterOption> options;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final bool isDarkMode;

  const EnhancedFilterBar({
    super.key,
    required this.options,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppTheme.spacing8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = selectedFilter == option.value;

          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.secondaryText(isDarkMode),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.darkText(isDarkMode),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (option.count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      option.count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onFilterChanged(option.value),
            backgroundColor: AppTheme.cardColor(isDarkMode),
            selectedColor: option.color ?? AppTheme.primaryGreen,
            side: BorderSide(
              color: isSelected
                  ? (option.color ?? AppTheme.primaryGreen)
                  : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          );
        },
      ),
    );
  }
}

class FilterOption {
  final String value;
  final String label;
  final IconData? icon;
  final int? count;
  final Color? color;

  FilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.color,
  });
}

/// Enhanced category tab bar
class EnhancedCategoryTabs extends StatelessWidget {
  final List<CategoryTab> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategoryChanged;
  final bool isDarkMode;

  const EnhancedCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1, // +1 for "All" option
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppTheme.spacing8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" tab
            final isSelected = selectedCategoryId == null;
            return _buildCategoryTab(
              label: 'All',
              isSelected: isSelected,
              onTap: () => onCategoryChanged(null),
            );
          }

          final category = categories[index - 1];
          final isSelected = selectedCategoryId == category.id;

          return _buildCategoryTab(
            label: category.name,
            isSelected: isSelected,
            onTap: () => onCategoryChanged(category.id),
            color: category.color,
          );
        },
      ),
    );
  }

  Widget _buildCategoryTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppTheme.primaryGreen)
              : AppTheme.cardColor(isDarkMode),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppTheme.primaryGreen)
                : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppTheme.darkText(isDarkMode),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: AppTheme.fontMedium,
          ),
        ),
      ),
    );
  }
}

class CategoryTab {
  final String id;
  final String name;
  final Color? color;

  CategoryTab({
    required this.id,
    required this.name,
    this.color,
  });
}
