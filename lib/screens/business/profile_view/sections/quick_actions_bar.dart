import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/business_model.dart';
import '../../../../models/user_profile.dart';
import '../../../../config/category_profile_config.dart';
import '../../../chat/enhanced_chat_screen.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';

/// Horizontal bar of quick action buttons (Call, Book, Order, etc.)
class QuickActionsBar extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBook;
  final VoidCallback? onOrder;
  final VoidCallback? onEnquire;

  const QuickActionsBar({
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: config.quickActions.map((action) {
          final isFirst = config.quickActions.indexOf(action) == 0;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: isFirst ? 0 : 6,
                right: isFirst ? 6 : 0,
              ),
              child: _ActionButton(
                action: action,
                business: business,
                config: config,
                isPrimary: action.isPrimary,
                onBook: onBook,
                onOrder: onOrder,
                onEnquire: onEnquire,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final QuickAction action;
  final BusinessModel business;
  final CategoryProfileConfig config;
  final bool isPrimary;
  final VoidCallback? onBook;
  final VoidCallback? onOrder;
  final VoidCallback? onEnquire;

  const _ActionButton({
    required this.action,
    required this.business,
    required this.config,
    this.isPrimary = false,
    this.onBook,
    this.onOrder,
    this.onEnquire,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = action.color;

    if (isPrimary) {
      return ElevatedButton(
        onPressed: () => _handleAction(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: AppColors.textPrimaryDark,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                action.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton(
      onPressed: () => _handleAction(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.secondaryText(isDarkMode),
        side: BorderSide(
          color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 18),
          const SizedBox(height: 2),
          Text(
            action.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context) {
    HapticFeedback.lightImpact();

    switch (action.type) {
      case QuickActionType.call:
        _makeCall(context);
        break;
      case QuickActionType.SingleTap:
        _openSingleTap(context);
        break;
      case QuickActionType.directions:
        _openDirections(context);
        break;
      case QuickActionType.book:
        if (onBook != null) {
          onBook!();
        } else {
          _showBookingSheet(context);
        }
        break;
      case QuickActionType.order:
        if (onOrder != null) {
          onOrder!();
        } else {
          _showOrderSheet(context);
        }
        break;
      case QuickActionType.enquire:
        if (onEnquire != null) {
          onEnquire!();
        } else {
          _showEnquirySheet(context);
        }
        break;
      case QuickActionType.share:
        _shareProfile(context);
        break;
      case QuickActionType.website:
        _openWebsite(context);
        break;
      case QuickActionType.message:
        _openMessage(context);
        break;
      case QuickActionType.chat:
        _openMessage(context);
        break;
      case QuickActionType.map:
        _openDirections(context);
        break;
    }
  }

  Future<void> _makeCall(BuildContext context) async {
    final phone = business.contact.phone;
    if (phone == null || phone.isEmpty) {
      _showError(context, 'No phone number available');
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _showError(context, 'Could not make call');
      }
    }
  }

  Future<void> _openSingleTap(BuildContext context) async {
    final SingleTap = business.contact.SingleTap ?? business.contact.phone;
    if (SingleTap == null || SingleTap.isEmpty) {
      _showError(context, 'No SingleTap number available');
      return;
    }

    // Remove any non-digit characters
    final cleanNumber = SingleTap.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        _showError(context, 'Could not open SingleTap');
      }
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    final address = business.address;
    if (address == null) {
      _showError(context, 'No address available');
      return;
    }

    Uri uri;
    if (address.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${address.latitude},${address.longitude}',
      );
    } else {
      final query = Uri.encodeComponent(address.formattedAddress);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        _showError(context, 'Could not open maps');
      }
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final website = business.contact.website;
    if (website == null || website.isEmpty) {
      _showError(context, 'No website available');
      return;
    }

    var url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        _showError(context, 'Could not open website');
      }
    }
  }

  void _showBookingSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.iosGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: config.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Book with ${business.businessName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you\'d like to book',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openMessage(context);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send Booking Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _makeCall(context);
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call to Book'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: config.primaryColor,
                    side: BorderSide(color: config.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.iosGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                Icons.shopping_bag_rounded,
                size: 48,
                color: config.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Order from ${business.businessName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you\'d like to order',
                style: TextStyle(color: AppTheme.secondaryText(isDarkMode)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openMessage(context);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send Order via Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _makeCall(context);
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call to Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: config.primaryColor,
                    side: BorderSide(color: config.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnquirySheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.iosGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Contact ${business.businessName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              if (business.contact.phone != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: config.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone, color: config.primaryColor),
                  ),
                  title: const Text('Call'),
                  subtitle: Text(business.contact.phone!),
                  onTap: () {
                    Navigator.pop(context);
                    _makeCall(context);
                  },
                ),
              if (business.contact.SingleTap != null ||
                  business.contact.phone != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.green),
                  ),
                  title: const Text('SingleTap'),
                  subtitle: Text(
                    business.contact.SingleTap ?? business.contact.phone!,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openSingleTap(context);
                  },
                ),
              if (business.contact.email != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.email, color: Colors.blue),
                  ),
                  title: const Text('Email'),
                  subtitle: Text(business.contact.email!),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('mailto:${business.contact.email}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMessage(BuildContext context) {
    // Navigate to chat screen with business owner
    final otherUser = UserProfile(
      uid: business.userId,
      name: business.businessName,
      email: business.contact.email ?? '',
      profileImageUrl: business.logo,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(otherUser: otherUser),
      ),
    );
  }

  void _shareProfile(BuildContext context) {
    Share.share(
      'Check out ${business.businessName}!\n\n'
      '${business.description ?? ""}\n\n'
      'Location: ${business.address?.formattedAddress ?? "Address not available"}\n'
      'Rating: ${business.rating} ⭐',
      subject: business.businessName,
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
