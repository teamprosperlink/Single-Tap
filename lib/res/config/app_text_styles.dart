import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized text style configuration for the entire app.
/// Use these text styles throughout the app instead of hardcoding TextStyle values.
class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  // DISPLAY STYLES (Large Headings 28-34px)

  /// Display Large - 34px, Bold
  /// Use for: Splash screen titles, hero text
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.5,
    color: AppColors.textPrimaryDark,
  );

  /// Display Large Light - 34px, Bold, Light mode
  static const TextStyle displayLargeLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.5,
    color: AppColors.textPrimaryLight,
  );

  /// Display Medium - 28px, w700
  /// Use for: Main screen titles, modal headers
  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    color: AppColors.textPrimaryDark,
  );

  /// Display Medium Light - 28px, w700, Light mode
  static const TextStyle displayMediumLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    color: AppColors.textPrimaryLight,
  );

  /// Display Small - 24px, Bold
  /// Use for: Section headers, card titles
  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Display Small Light - 24px, Bold, Light mode
  static const TextStyle displaySmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  // HEADLINE STYLES (20-22px)

  /// Headline Large - 22px, w600
  /// Use for: Screen titles, important headings
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Headline Large Light - 22px, w600, Light mode
  static const TextStyle headlineLargeLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Headline Medium - 20px, Bold
  /// Use for: AppBar titles, dialog headers
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Headline Medium Light - 20px, Bold, Light mode
  static const TextStyle headlineMediumLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Headline Small - 20px, w600
  /// Use for: Subheadings, card headers
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Headline Small Light - 20px, w600, Light mode
  static const TextStyle headlineSmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  // TITLE STYLES (17-18px)

  /// Title Large - 18px, Bold
  /// Use for: List item titles, section headers
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Title Large Light - 18px, Bold, Light mode
  static const TextStyle titleLargeLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Title Medium - 17px, w600
  /// Use for: Card titles, form section headers
  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Title Medium Light - 17px, w600, Light mode
  static const TextStyle titleMediumLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Title Small - 16px, w600
  /// Use for: Emphasized labels, small titles
  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Title Small Light - 16px, w600, Light mode
  static const TextStyle titleSmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  // BODY STYLES (14-16px)

  /// Body Large - 16px, Normal
  /// Use for: Main content text, descriptions
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Body Large Light - 16px, Normal, Light mode
  static const TextStyle bodyLargeLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Body Large Readable - 16px with 1.5 line height
  /// Use for: Paragraphs, long-form content
  static const TextStyle bodyLargeReadable = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.5,
    color: AppColors.textPrimaryDark,
  );

  /// Body Large Readable Light - 16px with 1.5 line height, Light mode
  static const TextStyle bodyLargeReadableLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  /// Body Medium - 15px, Normal
  /// Use for: Secondary content, list items
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Body Medium Light - 15px, Normal, Light mode
  static const TextStyle bodyMediumLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Body Small - 14px, Normal
  /// Use for: Descriptions, helper text
  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Body Small Light - 14px, Normal, Light mode
  static const TextStyle bodySmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Body Small Readable - 14px with 1.5 line height
  /// Use for: Policy text, terms, long descriptions
  static const TextStyle bodySmallReadable = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.5,
    color: AppColors.textPrimaryDark,
  );

  /// Body Small Readable Light - 14px with 1.5 line height, Light mode
  static const TextStyle bodySmallReadableLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  // LABEL STYLES (11-13px)

  /// Label Large - 13px, w500
  /// Use for: Form labels, chip text
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Label Large Light - 13px, w500, Light mode
  static const TextStyle labelLargeLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
  );

  /// Label Medium - 12px, w500
  /// Use for: Tags, badges, small labels
  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimaryDark,
  );

  /// Label Medium Light - 12px, w500, Light mode
  static const TextStyle labelMediumLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimaryLight,
  );

  /// Label Small - 11px, w500
  /// Use for: Overlines, micro labels
  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimaryDark,
  );

  /// Label Small Light - 11px, w500, Light mode
  static const TextStyle labelSmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimaryLight,
  );

  // CAPTION STYLES (10-12px)

  /// Caption - 12px, Normal
  /// Use for: Timestamps, secondary info
  static const TextStyle caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondaryDark,
  );

  /// Caption Light - 12px, Normal, Light mode
  static const TextStyle captionLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondaryLight,
  );

  /// Caption Small - 10px, Normal
  /// Use for: Badges, mini timestamps
  static const TextStyle captionSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondaryDark,
  );

  /// Caption Small Light - 10px, Normal, Light mode
  static const TextStyle captionSmallLight = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textSecondaryLight,
  );

  // BUTTON TEXT STYLES

  /// Button Large - 17px, w600
  /// Use for: Primary buttons, elevated buttons
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Button Medium - 15px, w600
  /// Use for: Secondary buttons, text buttons
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Button Small - 13px, w600
  /// Use for: Compact buttons, chip actions
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  // SEMANTIC TEXT STYLES

  /// Error Text - 14px, Normal, Red
  /// Use for: Error messages, validation errors
  static const TextStyle error = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.error,
  );

  /// Success Text - 14px, Normal, Green
  /// Use for: Success messages, confirmations
  static const TextStyle success = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.success,
  );

  /// Warning Text - 14px, Normal, Amber
  /// Use for: Warning messages, cautions
  static const TextStyle warning = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.warning,
  );

  /// Info Text - 14px, Normal, Blue
  /// Use for: Informational messages, hints
  static const TextStyle info = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.info,
  );

  /// Link Text - 14px, Normal, iOS Blue
  /// Use for: Clickable links, actions
  static const TextStyle link = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.iosBlue,
  );

  /// Destructive Text - 14px, w600, Red
  /// Use for: Delete, logout, destructive actions
  static const TextStyle destructive = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.error,
  );

  // HINT/PLACEHOLDER STYLES

  /// Hint Text - 14px, Normal, Grey
  /// Use for: Input hints, placeholders
  static const TextStyle hint = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.iosGray,
  );

  /// Hint Large - 16px, Normal, Grey
  /// Use for: Large input hints
  static const TextStyle hintLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: AppColors.iosGray,
  );

  /// Hint Small - 12px, Normal, Grey
  /// Use for: Small hints, helper text
  static const TextStyle hintSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.iosGray,
  );

  // SPECIAL STYLES

  /// Emoji Large - 32px
  /// Use for: Large emoji display, reactions
  static const TextStyle emojiLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 32,
  );

  /// Emoji Medium - 24px
  /// Use for: Medium emoji display
  static const TextStyle emojiMedium = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
  );

  /// Emoji Small - 18px
  /// Use for: Inline emoji
  static const TextStyle emojiSmall = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
  );

  /// Price Text - 18px, Bold
  /// Use for: Product prices, amounts
  static const TextStyle price = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Price Large - 24px, Bold
  /// Use for: Featured prices, totals
  static const TextStyle priceLarge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
  );

  /// Rating Text - 14px, w600
  /// Use for: Star ratings, scores
  static const TextStyle rating = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.warning,
  );

  /// Badge Text - 10px, w600, White
  /// Use for: Notification badges, counters
  static const TextStyle badge = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: Colors.white,
  );

  /// Overline Text - 10px, w600, Uppercase tracking
  /// Use for: Category labels, overlines
  static const TextStyle overline = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.textSecondaryDark,
  );

  // HELPER METHODS

  /// Get text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Get text style for dark/light mode
  static TextStyle forMode(
    TextStyle darkStyle,
    TextStyle lightStyle,
    bool isDarkMode,
  ) {
    return isDarkMode ? darkStyle : lightStyle;
  }

  /// Get body style based on size
  static TextStyle getBodyStyle(String size, {bool isDarkMode = true}) {
    switch (size.toLowerCase()) {
      case 'large':
        return isDarkMode ? bodyLarge : bodyLargeLight;
      case 'medium':
        return isDarkMode ? bodyMedium : bodyMediumLight;
      case 'small':
        return isDarkMode ? bodySmall : bodySmallLight;
      default:
        return isDarkMode ? bodyMedium : bodyMediumLight;
    }
  }

  /// Get heading style based on size
  static TextStyle getHeadingStyle(String size, {bool isDarkMode = true}) {
    switch (size.toLowerCase()) {
      case 'large':
        return isDarkMode ? headlineLarge : headlineLargeLight;
      case 'medium':
        return isDarkMode ? headlineMedium : headlineMediumLight;
      case 'small':
        return isDarkMode ? headlineSmall : headlineSmallLight;
      default:
        return isDarkMode ? headlineMedium : headlineMediumLight;
    }
  }

  /// Get title style based on size
  static TextStyle getTitleStyle(String size, {bool isDarkMode = true}) {
    switch (size.toLowerCase()) {
      case 'large':
        return isDarkMode ? titleLarge : titleLargeLight;
      case 'medium':
        return isDarkMode ? titleMedium : titleMediumLight;
      case 'small':
        return isDarkMode ? titleSmall : titleSmallLight;
      default:
        return isDarkMode ? titleMedium : titleMediumLight;
    }
  }

  /// Get label style based on size
  static TextStyle getLabelStyle(String size, {bool isDarkMode = true}) {
    switch (size.toLowerCase()) {
      case 'large':
        return isDarkMode ? labelLarge : labelLargeLight;
      case 'medium':
        return isDarkMode ? labelMedium : labelMediumLight;
      case 'small':
        return isDarkMode ? labelSmall : labelSmallLight;
      default:
        return isDarkMode ? labelMedium : labelMediumLight;
    }
  }

  /// Get caption style based on size
  static TextStyle getCaptionStyle(String size, {bool isDarkMode = true}) {
    switch (size.toLowerCase()) {
      case 'normal':
        return isDarkMode ? caption : captionLight;
      case 'small':
        return isDarkMode ? captionSmall : captionSmallLight;
      default:
        return isDarkMode ? caption : captionLight;
    }
  }

  /// Get button style based on size
  static TextStyle getButtonStyle(String size) {
    switch (size.toLowerCase()) {
      case 'large':
        return buttonLarge;
      case 'medium':
        return buttonMedium;
      case 'small':
        return buttonSmall;
      default:
        return buttonMedium;
    }
  }
}
