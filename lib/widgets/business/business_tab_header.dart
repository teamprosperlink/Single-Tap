import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable header widget for business tabs.
/// Consolidates duplicate header implementations across business screens.
class BusinessTabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTrailingPressed;
  final IconData? trailingIcon;
  final String? trailingText;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const BusinessTabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTrailingPressed,
    this.trailingIcon,
    this.trailingText,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = iconColor ?? const Color(0xFF00D67D);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Back button (optional)
          if (showBackButton) ...[
            IconButton(
              onPressed: onBackPressed ?? () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Icon
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: defaultIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: defaultIconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Trailing widget
          if (trailing != null)
            trailing!
          else if (onTrailingPressed != null)
            _buildTrailingButton(context, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildTrailingButton(BuildContext context, bool isDarkMode) {
    if (trailingText != null) {
      return TextButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTrailingPressed!();
        },
        icon: Icon(
          trailingIcon ?? Icons.settings,
          size: 18,
          color: const Color(0xFF00D67D),
        ),
        label: Text(
          trailingText!,
          style: const TextStyle(
            color: Color(0xFF00D67D),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTrailingPressed!();
      },
      icon: Icon(
        trailingIcon ?? Icons.more_vert,
        color: isDarkMode ? Colors.white70 : Colors.grey[600],
      ),
    );
  }
}

/// Section header for content sections within tabs
class BusinessSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final int? count;

  const BusinessSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionPressed,
    this.actionIcon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Title with optional count
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Color(0xFF00D67D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Action button
          if (actionText != null || onActionPressed != null)
            TextButton.icon(
              onPressed: onActionPressed,
              icon: Icon(
                actionIcon ?? Icons.chevron_right,
                size: 18,
                color: const Color(0xFF00D67D),
              ),
              label: Text(
                actionText ?? 'See All',
                style: const TextStyle(
                  color: Color(0xFF00D67D),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Business logo placeholder widget
class BusinessLogoPlaceholder extends StatelessWidget {
  final String? businessName;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final double fontSize;

  const BusinessLogoPlaceholder({
    super.key,
    this.businessName,
    this.size = 48,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!);
    final txtColor = textColor ?? const Color(0xFF00D67D);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: Text(
          _getInitials(businessName ?? 'B'),
          style: TextStyle(
            color: txtColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'B';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

/// Search bar for business tabs
class BusinessSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const BusinessSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white38 : Colors.grey[500],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
          suffixIcon: controller?.text.isNotEmpty == true
              ? IconButton(
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                  },
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
