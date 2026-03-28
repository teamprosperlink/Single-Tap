import 'package:flutter/material.dart';
import '../res/config/app_colors.dart';

/// Centralized theme constants for business UI screens.
class AppTheme {
  AppTheme._();

  // ============ PRIMARY DESIGN SYSTEM COLORS ============

  /// Primary action color (Blue) — buttons, CTAs, FABs, links
  static const Color primaryAction = AppColors.primaryBrand;

  /// Secondary accent color (Orange) — highlights, product badges
  static const Color secondaryAccent = AppColors.secondaryBrand;

  /// Success status (Green) — Live, Open, Available, Confirmed
  static const Color successStatus = AppColors.semanticSuccess;

  /// Warning status (Yellow) — stars, pending, reviews accent
  static const Color warningStatus = AppColors.semanticWarning;

  /// Error status (Red) — error, declined, delete
  static const Color errorStatus = AppColors.semanticError;

  /// Info status (Blue) — information, views
  static const Color infoStatus = AppColors.semanticInfo;

  // ============ QUICK ACTION COLORS ============

  static const Color quickActionCatalog = AppColors.primaryBrand;
  static const Color quickActionBookings = AppColors.secondaryBrand;
  static const Color quickActionReviews = AppColors.semanticWarning;
  static const Color quickActionViews = AppColors.semanticInfo;

  // ============ LEGACY ALIASES (for non-business code) ============

  static const Color primaryGreen = primaryAction;
  static const Color successGreen = successStatus;
  static const Color errorRed = AppColors.semanticError;
  static const Color infoBlue = AppColors.semanticInfo;
  static const Color purpleAccent = Color(0xFF8B5CF6);

  // Status colors
  static const Color statusSuccess = successStatus;
  static const Color statusWarning = warningStatus;
  static const Color statusError = errorStatus;
  static const Color warningOrange = AppColors.secondaryBrand;

  // Card colors
  static const Color darkCard = AppColors.bgCard;
  static const Color lightCard = Color(0xFFFFFFFF);

  // ============ GRADIENTS ============

  /// Cover image placeholder gradient (dark palette)
  static const LinearGradient coverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F1114), Color(0xFF161A1E), Color(0xFF1A1D21)],
  );

  // ============ DYNAMIC COLORS ============

  static Color cardColor(bool isDarkMode) =>
      isDarkMode ? darkCard : lightCard;

  static Color backgroundColor(bool isDarkMode) =>
      isDarkMode ? AppColors.bgCardBlack : const Color(0xFFF5F5F7);

  static Color textPrimary(bool isDarkMode) =>
      isDarkMode ? AppColors.textWhite : AppColors.textPrimaryBlack;

  static Color darkText(bool isDarkMode) =>
      isDarkMode ? AppColors.textWhite : AppColors.textPrimaryBlack;

  static Color secondaryText(bool isDarkMode) =>
      isDarkMode ? AppColors.textSecondary2 : Colors.black.withValues(alpha: 0.6);

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
