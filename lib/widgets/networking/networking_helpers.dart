import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared helper/utility functions for networking screens.
class NetworkingHelpers {
  NetworkingHelpers._();

  /// Format a DateTime to a human-readable "time ago" string.
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  /// Calculate distance in km between two lat/lng points (Haversine formula).
  static double calcDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = (sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * pi / 180) *
                cos(lat2 * pi / 180) *
                sin(dLon / 2) *
                sin(dLon / 2))
        .clamp(0.0, 1.0);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Resolve user display name from Firestore data, checking multiple fields.
  static String? resolveUserName(Map<String, dynamic> data) {
    final nameRaw = data['name'];
    final name = nameRaw is String ? nameRaw : nameRaw?.toString();
    if (name != null &&
        name.isNotEmpty &&
        name != 'User' &&
        name != 'Unknown') {
      return name;
    }
    final displayRaw = data['displayName'];
    final displayName = displayRaw is String ? displayRaw : displayRaw?.toString();
    if (displayName != null &&
        displayName.isNotEmpty &&
        displayName != 'User' &&
        displayName != 'Unknown') {
      return displayName;
    }
    final phoneRaw = data['phone'];
    final phone = phoneRaw is String ? phoneRaw : phoneRaw?.toString();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return null;
  }

  /// Resolve occupation from multiple possible Firestore fields.
  static String? resolveOccupation(Map<String, dynamic> data) {
    final occRaw = data['occupation'];
    final occupation = occRaw is String ? occRaw : occRaw?.toString();
    if (occupation != null && occupation.isNotEmpty) return occupation;

    final profRaw = data['profession'];
    final profession = profRaw is String ? profRaw : profRaw?.toString();
    if (profession != null && profession.isNotEmpty) return profession;

    final bizProfileRaw = data['businessProfile'];
    if (bizProfileRaw is Map<String, dynamic>) {
      final labelRaw = bizProfileRaw['softLabel'];
      final label = labelRaw is String ? labelRaw : labelRaw?.toString();
      if (label != null && label.isNotEmpty) return label;
    }

    final subcatRaw = data['networkingSubcategory'];
    final subcat = subcatRaw is String ? subcatRaw : subcatRaw?.toString();
    if (subcat != null && subcat.isNotEmpty) return subcat;
    return null;
  }

  /// Calculate age from dateOfBirth (supports Timestamp and String).
  static int? calcAgeFromDob(dynamic dob) {
    if (dob == null) return null;
    try {
      final DateTime birthDate;
      if (dob is Timestamp) {
        birthDate = dob.toDate();
      } else if (dob is String && dob.isNotEmpty) {
        birthDate = DateTime.parse(dob);
      } else {
        return null;
      }
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  /// Get a distinct avatar gradient pair based on the user's name hash.
  static List<Color> getAvatarGradient(String name) {
    final hash = name.hashCode.abs() % 5;
    switch (hash) {
      case 0:
        return const [Color(0xFFFF6B9D), Color(0xFFC7365F)]; // Pink
      case 1:
        return const [Color(0xFF4A90E2), Color(0xFF2E5BFF)]; // Blue
      case 2:
        return const [Color(0xFFFF6B35), Color(0xFFFF4E00)]; // Orange
      case 3:
        return const [Color(0xFF9B59B6), Color(0xFF6C3483)]; // Purple
      default:
        return const [Color(0xFF00D67D), Color(0xFF00A85E)]; // Green
    }
  }

  /// Show a glassmorphic success SnackBar (matches login screen design).
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        _buildGlassSnackBar(
          message: message,
          icon: Icons.check_circle,
          accentColor: Colors.greenAccent,
        ),
      );
  }

  /// Show a glassmorphic error SnackBar (matches login screen design).
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        _buildGlassSnackBar(
          message: message,
          icon: Icons.error_outline,
          accentColor: Colors.redAccent,
        ),
      );
  }

  /// Show a glassmorphic warning SnackBar (matches login screen design).
  static void showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        _buildGlassSnackBar(
          message: message,
          icon: Icons.warning_amber_rounded,
          accentColor: Colors.orangeAccent,
        ),
      );
  }

  /// Backward-compatible wrapper — routes to success or error glassmorphic style.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
  }) {
    if (isError) {
      showErrorSnackBar(context, message);
    } else {
      showSuccessSnackBar(context, message);
    }
  }

  /// Build a glassmorphic SnackBar with blur + gradient (login screen style).
  static SnackBar _buildGlassSnackBar({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    return SnackBar(
      clipBehavior: Clip.none,
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
                Icon(icon, color: accentColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      fontFamily: 'Poppins',
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
    );
  }
}
