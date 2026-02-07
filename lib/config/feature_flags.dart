/// Categories for features.
enum FeatureCategory {
  general,
  business,
  social,
  communication;

  String get displayName {
    switch (this) {
      case FeatureCategory.general:
        return 'General';
      case FeatureCategory.business:
        return 'Business';
      case FeatureCategory.social:
        return 'Social';
      case FeatureCategory.communication:
        return 'Communication';
    }
  }
}

/// Information about a feature flag.
class FeatureInfo {
  final String name;
  final String title;
  final String description;
  final String icon;
  final FeatureCategory category;
  final bool isEnabled;
  final String estimatedRelease;

  const FeatureInfo({
    required this.name,
    String? title,
    required this.description,
    this.icon = 'new_releases',
    this.category = FeatureCategory.general,
    this.isEnabled = false,
    this.estimatedRelease = 'TBD',
  }) : title = title ?? name;
}

/// Feature flags configuration for the app.
class FeatureFlags {
  FeatureFlags._();

  /// Get all features in a given category.
  static List<MapEntry<String, FeatureInfo>> getFeaturesByCategory(FeatureCategory category) {
    return [];
  }

  /// Get all features marked as coming soon.
  static List<MapEntry<String, FeatureInfo>> getComingSoonFeatures() {
    return [];
  }

  /// Get info about a specific feature by name.
  static FeatureInfo? getFeatureInfo(String featureName) {
    return null;
  }

  /// Register user interest in a feature.
  static Future<void> registerInterest(
    String featureName,
    String userId,
  ) async {
    // Stub: no-op
  }
}
