/// Business theme system - consistent colors, typography, and spacing
library;

import 'package:flutter/material.dart';

class BusinessTheme {
  // ============================================================================
  // PRIMARY COLORS BY ARCHETYPE
  // ============================================================================

  static const Color retailGreen = Color(0xFF10B981);
  static const Color menuAmber = Color(0xFFF59E0B);
  static const Color appointmentBlue = Color(0xFF3B82F6);
  static const Color hospitalityIndigo = Color(0xFF6366F1);
  static const Color portfolioPurple = Color(0xFF8B5CF6);

  // ============================================================================
  // SEMANTIC COLORS
  // ============================================================================

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ============================================================================
  // GREY SCALE (Tailwind-inspired)
  // ============================================================================

  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================

  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSize2XL = 20.0;
  static const double fontSize3XL = 24.0;
  static const double fontSize4XL = 30.0;
  static const double fontSize5XL = 36.0;

  // ============================================================================
  // SPACING SCALE
  // ============================================================================

  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 12.0;
  static const double spaceL = 16.0;
  static const double spaceXL = 20.0;
  static const double space2XL = 24.0;
  static const double space3XL = 32.0;
  static const double space4XL = 40.0;
  static const double space5XL = 48.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
  static const double radius2XL = 24.0;
  static const double radiusFull = 99.0;

  // ============================================================================
  // TEXT STYLES
  // ============================================================================

  static const TextStyle headingLarge = TextStyle(
    fontSize: fontSize3XL,
    fontWeight: FontWeight.bold,
    color: grey900,
    height: 1.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: fontSize2XL,
    fontWeight: FontWeight.bold,
    color: grey900,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: fontSizeXL,
    fontWeight: FontWeight.w600,
    color: grey800,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSizeL,
    color: grey700,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSizeM,
    color: grey600,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeS,
    color: grey500,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: fontSizeXS,
    color: grey400,
    height: 1.4,
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get archetype color by name
  static Color getArchetypeColor(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'retail':
        return retailGreen;
      case 'menu':
        return menuAmber;
      case 'appointment':
        return appointmentBlue;
      case 'hospitality':
        return hospitalityIndigo;
      case 'portfolio':
        return portfolioPurple;
      default:
        return appointmentBlue;
    }
  }

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get shadow for cards
  static List<BoxShadow> cardShadow({double elevation = 1}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05 * elevation),
        blurRadius: 10 * elevation,
        offset: Offset(0, 4 * elevation),
      ),
    ];
  }

  /// Get gradient for buttons/cards
  static LinearGradient getGradient(Color color) {
    return LinearGradient(
      colors: [
        color,
        Color.lerp(color, Colors.black, 0.1)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ============================================================================
  // THEME DATA
  // ============================================================================

  /// Get theme data for a specific archetype
  static ThemeData getThemeData(String archetype) {
    final primaryColor = getArchetypeColor(archetype);

    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: grey50,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: grey900,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusL)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceL,
            vertical: spaceM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
