import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Reusable components for business profile view sections.
class BusinessProfileComponents {
  BusinessProfileComponents._();

  /// Glass-morphism card with blur effect.
  static Widget glassCard({
    required bool isDarkMode,
    double borderRadius = 12.0,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  /// Verified badge icon.
  static Widget verifiedBadge({double size = 16}) {
    return Icon(Icons.verified, color: Colors.blue, size: size);
  }

  /// Star rating widget with review count.
  static Widget ratingWidget({
    required num rating,
    int reviewCount = 0,
    required bool isDarkMode,
    double size = 14,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: size),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size - 2,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(isDarkMode),
          ),
        ),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: size - 4,
              color: AppTheme.secondaryText(isDarkMode),
            ),
          ),
        ],
      ],
    );
  }

  /// Colored status chip with optional icon.
  static Widget statusChip({
    required String label,
    required Color color,
    required bool isDarkMode,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern section header with icon, title, optional count and action.
  static Widget modernSectionHeader({
    required String title,
    required bool isDarkMode,
    required IconData icon,
    int? count,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(isDarkMode),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  /// Highlight chip with gradient background.
  static Widget highlightChip({
    required String label,
    required IconData icon,
    LinearGradient? gradient,
  }) {
    final grad = gradient ??
        LinearGradient(colors: [
          AppTheme.primaryGreen,
          AppTheme.primaryGreen.withValues(alpha: 0.7),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
