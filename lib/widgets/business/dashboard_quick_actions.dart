import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supper/models/business_dashboard_config.dart';
import 'package:supper/res/config/app_colors.dart';

/// Dashboard quick actions grid widget (2x2 grid)
/// Displays 4 action buttons for common business operations
class DashboardQuickActions extends StatelessWidget {
  final List<QuickAction> actions;
  final Function(String route) onActionTap;
  final bool isDarkMode;

  const DashboardQuickActions({
    super.key,
    required this.actions,
    required this.onActionTap,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Take only first 4 actions for 2x2 grid
    final displayActions = actions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: displayActions.map((action) => _buildActionButton(action)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(QuickAction action) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onActionTap(action.route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode
              ? action.color.withValues(alpha: 0.15)
              : action.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: action.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // Label and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
