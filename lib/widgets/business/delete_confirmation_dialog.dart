import 'package:flutter/material.dart';

/// Reusable delete confirmation dialog for business module
class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String itemName;
  final String? message;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;

  const DeleteConfirmationDialog({
    super.key,
    this.title = 'Delete Item?',
    required this.itemName,
    this.message,
    required this.onConfirm,
    this.onCancel,
    this.confirmText = 'Delete',
    this.cancelText = 'Cancel',
    this.confirmColor = Colors.red,
  });

  /// Show the delete confirmation dialog
  static Future<bool?> show({
    required BuildContext context,
    String title = 'Delete Item?',
    required String itemName,
    String? message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: title,
        itemName: itemName,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
  }

  /// Convenience factory for deleting a product
  static Future<bool?> showForProduct(BuildContext context, String productName) {
    return show(
      context: context,
      title: 'Delete Product?',
      itemName: productName,
      message: 'This action cannot be undone.',
    );
  }

  /// Convenience factory for deleting a menu item
  static Future<bool?> showForMenuItem(BuildContext context, String itemName) {
    return show(
      context: context,
      title: 'Delete Menu Item?',
      itemName: itemName,
      message: 'This action cannot be undone.',
    );
  }

  /// Convenience factory for deleting a room
  static Future<bool?> showForRoom(BuildContext context, String roomName) {
    return show(
      context: context,
      title: 'Delete Room?',
      itemName: roomName,
      message: 'This action cannot be undone.',
    );
  }

  /// Convenience factory for deleting a service
  static Future<bool?> showForService(BuildContext context, String serviceName) {
    return show(
      context: context,
      title: 'Delete Service?',
      itemName: serviceName,
      message: 'This action cannot be undone.',
    );
  }

  /// Convenience factory for deleting a post
  static Future<bool?> showForPost(BuildContext context, String postTitle) {
    return show(
      context: context,
      title: 'Delete Post?',
      itemName: postTitle,
      message: 'This action cannot be undone.',
    );
  }

  /// Convenience factory for deleting a category
  static Future<bool?> showForCategory(BuildContext context, String categoryName) {
    return show(
      context: context,
      title: 'Delete Category?',
      itemName: categoryName,
      message: 'All items in this category will also be deleted. This action cannot be undone.',
    );
  }

  /// Convenience factory for cancelling an appointment
  static Future<bool?> showForAppointment(BuildContext context, String appointmentInfo) {
    return show(
      context: context,
      title: 'Cancel Appointment?',
      itemName: appointmentInfo,
      message: 'The customer will be notified of the cancellation.',
      confirmText: 'Cancel Appointment',
      confirmColor: Colors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.delete_outline,
              color: confirmColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              children: [
                const TextSpan(text: 'Are you sure you want to delete '),
                TextSpan(
                  text: '"$itemName"',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
