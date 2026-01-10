import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Responsive Helper - Auto-adjusts UI for all screen sizes
/// Usage:
/// - Initialize in main.dart: ResponsiveHelper.init(context);
/// - Use: ResponsiveHelper.sp(16) for font size
/// - Use: ResponsiveHelper.wp(50) for 50% of screen width
/// - Use: ResponsiveHelper.hp(10) for 10% of screen height
class ResponsiveHelper {
  static late MediaQueryData _mediaQueryData;
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _blockSizeHorizontal;
  static late double _blockSizeVertical;
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double _safeBlockHorizontal;
  static late double _safeBlockVertical;
  static late double _textScaleFactor;
  static late double _pixelRatio;
  static bool _isInitialized = false;

  // Design reference dimensions (based on standard phone)
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  /// Initialize the helper - call this in your main widget build
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    _screenWidth = _mediaQueryData.size.width;
    _screenHeight = _mediaQueryData.size.height;
    _pixelRatio = _mediaQueryData.devicePixelRatio;

    // Use textScaler instead of deprecated textScaleFactor
    _textScaleFactor = _mediaQueryData.textScaler.scale(1.0).clamp(0.8, 1.2);

    _blockSizeHorizontal = _screenWidth / 100;
    _blockSizeVertical = _screenHeight / 100;

    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;

    _safeBlockHorizontal = (_screenWidth - _safeAreaHorizontal) / 100;
    _safeBlockVertical = (_screenHeight - _safeAreaVertical) / 100;

    _isInitialized = true;
  }

  /// Check if initialized
  static bool get isInitialized => _isInitialized;

  /// Screen width
  static double get screenWidth => _screenWidth;

  /// Screen height
  static double get screenHeight => _screenHeight;

  /// Pixel ratio
  static double get pixelRatio => _pixelRatio;

  /// Text scale factor
  static double get textScaleFactor => _textScaleFactor;

  /// Width percentage (0-100)
  static double wp(double percentage) {
    return _blockSizeHorizontal * percentage;
  }

  /// Height percentage (0-100)
  static double hp(double percentage) {
    return _blockSizeVertical * percentage;
  }

  /// Safe width percentage (excluding safe area)
  static double swp(double percentage) {
    return _safeBlockHorizontal * percentage;
  }

  /// Safe height percentage (excluding safe area)
  static double shp(double percentage) {
    return _safeBlockVertical * percentage;
  }

  /// Scaled pixel - for font sizes (responsive text)
  static double sp(double size) {
    final double scaleWidth = _screenWidth / _designWidth;
    final double scaleHeight = _screenHeight / _designHeight;
    final double scale = math.min(scaleWidth, scaleHeight);
    return (size * scale).clamp(size * 0.8, size * 1.3);
  }

  /// Responsive width based on design width
  static double w(double size) {
    return size * (_screenWidth / _designWidth);
  }

  /// Responsive height based on design height
  static double h(double size) {
    return size * (_screenHeight / _designHeight);
  }

  /// Responsive size (uses the smaller scale factor for consistent sizing)
  static double r(double size) {
    final double scaleWidth = _screenWidth / _designWidth;
    final double scaleHeight = _screenHeight / _designHeight;
    return size * math.min(scaleWidth, scaleHeight);
  }

  /// Responsive padding
  static EdgeInsets paddingAll(double value) {
    return EdgeInsets.all(r(value));
  }

  /// Responsive symmetric padding
  static EdgeInsets paddingSymmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: r(horizontal),
      vertical: r(vertical),
    );
  }

  /// Responsive only padding
  static EdgeInsets paddingOnly({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: r(left),
      right: r(right),
      top: r(top),
      bottom: r(bottom),
    );
  }

  /// Responsive border radius
  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(r(radius));
  }

  /// Get device type
  static DeviceType get deviceType {
    if (_screenWidth < 600) {
      return DeviceType.mobile;
    } else if (_screenWidth < 900) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Is small phone (width < 360)
  static bool get isSmallPhone => _screenWidth < 360;

  /// Is medium phone (360 <= width < 400)
  static bool get isMediumPhone => _screenWidth >= 360 && _screenWidth < 400;

  /// Is large phone (width >= 400)
  static bool get isLargePhone => _screenWidth >= 400;

  /// Is tablet
  static bool get isTablet => _screenWidth >= 600;

  /// Safe area padding
  static EdgeInsets get safeAreaPadding => _mediaQueryData.padding;

  /// Bottom navigation height (responsive)
  static double get bottomNavHeight => r(56);

  /// App bar height (responsive)
  static double get appBarHeight => r(56);

  /// Icon size small
  static double get iconSizeSmall => r(16);

  /// Icon size medium
  static double get iconSizeMedium => r(24);

  /// Icon size large
  static double get iconSizeLarge => r(32);

  /// Standard spacing
  static double get spacingXS => r(4);
  static double get spacingS => r(8);
  static double get spacingM => r(16);
  static double get spacingL => r(24);
  static double get spacingXL => r(32);

  /// Font sizes
  static double get fontSizeXS => sp(10);
  static double get fontSizeS => sp(12);
  static double get fontSizeM => sp(14);
  static double get fontSizeL => sp(16);
  static double get fontSizeXL => sp(18);
  static double get fontSizeXXL => sp(20);
  static double get fontSizeHeading => sp(24);
  static double get fontSizeTitle => sp(28);

  /// Button heights
  static double get buttonHeightSmall => r(36);
  static double get buttonHeightMedium => r(44);
  static double get buttonHeightLarge => r(52);

  /// Card dimensions
  static double get cardBorderRadius => r(12);
  static double get cardElevation => r(4);
  static double get cardPadding => r(16);

  /// Avatar sizes
  static double get avatarSizeSmall => r(32);
  static double get avatarSizeMedium => r(48);
  static double get avatarSizeLarge => r(64);
  static double get avatarSizeXL => r(96);

  /// Input field height
  static double get inputFieldHeight => r(48);

  /// Responsive SizedBox
  static SizedBox verticalSpace(double height) => SizedBox(height: r(height));
  static SizedBox horizontalSpace(double width) => SizedBox(width: r(width));
}

/// Device type enum
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Extension on BuildContext for easy access
extension ResponsiveContext on BuildContext {
  /// Initialize ResponsiveHelper
  void initResponsive() => ResponsiveHelper.init(this);

  /// Screen width
  double get screenWidth => ResponsiveHelper.screenWidth;

  /// Screen height
  double get screenHeight => ResponsiveHelper.screenHeight;

  /// Width percentage
  double wp(double percentage) => ResponsiveHelper.wp(percentage);

  /// Height percentage
  double hp(double percentage) => ResponsiveHelper.hp(percentage);

  /// Scaled pixel for fonts
  double sp(double size) => ResponsiveHelper.sp(size);

  /// Responsive size
  double r(double size) => ResponsiveHelper.r(size);

  /// Device type
  DeviceType get deviceType => ResponsiveHelper.deviceType;

  /// Is small phone
  bool get isSmallPhone => ResponsiveHelper.isSmallPhone;

  /// Is tablet
  bool get isTablet => ResponsiveHelper.isTablet;
}

/// Responsive Widget Builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);
    return builder(context, ResponsiveHelper.deviceType);
  }
}

/// Responsive Layout - Different layouts for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    if (ResponsiveHelper.isTablet && tablet != null) {
      return tablet!;
    }

    if (ResponsiveHelper.deviceType == DeviceType.desktop && desktop != null) {
      return desktop!;
    }

    return mobile;
  }
}
