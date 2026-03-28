import 'package:flutter/material.dart';

/// Centralized color configuration for the entire app.
/// Use these colors throughout the app instead of hardcoding color values.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  //    PRIMARY THEME COLORS
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondary = Color(0xFF8B5CF6); // Purple

  //    iOS SYSTEM COLORS
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosPurple = Color(0xFF5856D6);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosYellow = Color(0xFFFFCC00);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosTeal = Color(0xFF5AC8FA);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosGrayDark = Color(0xFF1C1C1E);
  static const Color iosGrayLight = Color(0xFFE5E5EA);
  static const Color iosGraySecondary = Color(0xFF38383A);
  static const Color iosGrayTertiary = Color(0xFFE9E9EB);
  static const Color iosSystemGray = Color(0xFFF6F6F6);

  //    TRANSPARENT
  static const Color transparent = Colors.transparent;

  //    STATUS COLORS
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF0EA5E9); // Sky blue

  //    VIBRANT ACCENT COLORS
  static const Color vibrantGreen = Color(0xFF00D67D);

  // Light tint colors for backgrounds
  static const Color lightBlueTint = Color(0xFFE3F2FD);
  static const Color lightPurpleTint = Color(0xFFF3E5F5);
  static const Color lightGreenTint = Color(0xFFE8F5E9);
  static const Color lightOrangeTint = Color(0xFFFFF3E0);
  static const Color lightGrayTint = Color(0xFFF2F2F7);

  //    BACKGROUND COLORS
  static const Color backgroundDark = Color(0xFF000000);
  static const Color backgroundDarkSecondary = Color(0xFF1C1C1E);
  static const Color backgroundDarkTertiary = Color(0xFF2C2C2E);
  static const Color backgroundLightSecondary = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkCardSecondary = Color(0xFF2A2A2A);

  //    CHAT THEME GRADIENTS
  static const Map<String, List<Color>> chatThemeGradients = {
    'default': [Color(0xFF007AFF), Color(0xFF5856D6)], // iOS Blue-Purple
    'sunset': [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Red-Orange
    'ocean': [Color(0xFF00B4DB), Color(0xFF0083B0)], // Cyan-Blue
    'forest': [Color(0xFF56AB2F), Color(0xFFA8E063)], // Green gradient
    'berry': [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
    'midnight': [Color(0xFF232526), Color(0xFF414345)], // Dark gray
    'rose': [Color(0xFFFF0844), Color(0xFFFFB199)], // Pink-Peach
    'golden': [Color(0xFFF7971E), Color(0xFFFFD200)], // Orange-Gold
  };

  //    TEXT COLORS
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xB3FFFFFF); // 70% white
  static const Color textTertiaryDark = Color(0x8AFFFFFF); // 54% white
  static const Color textPrimaryLight = Colors.black;
  static const Color textSecondaryLight = Color(0xB3000000); // 70% black

  // Text with opacity variants (dark mode - white with alpha)
  static const Color textPrimaryDark70 = Color(0xB3FFFFFF); // 70% white
  static const Color textPrimaryDark54 = Color(0x8AFFFFFF); // 54% white
  static const Color textPrimaryDark38 = Color(0x61FFFFFF); // 38% white
  static const Color textPrimaryDark24 = Color(0x3DFFFFFF); // 24% white
  static const Color textPrimaryDark12 = Color(0x1FFFFFFF); // 12% white
  static const Color textPrimaryDark10 = Color(0x1AFFFFFF); // 10% white

  //    ACCENT COLORS
  static const Color purpleAccent = Color(0xFF8B5CF6);

  //    SPLASH/LOGIN COLORS
  static const Color splashDark1 = Color.fromRGBO(64, 64, 64, 1);
  static const Color splashDark2 = Color.fromRGBO(32, 32, 32, 1);
  static const Color splashDark3 = Color.fromRGBO(0, 0, 0, 1);

  //    GRADIENTS

  /// Splash screen gradient (matches home screen exactly)
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [splashDark1, splashDark3],
  );

  //    GLASSMORPHISM COLORS

  /// Glass background color (dark mode)
  static Color glassBackgroundDark({double alpha = 0.15}) =>
      Colors.white.withValues(alpha: alpha);

  /// Glass border color
  static Color glassBorder({double alpha = 0.2}) =>
      Colors.white.withValues(alpha: alpha);

  // ============ STANDARD BUTTON COLORS ============

  /// Standard button background color
  static Color buttonBackground({double alpha = 0.4}) =>
      Colors.blue.withValues(alpha: alpha);

  /// Standard button border color
  static Color buttonBorder({double alpha = 0.5}) =>
      Colors.blue.withValues(alpha: alpha);

  /// Standard button foreground color
  static const Color buttonForeground = Colors.white;

  /// Standard button border radius
  static const double buttonBorderRadius = 16.0;

  /// Dark overlay
  static Color darkOverlay({double alpha = 0.4}) =>
      Colors.black.withValues(alpha: alpha);

  /// Light overlay
  static Color lightOverlay({double alpha = 0.1}) =>
      Colors.white.withValues(alpha: alpha);

  //    SHADOW COLORS

  static Color darkShadow({double alpha = 0.2}) =>
      Colors.black.withValues(alpha: alpha);

  /// White with alpha
  static Color whiteAlpha({double alpha = 0.5}) =>
      Colors.white.withValues(alpha: alpha);

  /// Black with alpha
  static Color blackAlpha({double alpha = 0.5}) =>
      Colors.black.withValues(alpha: alpha);

  // ============ FIGMA DESIGN SYSTEM TOKENS (Dark Mode) ============

  // ── Primary Palette (Blue) ──
  static const Color primaryBrand = Color(0xFF016CFF);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryActive = Color(0xFF016CFF);
  static const Color primaryDisabled = Color(0x66016CFF);
  static const Color primary900 = Color(0xFF002D6B);
  static const Color primary800 = Color(0xFF013B8C);
  static const Color primary700 = Color(0xFF014DB5);
  static const Color primary600 = Color(0xFF0162E8);
  static const Color primary500 = Color(0xFF016CFF);
  static const Color primary400 = Color(0xFF3489FF);
  static const Color primary300 = Color(0xFF559DFF);
  static const Color primary200 = Color(0xFF8ABBFF);
  static const Color primary100 = Color(0xFFB0D1FF);
  static const Color primary50 = Color(0xFFE6F0FF);

  // ── Secondary Palette (Orange) ──
  static const Color secondaryBrand = Color(0xFFFFAB35);
  static const Color secondaryHover = Color(0xFFF59E0B);
  static const Color secondaryActive = Color(0xFFFFC05C);
  static const Color secondaryDisabled = Color(0x66FFAB35);
  static const Color secondary900 = Color(0xFF6B4816);
  static const Color secondary800 = Color(0xFF8C5E1D);
  static const Color secondary700 = Color(0xFFB57926);
  static const Color secondary600 = Color(0xFFE89C30);
  static const Color secondary500 = Color(0xFFFFAB35);
  static const Color secondary400 = Color(0xFFFFBC5D);
  static const Color secondary300 = Color(0xFFFFC778);
  static const Color secondary200 = Color(0xFFFFD8A2);
  static const Color secondary100 = Color(0xFFFFE5C0);
  static const Color secondary50 = Color(0xFFFFF7EB);

  // ── Background Tokens ──
  static const Color bgPrimary = Color(0xFF212121);
  static const Color bgCard = Color(0xFF1A1D21);
  static const Color bgOverlay = Color(0xFF242830);
  static const Color bgDisabled = Color(0xFF1E2228);
  static const Color bgOther = Color(0xFF161A1E);
  static const Color bgScreenHalfFill = Color(0x800F1114);
  static const Color bgCardBlack = Color(0xFF000000);

  // ── Text Tokens ──
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondaryGray = Color(0xFF717171);
  static const Color textDisabledGray = Color(0xFF9CA3AF);
  static const Color textButtonWhite = Color(0xFFFFFFFF);
  static const Color textPrimaryBlack = Color(0xFF212121);
  static const Color textSecondary2 = Color(0xFFC0C0C0);
  static const Color textButtonGrey = Color(0xFF898989);

  // ── Border Tokens ──
  static const Color borderDefault = Color(0xFF9CA3AB);
  static const Color borderSubtle = Color(0xFF1E2228);
  static const Color borderDivider = Color(0xFF3B424D);
  static const Color borderFocus = Color(0xFF3B8AFF);
  static const Color borderDisabled = Color(0xFF2D3239);
  static const Color borderDefaultLow = Color(0x809CA3AB);

  // ── Semantic Status Tokens ──
  static const Color semanticSuccess = Color(0xFF00AC40);
  static const Color semanticError = Color(0xFFD92D20);
  static const Color semanticErrorHover = Color(0xFFDC2626);
  static const Color semanticWarning = Color(0xFFFBBF24);
  static const Color semanticInfo = Color(0xFF60A5FA);

  // ── Card Fill Tokens ──
  static const Color cardWhiteFill = Color(0x0AFFFFFF);
  static const Color cardWhiteFill2 = Color(0x29FFFFFF);
}
