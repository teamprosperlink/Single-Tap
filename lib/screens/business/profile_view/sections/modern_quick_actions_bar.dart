import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../utils/chat_navigation_helper.dart';

/// Modern Quick Actions Bar with Primary and Secondary Actions
/// Features:
/// - Prominent primary action with gradient background
/// - Icon-only secondary actions
/// - Floating card design with shadow
/// - Haptic feedback on press
/// - Smooth animations
class ModernQuickActionsBar extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBook;
  final VoidCallback? onOrder;
  final VoidCallback? onEnquire;

  const ModernQuickActionsBar({
    super.key,
    required this.business,
    required this.config,
    this.onBook,
    this.onOrder,
    this.onEnquire,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final actions = config.quickActions;

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Primary action (first action)
          if (actions.isNotEmpty)
            Expanded(
              flex: 2,
              child: _buildPrimaryAction(context, actions.first, isDarkMode),
            ),

          // Secondary actions (remaining actions)
          if (actions.length > 1) ...[
            const SizedBox(width: 12),
            ...actions.skip(1).map((action) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildSecondaryAction(context, action, isDarkMode),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryAction(
    BuildContext context,
    QuickAction action,
    bool isDarkMode,
  ) {
    final buttonColor = action.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          _handleAction(context, action);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [buttonColor, buttonColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: buttonColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(
    BuildContext context,
    QuickAction action,
    bool isDarkMode,
  ) {
    final buttonColor = action.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleAction(context, action);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: buttonColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: buttonColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(action.icon, color: buttonColor, size: 24),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, QuickAction action) {
    switch (action.type) {
      case QuickActionType.call:
        _makeCall();
        break;
      case QuickActionType.SingleTap:
        _sendSingleTap();
        break;
      case QuickActionType.message:
        _openInAppChat(context);
        break;
      case QuickActionType.directions:
        _openMap();
        break;
      case QuickActionType.book:
        if (onBook != null) {
          onBook!();
        } else {
          _showComingSoon(context);
        }
        break;
      case QuickActionType.order:
        if (onOrder != null) {
          onOrder!();
        } else {
          _showComingSoon(context);
        }
        break;
      case QuickActionType.enquire:
        if (onEnquire != null) {
          onEnquire!();
        } else {
          _showComingSoon(context);
        }
        break;
      case QuickActionType.website:
        _openWebsite();
        break;
      case QuickActionType.share:
        _showComingSoon(context);
        break;
      case QuickActionType.chat:
        _openInAppChat(context);
        break;
      case QuickActionType.map:
        _openMap();
        break;
    }
  }

  void _makeCall() async {
    if (business.contact.phone != null && business.contact.phone!.isNotEmpty) {
      final uri = Uri.parse('tel:${business.contact.phone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _sendSingleTap() async {
    if (business.contact.SingleTap != null &&
        business.contact.SingleTap!.isNotEmpty) {
      final uri = Uri.parse('https://wa.me/${business.contact.SingleTap}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (business.contact.phone != null &&
        business.contact.phone!.isNotEmpty) {
      final uri = Uri.parse('https://wa.me/${business.contact.phone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _openInAppChat(BuildContext context) async {
    ChatNavigationHelper.openBusinessChat(
      context,
      businessId: business.userId,
      businessName: business.businessName,
      businessPhoto: business.logo,
    );
  }

  void _openMap() async {
    if (business.address?.latitude != null &&
        business.address?.longitude != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${business.address?.latitude},${business.address?.longitude}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _openWebsite() async {
    if (business.contact.website != null &&
        business.contact.website!.isNotEmpty) {
      final uri = Uri.parse(business.contact.website!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }
}
