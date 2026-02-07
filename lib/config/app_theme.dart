import 'package:flutter/material.dart';

/// Centralized theme constants for business UI screens.
class AppTheme {
  AppTheme._();

  // ============ COLORS ============

  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);

  // Archetype accent colors
  static const Color retailGreen = Color(0xFF22C55E);
  static const Color menuAmber = Color(0xFFF59E0B);
  static const Color appointmentBlue = Color(0xFF3B82F6);
  static const Color hospitalityTeal = Color(0xFF14B8A6);
  static const Color portfolioPurple = Color(0xFF8B5CF6);

  // Status colors
  static const Color statusSuccess = Color(0xFF22C55E);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color hospitalityIndigo = Color(0xFF6366F1);

  // Card colors
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ============ DYNAMIC COLORS ============

  static Color cardColor(bool isDarkMode) =>
      isDarkMode ? darkCard : lightCard;

  static Color backgroundColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F7);

  static Color textPrimary(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  static Color darkText(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  static Color secondaryText(bool isDarkMode) =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.6);

  // ============ SPACING ============

  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;

  // ============ BORDER RADIUS ============

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // ============ FONT SIZES ============

  static const double fontSmall = 12.0;
  static const double fontRegular = 14.0;
  static const double fontMedium = 14.0;
  static const double fontBody = 14.0;
  static const double fontSubtitle = 16.0;
  static const double fontLarge = 18.0;
  static const double fontSizeLarge = 18.0;
  static const double fontXLarge = 20.0;
  static const double fontTitle = 20.0;
  static const double fontHeading = 24.0;

  // ============ ICON SIZES ============

  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
}
