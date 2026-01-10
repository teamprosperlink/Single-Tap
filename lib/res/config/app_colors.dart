import 'package:flutter/material.dart';

/// Centralized color configuration for the entire app.
/// Use these colors throughout the app instead of hardcoding color values.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  //    PRIMARY THEME COLORS
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color accent = Color(0xFFEC4899); // Pink
  static const Color tertiary = Color(0xFF06B6D4); // Cyan

  //    iOS SYSTEM COLORS
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosPurple = Color(0xFF5856D6);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosYellow = Color(0xFFFFCC00);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosTeal = Color(0xFF5AC8FA);
  static const Color iosIndigo = Color(0xFF5856D6);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosGrayDark = Color(0xFF1C1C1E);
  static const Color iosGrayLight = Color(0xFFE5E5EA);
  static const Color iosGraySecondary = Color(0xFF38383A);
  static const Color iosGrayTertiary = Color(0xFFE9E9EB);
  static const Color iosSystemGray = Color(0xFFF6F6F6);

  //    TRANSPARENT
  static const Color transparent = Colors.transparent;

  //    ACTION TYPE COLORS
  static const Color seeking = Color(0xFF60A5FA); // Light blue
  static const Color offering = Color(0xFF34D399); // Light green
  static const Color neutral = Colors.white;

  //    STATUS COLORS
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF0EA5E9); // Sky blue

  //    CONNECTION TYPE COLORS
  static const Color professional = Color(0xFF4A90E2); // Medium blue
  static const Color activityPartner = Color(0xFF00D67D); // Vibrant green
  static const Color eventCompanion = Color(0xFFFFB800); // Vibrant yellow
  static const Color friendship = Color(0xFFFF6B9D); // Vibrant pink
  static const Color dating = Color(0xFFFF4444); // Bright red

  //    VIBRANT ACCENT COLORS
  static const Color vibrantGreen = Color(0xFF00D67D);
  static const Color vibrantOrange = Color(0xFFFF6B35);
  static const Color vibrantPurple = Color(0xFF9B59B6);
  static const Color vibrantCyan = Color(0xFF00C9FF);
  static const Color vibrantPink = Color(0xFFFF6B9D);
  static const Color vibrantYellow = Color(0xFFFFB800);
  static const Color vibrantBlue = Color(0xFF4A90E2);

  // Gradient secondary colors
  static const Color gradientPinkDark = Color(0xFFC7365F);
  static const Color gradientBlueDark = Color(0xFF2E5BFF);
  static const Color gradientOrangeDark = Color(0xFFFF4E00);
  static const Color gradientPurpleDark = Color(0xFF6C3483);
  static const Color gradientGreenDark = Color(0xFF00A85E);

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
  static const Color backgroundLight = Color(0xFFF5F5F7);
  static const Color backgroundLightSecondary = Color(0xFFFFFFFF);
  static const Color chipSelectedBackground = Color(
    0xFF1E1B4B,
  ); // Dark indigo for selected chips
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

  //    SURFACE COLORS
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color cardLight = Color(0xFFFFFFFF);

  //    TEXT COLORS
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xB3FFFFFF); // 70% white
  static const Color textTertiaryDark = Color(0x8AFFFFFF); // 54% white
  static const Color textPrimaryLight = Colors.black;
  static const Color textSecondaryLight = Color(0xB3000000); // 70% black
  static const Color textTertiaryLight = Color(0x8A000000); // 54% black

  //    VOICE ORB STATE COLORS
  static const Color voiceListening = Color(0xFF8B5CF6); // Purple
  static const Color voiceProcessing = Color(0xFF0EA5E9); // Sky blue
  static const Color voiceSpeaking = Color(0xFFFFAA00); // Orange
  static const Color voiceConnected = Color(0xFF10B981); // Green

  //    RAINBOW/ANIMATION COLORS
  static const Color rainbowBlue = Color(0xFF2196F3);
  static const Color rainbowPurple = Color(0xFF9C27B0);
  static const Color rainbowPink = Color(0xFFFF69B4);
  static const Color rainbowMagenta = Color(0xFFE91E63);
  static const Color rainbowRed = Color(0xFFF44336);
  static const Color rainbowOrange = Color(0xFFFF9800);
  static const Color rainbowYellow = Color(0xFFFFEB3B);
  static const Color rainbowGreen = Color(0xFF4CAF50);
  static const Color rainbowTeal = Color(0xFF00BCD4);

  //    SPLASH/LOGIN COLORS
  static const Color splashDark1 = Color(0xFF1A1A2E);
  static const Color splashDark2 = Color(0xFF16213E);
  static const Color splashDark3 = Color(0xFF0F0F23);

  //    AURORA BACKGROUND COLORS
  static const Color auroraDark1 = Color(0xFF0F0F1E);
  static const Color auroraDark2 = Color(0xFF1A1A2E);
  static const Color auroraDark3 = Color(0xFF16213E);
  static const Color auroraLight1 = Color(0xFFF0F4FF);
  static const Color auroraLight2 = Color(0xFFE8F0FF);
  static const Color auroraLight3 = Color(0xFFD6E8FF);

  //    GRADIENTS

  /// Primary gradient (Indigo → Purple → Pink)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent],
  );

  /// Primary gradient without pink
  static const LinearGradient primaryGradientSimple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Splash screen gradient
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [splashDark1, splashDark2, splashDark3],
  );

  /// Aurora dark mode gradient
  static const LinearGradient auroraDarkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [auroraDark1, auroraDark2, auroraDark3],
  );

  /// Aurora light mode gradient
  static const LinearGradient auroraLightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [auroraLight1, auroraLight2, auroraLight3],
  );

  //    CATEGORY GRADIENTS

  static const List<Color> categoryAllGradient = [
    Color(0xFFBBBCFA), // Indigo
    Color(0xFFC5B5EC), // Purple
    Color(0xFFD89EBB), // Pink
  ];

  static const List<Color> categoryBuyingGradient = [
    Color(0xFFC3EEE0), // Emerald
    Color(0xFF8FBCC4), // Cyan
    Color(0xFF96B1DD), // Blue
  ];

  static const List<Color> categorySellGradient = [
    Color(0xFFDDC397), // Amber
    Color(0xFFE2BEA3), // Orange
    Color(0xFF835F5F), // Red
  ];

  static const List<Color> categoryServicesGradient = [
    Color(0xFFC1AAF7), // Purple
    Color(0xFFD490DF), // Fuchsia
    Color(0xFFDB7CAC), // Pink
  ];

  static const List<Color> categoryJobsGradient = [
    Color(0xFF7085A7), // Blue
    Color(0xFFA9A9D8), // Indigo
    Color(0xFF9A85CC), // Purple
  ];

  static const List<Color> categorySocialGradient = [
    Color(0xFFDDA9C3), // Pink
    Color(0xFFAF717B), // Rose
    Color(0xFFDAA48C), // Orange
  ];

  //    BADGE GRADIENTS

  static const List<Color> connectedBadgeGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  static const List<Color> sentBadgeGradient = [
    Color(0xFFF59E0B),
    Color(0xFFFBBB24),
  ];

  static const List<Color> violetGradient = [
    Color(0xFF7C3AED),
    Color(0xFF8B5CF6),
  ];

  static const List<Color> pinkGradient = [
    Color(0xFFEC4899),
    Color(0xFFF472B6),
  ];

  static const List<Color> indigoGradient = [
    Color(0xFF6366F1),
    Color(0xFF818CF8),
  ];

  static const List<Color> cyanGradient = [
    Color(0xFF06B6D4),
    Color(0xFF22D3EE),
  ];

  static const List<Color> orangeGradient = [
    Color(0xFFF97316),
    Color(0xFFFB923C),
  ];

  static const List<Color> yellowGradient = [
    Color(0xFFEAB308),
    Color(0xFFFACC15),
  ];

  static const List<Color> redGradient = [Color(0xFFEF4444), Color(0xFFF87171)];

  static const List<Color> emeraldGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  static const List<Color> skyGradient = [Color(0xFF0EA5E9), Color(0xFF38BDF8)];

  //    GLASSMORPHISM COLORS

  /// Glass background color (dark mode)
  static Color glassBackgroundDark({double alpha = 0.15}) =>
      Colors.white.withValues(alpha: alpha);

  /// Glass background color (light mode)
  static Color glassBackgroundLight({double alpha = 0.8}) =>
      Colors.white.withValues(alpha: alpha);

  /// Glass border color
  static Color glassBorder({double alpha = 0.2}) =>
      Colors.white.withValues(alpha: alpha);

  // ============ STANDARD BUTTON COLORS ============
  // Consistent glassmorphism button style used across the app (matching login button)

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

  static Color primaryShadow({double alpha = 0.4}) =>
      primary.withValues(alpha: alpha);

  static Color darkShadow({double alpha = 0.2}) =>
      Colors.black.withValues(alpha: alpha);

  /// Blue tint shadow/glow
  static Color blueShadow({double alpha = 0.15}) =>
      Colors.blue.withValues(alpha: alpha);

  /// Purple tint color
  static Color purpleTint({double alpha = 0.3}) =>
      Colors.purple.withValues(alpha: alpha);

  /// Blue tint color
  static Color blueTint({double alpha = 0.3}) =>
      Colors.blue.withValues(alpha: alpha);

  /// Orange tint color
  static Color orangeTint({double alpha = 0.3}) =>
      Colors.orange.withValues(alpha: alpha);

  /// Amber tint color
  static Color amberTint({double alpha = 0.3}) =>
      Colors.amber.withValues(alpha: alpha);

  /// Grey tint color
  static Color greyTint({double alpha = 0.3}) =>
      Colors.grey.withValues(alpha: alpha);

  /// Green tint color
  static Color greenTint({double alpha = 0.3}) =>
      Colors.green.withValues(alpha: alpha);

  /// Teal tint color
  static Color tealTint({double alpha = 0.3}) =>
      Colors.teal.withValues(alpha: alpha);

  /// Pink tint color
  static Color pinkTint({double alpha = 0.3}) =>
      Colors.pink.withValues(alpha: alpha);

  /// Cyan tint color
  static Color cyanTint({double alpha = 0.3}) =>
      Colors.cyan.withValues(alpha: alpha);

  /// Red tint color
  static Color redTint({double alpha = 0.3}) =>
      Colors.red.withValues(alpha: alpha);

  /// White with alpha
  static Color whiteAlpha({double alpha = 0.5}) =>
      Colors.white.withValues(alpha: alpha);

  /// Black with alpha
  static Color blackAlpha({double alpha = 0.5}) =>
      Colors.black.withValues(alpha: alpha);

  //    HELPER METHODS

  /// Get action type color
  static Color getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'seeking':
        return seeking;
      case 'offering':
        return offering;
      case 'neutral':
        return neutral;
      default:
        return neutral;
    }
  }

  /// Get category gradient colors
  static List<Color> getCategoryGradient(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'all':
        return categoryAllGradient;
      case 'buying':
        return categoryBuyingGradient;
      case 'selling':
        return categorySellGradient;
      case 'services':
        return categoryServicesGradient;
      case 'jobs':
        return categoryJobsGradient;
      case 'social':
        return categorySocialGradient;
      default:
        return [primary, secondary];
    }
  }

  /// Get connection type color
  static Color getConnectionTypeColor(String connectionType) {
    switch (connectionType.toLowerCase()) {
      case 'professional networking':
        return professional;
      case 'activity partner':
        return activityPartner;
      case 'event companion':
        return eventCompanion;
      case 'friendship':
        return friendship;
      case 'dating':
        return dating;
      default:
        return primary;
    }
  }

  /// Get voice orb state color
  static Color getVoiceOrbColor(String state) {
    switch (state.toLowerCase()) {
      case 'listening':
        return voiceListening;
      case 'processing':
        return voiceProcessing;
      case 'speaking':
        return voiceSpeaking;
      case 'connected':
        return voiceConnected;
      default:
        return voiceListening;
    }
  }

  /// Rainbow colors list for animations
  static const List<Color> rainbowColors = [
    rainbowBlue,
    rainbowPurple,
    rainbowPink,
    rainbowMagenta,
    rainbowRed,
    rainbowOrange,
    rainbowYellow,
    rainbowGreen,
    rainbowTeal,
  ];

  /// Vibrant interest tag colors
  static const List<Color> interestTagColors = [
    vibrantGreen,
    vibrantOrange,
    vibrantPurple,
    vibrantCyan,
    vibrantPink,
    vibrantYellow,
  ];
}
