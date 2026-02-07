/// Behavioral archetype types for business categories
/// Based on shared operational patterns and UI/UX requirements
enum ArchetypeType {
  /// Inventory-Based Sales (Products with stock management)
  /// Categories: Grocery, Retail, Electronics, Fashion, Pharmacy
  retail,

  /// Service Menu Selection (Menu items with customization)
  /// Categories: Food Delivery, Beauty & Spa, Auto Services
  menu,

  /// Calendar-Based Booking (Appointment scheduling)
  /// Categories: Healthcare, Education, Real Estate, Legal, Home Services,
  ///            Fitness, Pet Care, Event Services
  appointment,

  /// Room/Space Booking (Hospitality industry)
  /// Categories: Hospitality (Hotels, Resorts, Lodges)
  hospitality,

  /// Project/Work Showcase (Portfolio and quote requests)
  /// Categories: Construction, Freelance Services, Photography, Media Production
  portfolio,
}

/// Extension for ArchetypeType to provide utility methods
extension ArchetypeTypeExtension on ArchetypeType {
  String get id {
    switch (this) {
      case ArchetypeType.retail:
        return 'retail';
      case ArchetypeType.menu:
        return 'menu';
      case ArchetypeType.appointment:
        return 'appointment';
      case ArchetypeType.hospitality:
        return 'hospitality';
      case ArchetypeType.portfolio:
        return 'portfolio';
    }
  }

  String get displayName {
    switch (this) {
      case ArchetypeType.retail:
        return 'Retail';
      case ArchetypeType.menu:
        return 'Menu';
      case ArchetypeType.appointment:
        return 'Appointment';
      case ArchetypeType.hospitality:
        return 'Hospitality';
      case ArchetypeType.portfolio:
        return 'Portfolio';
    }
  }

  String get description {
    switch (this) {
      case ArchetypeType.retail:
        return 'Inventory-based sales with product catalog and stock management';
      case ArchetypeType.menu:
        return 'Service menu selection with customization options';
      case ArchetypeType.appointment:
        return 'Calendar-based booking and appointment scheduling';
      case ArchetypeType.hospitality:
        return 'Room/space booking with check-in/check-out management';
      case ArchetypeType.portfolio:
        return 'Project showcase with portfolio and quote requests';
    }
  }

  /// Get archetype from string
  static ArchetypeType? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'retail':
        return ArchetypeType.retail;
      case 'menu':
        return ArchetypeType.menu;
      case 'appointment':
        return ArchetypeType.appointment;
      case 'hospitality':
        return ArchetypeType.hospitality;
      case 'portfolio':
        return ArchetypeType.portfolio;
      default:
        return null;
    }
  }
}
