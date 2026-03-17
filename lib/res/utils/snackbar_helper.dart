import 'package:flutter/material.dart';

/// Global SnackBar helper with consistent glassmorphism styling
/// Matches login screen snackbar design
class SnackBarHelper {
  SnackBarHelper._();

  /// Show error snackbar with red glassmorphic gradient
  static void showError(BuildContext context, String message) {
    _show(context, message, Icons.error_outline, Colors.redAccent);
  }

  /// Show success snackbar with green glassmorphic gradient
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Icons.check_circle, Colors.greenAccent);
  }

  /// Show warning snackbar with orange glassmorphic gradient
  static void showWarning(BuildContext context, String message) {
    _show(context, message, Icons.warning_amber_rounded, Colors.orangeAccent);
  }

  /// Show info snackbar with blue glassmorphic gradient
  static void showInfo(BuildContext context, String message) {
    _show(context, message, Icons.info_outline, Colors.blueAccent);
  }

  static void _show(BuildContext context, String message, IconData icon, Color accentColor) {
    // Use root ScaffoldMessenger to avoid Hero conflicts with nested Scaffolds
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      _buildSnackBar(message: message, icon: icon, accentColor: accentColor),
    );
  }

  static int _snackBarCounter = 0;

  static SnackBar _buildSnackBar({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    _snackBarCounter++;
    final tag = 'snackbar_${_snackBarCounter}_${DateTime.now().microsecondsSinceEpoch}';
    return SnackBar(
      key: ValueKey(tag),
      content: Container(
        key: ValueKey('content_$tag'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              accentColor.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      duration: const Duration(seconds: 3),
    );
  }
}
