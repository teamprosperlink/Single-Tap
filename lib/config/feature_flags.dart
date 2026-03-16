/// Stub for feature flags — placeholder until full implementation.

enum FeatureCategory {
  business,
  social,
  marketplace,
  tools;

  String get displayName {
    switch (this) {
      case FeatureCategory.business: return 'Business';
      case FeatureCategory.social: return 'Social';
      case FeatureCategory.marketplace: return 'Marketplace';
      case FeatureCategory.tools: return 'Tools';
    }
  }
}

class FeatureInfo {
  final String title;
  final String description;
  final String estimatedRelease;
  final String icon;
  final FeatureCategory category;

  const FeatureInfo({
    required this.title,
    required this.description,
    this.estimatedRelease = 'Coming Soon',
    this.icon = 'new_releases',
    this.category = FeatureCategory.tools,
  });
}

class FeatureFlags {
  static FeatureInfo? getFeatureInfo(String featureName) => null;

  static Future<void> registerInterest(
      String featureName, String userId) async {}

  static List<MapEntry<String, FeatureInfo>> getFeaturesByCategory(
      dynamic category) => [];

  static List<MapEntry<String, FeatureInfo>> getComingSoonFeatures() => [];
}
