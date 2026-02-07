import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../res/config/app_colors.dart';
import 'package:flutter/services.dart';

/// Reusable filter chip widget for business tabs.
/// Consolidates duplicate implementations from rooms_tab, menu_tab, products_tab.
class BusinessFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final bool showCheckmark;

  const BusinessFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.selectedColor,
    this.unselectedColor,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultSelectedColor = selectedColor ?? AppTheme.primaryGreen;
    final defaultUnselectedColor = unselectedColor ??
        (isDarkMode ? AppColors.textPrimaryDark.withValues(alpha: 0.08) : Colors.grey[100]!);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? defaultSelectedColor.withValues(alpha: 0.15)
              : defaultUnselectedColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: isSelected
                ? defaultSelectedColor.withValues(alpha: 0.5)
                : (isDarkMode ? AppColors.textPrimaryDark12 : AppColors.lightGrayTint),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconWidget != null) ...[
              iconWidget!,
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? defaultSelectedColor
                    : (iconColor ?? (isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600])),
              ),
              const SizedBox(width: 6),
            ],
            if (showCheckmark && isSelected) ...[
              Icon(
                Icons.check,
                size: 14,
                color: defaultSelectedColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? defaultSelectedColor
                    : (isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category chip with count badge
class BusinessCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final Color? selectedColor;

  const BusinessCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultSelectedColor = selectedColor ?? AppTheme.primaryGreen;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? defaultSelectedColor.withValues(alpha: 0.15)
              : (isDarkMode ? AppColors.textPrimaryDark.withValues(alpha: 0.08) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: isSelected
                ? defaultSelectedColor.withValues(alpha: 0.5)
                : (isDarkMode ? AppColors.textPrimaryDark12 : AppColors.lightGrayTint),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? defaultSelectedColor
                    : (isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? defaultSelectedColor.withValues(alpha: 0.2)
                      : (isDarkMode ? AppColors.textPrimaryDark12 : AppColors.lightGrayTint),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected
                        ? defaultSelectedColor
                        : (isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600]),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

/// Filter chip bar with horizontal scroll
class BusinessFilterBar extends StatelessWidget {
  final List<BusinessFilterChip> chips;
  final EdgeInsets? padding;

  const BusinessFilterBar({
    super.key,
    required this.chips,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chips
            .map((chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ))
            .toList(),
      ),
    );
  }
}

/// Status filter chip with color indicator
class BusinessStatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color statusColor;

  const BusinessStatusChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? statusColor.withValues(alpha: 0.15)
              : (isDarkMode ? AppColors.textPrimaryDark.withValues(alpha: 0.08) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: isSelected
                ? statusColor.withValues(alpha: 0.5)
                : (isDarkMode ? AppColors.textPrimaryDark12 : AppColors.lightGrayTint),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? statusColor
                    : (isDarkMode ? AppColors.textPrimaryDark70 : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
