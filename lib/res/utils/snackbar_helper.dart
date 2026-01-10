import 'dart:ui';
import 'package:flutter/material.dart';

/// Global SnackBar helper with consistent glassmorphism styling
/// Matches login screen snackbar design
class SnackBarHelper {
  SnackBarHelper._();

  /// Show error snackbar with red glassmorphic gradient
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.error_outline,
        accentColor: Colors.redAccent,
      ),
    );
  }

  /// Show success snackbar with green glassmorphic gradient
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.check_circle,
        accentColor: Colors.greenAccent,
      ),
    );
  }

  /// Show warning snackbar with orange glassmorphic gradient
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.warning_amber_rounded,
        accentColor: Colors.orangeAccent,
      ),
    );
  }

  /// Show info snackbar with blue glassmorphic gradient
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.info_outline,
        accentColor: Colors.blueAccent,
      ),
    );
  }

  static SnackBar _buildSnackBar({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    return SnackBar(
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
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
                Icon(
                  icon,
                  color: accentColor,
                  size: 28,
                ),
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
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      duration: const Duration(seconds: 3),
    );
  }
}
