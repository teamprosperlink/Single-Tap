import 'package:flutter/material.dart';
import '../../models/business_category_config.dart';

/// Comprehensive dynamic UI configuration for all business categories
/// This configuration system drives the ENTIRE business profile UI dynamically
/// based on category, features, and business data.
///
/// Architecture:
/// - Each category has a DynamicUIConfig that defines:
///   * Profile sections to display and their order
///   * Dashboard widgets and metrics
///   * Quick actions available
///   * Tab structure for the business app
///   * Profile template to use
///
/// Usage:
/// ```dart
/// final config = DynamicUIConfig.getConfigForCategory(BusinessCategory.foodBeverage);
/// // Build UI dynamically based on config
/// ```

class DynamicUIConfig {
  final BusinessCategory category;
  final String profileTemplate;
  final List<ProfileSection> profileSections;
  final List<DashboardWidget> dashboardWidgets;
  final List<QuickAction> quickActions;
  final List<BusinessTab> bottomTabs;
  final Map<String, dynamic> customization;

  const DynamicUIConfig({
    required this.category,
    required this.profileTemplate,
    required this.profileSections,
    required this.dashboardWidgets,
    required this.quickActions,
    required this.bottomTabs,
    this.customization = const {},
  });

  /// Get dynamic UI configuration for a specific category
  static DynamicUIConfig getConfigForCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.foodBeverage:
        return _foodBeverageConfig;
      case BusinessCategory.hospitality:
        return _hospitalityConfig;
      case BusinessCategory.retail:
        return _retailConfig;
      case BusinessCategory.grocery:
        return _groceryConfig;
      case BusinessCategory.beautyWellness:
        return _beautyWellnessConfig;
      case BusinessCategory.healthcare:
        return _healthcareConfig;
      case BusinessCategory.education:
        return _educationConfig;
      case BusinessCategory.fitness:
        return _fitnessConfig;
      case BusinessCategory.automotive:
        return _automotiveConfig;
      case BusinessCategory.realEstate:
        return _realEstateConfig;
      case BusinessCategory.travelTourism:
        return _travelTourismConfig;
      case BusinessCategory.entertainment:
        return _entertainmentConfig;
      case BusinessCategory.petServices:
        return _petServicesConfig;
      case BusinessCategory.homeServices:
        return _homeServicesConfig;
      case BusinessCategory.technology:
        return _technologyConfig;
      case BusinessCategory.legal:
        return _legalConfig;
      case BusinessCategory.professional:
        return _professionalConfig;
      case BusinessCategory.transportation:
        return _transportationConfig;
      case BusinessCategory.artCreative:
        return _artCreativeConfig;
      case BusinessCategory.construction:
        return _constructionConfig;
      case BusinessCategory.agriculture:
        return _agricultureConfig;
      case BusinessCategory.manufacturing:
        return _manufacturingConfig;
      case BusinessCategory.weddingEvents:
        return _weddingEventsConfig;
    }
  }

  // Default config removed (unused - categories have their own configs)

  // ============ FOOD & BEVERAGE CONFIG ============
  static const _foodBeverageConfig = DynamicUIConfig(
    category: BusinessCategory.foodBeverage,
    profileTemplate: 'restaurant_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.menu,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.recentOrders,
      DashboardWidget.popularItems,
      DashboardWidget.recentReviews,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addMenuItem,
      QuickAction.manageOrders,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.menu,
      BusinessTab.orders,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showMenuCategories': true,
      'showPopularItems': true,
      'showCuisineTypes': true,
      'showDietaryTags': true,
    },
  );

  // ============ HOSPITALITY CONFIG ============
  static const _hospitalityConfig = DynamicUIConfig(
    category: BusinessCategory.hospitality,
    profileTemplate: 'hotel_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.rooms,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayCheckIns,
      DashboardWidget.roomOccupancy,
      DashboardWidget.upcomingBookings,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addRoom,
      QuickAction.manageBookings,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.rooms,
      BusinessTab.bookings,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showAmenities': true,
      'showCheckInOut': true,
      'showRoomAvailability': true,
    },
  );

  // ============ RETAIL CONFIG ============
  static const _retailConfig = DynamicUIConfig(
    category: BusinessCategory.retail,
    profileTemplate: 'retail_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.products,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.recentOrders,
      DashboardWidget.topProducts,
      DashboardWidget.lowStock,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addProduct,
      QuickAction.manageOrders,
      QuickAction.manageInventory,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.products,
      BusinessTab.orders,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showProductCategories': true,
      'showStock': true,
      'showPricing': true,
    },
  );

  // ============ GROCERY CONFIG ============
  static const _groceryConfig = DynamicUIConfig(
    category: BusinessCategory.grocery,
    profileTemplate: 'retail_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.products,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.recentOrders,
      DashboardWidget.topProducts,
      DashboardWidget.lowStock,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addProduct,
      QuickAction.manageOrders,
      QuickAction.manageInventory,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.products,
      BusinessTab.orders,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showProductCategories': true,
      'showStock': true,
      'showPricing': true,
      'showDeliveryOptions': true,
      'showFreshness': true,
    },
  );

  // ============ BEAUTY & WELLNESS CONFIG ============
  static const _beautyWellnessConfig = DynamicUIConfig(
    category: BusinessCategory.beautyWellness,
    profileTemplate: 'salon_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayAppointments,
      DashboardWidget.popularServices,
      DashboardWidget.staffPerformance,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.manageAppointments,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.appointments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showSpecialists': true,
      'showTreatmentDuration': true,
      'showBookingSlots': true,
      'showBeforeAfter': true,
    },
  );

  // ============ HEALTHCARE CONFIG ============
  static const _healthcareConfig = DynamicUIConfig(
    category: BusinessCategory.healthcare,
    profileTemplate: 'healthcare_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayAppointments,
      DashboardWidget.patientQueue,
      DashboardWidget.popularServices,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.manageAppointments,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.appointments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showDoctors': true,
      'showDepartments': true,
      'showSpecializations': true,
      'showConsultationModes': true,
      'showInsuranceAccepted': true,
      'showFacilityFeatures': true,
    },
  );

  // ============ EDUCATION CONFIG ============
  static const _educationConfig = DynamicUIConfig(
    category: BusinessCategory.education,
    profileTemplate: 'education_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.courses,
      ProfileSection.classes,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.totalStudents,
      DashboardWidget.courseEnrollments,
      DashboardWidget.upcomingClasses,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addCourse,
      QuickAction.manageClasses,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.courses,
      BusinessTab.enrollments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showFaculty': true,
      'showSubjects': true,
      'showBatches': true,
      'showDeliveryModes': true,
      'showCertificationPartners': true,
      'showLearningFeatures': true,
      'showPlacementStats': true,
    },
  );

  // ============ FITNESS CONFIG ============
  static const _fitnessConfig = DynamicUIConfig(
    category: BusinessCategory.fitness,
    profileTemplate: 'fitness_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.memberships,
      ProfileSection.classes,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeMembers,
      DashboardWidget.todayClasses,
      DashboardWidget.renewalsDue,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addMembership,
      QuickAction.manageClasses,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.memberships,
      BusinessTab.classes,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showTrainers': true,
      'showFacilities': true,
      'showMembershipPlans': true,
      'showWorkoutFormats': true,
      'showGenderPolicy': true,
      'showClassSchedule': true,
    },
  );

  // ============ AUTOMOTIVE CONFIG ============
  static const _automotiveConfig = DynamicUIConfig(
    category: BusinessCategory.automotive,
    profileTemplate: 'automotive_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.vehicles,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.serviceJobs,
      DashboardWidget.vehicleInventory,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addVehicle,
      QuickAction.addService,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.vehicles,
      BusinessTab.services,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showBrandsHandled': true,
      'showVehicleTypes': true,
      'showFacilityFeatures': true,
      'showServiceBays': true,
      'showPickupDrop': true,
    },
  );

  // ============ REAL ESTATE CONFIG ============
  static const _realEstateConfig = DynamicUIConfig(
    category: BusinessCategory.realEstate,
    profileTemplate: 'real_estate_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.properties,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeListings,
      DashboardWidget.inquiries,
      DashboardWidget.closedDeals,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addProperty,
      QuickAction.manageInquiries,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.properties,
      BusinessTab.inquiries,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showPropertyTypes': true,
      'showTransactionTypes': true,
      'showOperatingAreas': true,
      'showAgencyFeatures': true,
      'showRERA': true,
      'showTeamMembers': true,
      'showClosedDeals': true,
      'showPricing': true,
      'showLocation': true,
    },
  );

  // ============ TRAVEL & TOURISM CONFIG ============
  static const _travelTourismConfig = DynamicUIConfig(
    category: BusinessCategory.travelTourism,
    profileTemplate: 'travel_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.packages,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeBookings,
      DashboardWidget.popularPackages,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addPackage,
      QuickAction.manageBookings,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.packages,
      BusinessTab.bookings,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showTourTypes': true,
      'showDestinations': true,
      'showServicesOffered': true,
      'showAgencyFeatures': true,
      'showTeamMembers': true,
      'showCertifications': true,
      'showTravelStats': true,
    },
  );

  // ============ ENTERTAINMENT CONFIG ============
  static const _entertainmentConfig = DynamicUIConfig(
    category: BusinessCategory.entertainment,
    profileTemplate: 'entertainment_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.packages,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.upcomingEvents,
      DashboardWidget.bookings,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addPackage,
      QuickAction.manageBookings,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.packages,
      BusinessTab.bookings,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showEventTypes': true,
      'showAmenities': true,
      'showVenueFeatures': true,
      'showCapacity': true,
      'showUpcomingEvents': true,
      'showEntertainmentStats': true,
      'showTeamMembers': true,
    },
  );

  // ============ PET SERVICES CONFIG ============
  static const _petServicesConfig = DynamicUIConfig(
    category: BusinessCategory.petServices,
    profileTemplate: 'pet_services_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.products,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayAppointments,
      DashboardWidget.boardingPets,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.addProduct,
      QuickAction.manageAppointments,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.products,
      BusinessTab.appointments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showPetTypes': true,
      'showFacilities': true,
      'showCertifications': true,
      'showPetCareStats': true,
      'showTeamMembers': true,
      'showBoardingInfo': true,
      'showEmergencyCare': true,
    },
  );

  // ============ HOME SERVICES CONFIG ============
  static const _homeServicesConfig = DynamicUIConfig(
    category: BusinessCategory.homeServices,
    profileTemplate: 'home_services_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayJobs,
      DashboardWidget.pendingRequests,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.manageAppointments,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.appointments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showServiceTypes': true,
      'showServiceArea': true,
      'showCertifications': true,
      'showServiceFeatures': true,
      'showTeamMembers': true,
      'showWarrantyInfo': true,
      'showEmergencyService': true,
    },
  );

  // ============ TECHNOLOGY CONFIG ============
  static const _technologyConfig = DynamicUIConfig(
    category: BusinessCategory.technology,
    profileTemplate: 'technology_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.portfolio,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeProjects,
      DashboardWidget.inquiries,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.addPortfolioItem,
      QuickAction.manageInquiries,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.portfolio,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showTechStack': true,
      'showCertifications': true,
      'showPortfolio': true,
      'showClientTypes': true,
      'showTeamMembers': true,
      'showIndustryVerticals': true,
      'showServiceModels': true,
    },
  );

  // ============ LEGAL CONFIG ============
  static const _legalConfig = DynamicUIConfig(
    category: BusinessCategory.legal,
    profileTemplate: 'legal_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.todayAppointments,
      DashboardWidget.activeCases,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.manageAppointments,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.appointments,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showPracticeAreas': true,
      'showCredentials': true,
      'showCourtsPracticed': true,
      'showFeeStructure': true,
      'showCaseStats': true,
      'showTeam': true,
      'showConsultationCTA': true,
    },
  );

  // ============ PROFESSIONAL CONFIG ============
  static const _professionalConfig = DynamicUIConfig(
    category: BusinessCategory.professional,
    profileTemplate: 'professional_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.portfolio,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeProjects,
      DashboardWidget.inquiries,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.addPortfolioItem,
      QuickAction.manageInquiries,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.portfolio,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
    customization: {
      'showExpertise': true,
      'showCertifications': true,
      'showClientTypes': true,
      'showIndustriesServed': true,
      'showCaseStudies': true,
      'showTeam': true,
      'showProposalCTA': true,
    },
  );

  // ============ TRANSPORTATION CONFIG ============
  static const _transportationConfig = DynamicUIConfig(
    category: BusinessCategory.transportation,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.vehicles,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeBookings,
      DashboardWidget.fleetStatus,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addVehicle,
      QuickAction.manageBookings,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.vehicles,
      BusinessTab.bookings,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // ============ ART & CREATIVE CONFIG ============
  static const _artCreativeConfig = DynamicUIConfig(
    category: BusinessCategory.artCreative,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.portfolio,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeProjects,
      DashboardWidget.bookings,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addPortfolioItem,
      QuickAction.addService,
      QuickAction.manageBookings,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.portfolio,
      BusinessTab.services,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // ============ CONSTRUCTION CONFIG ============
  static const _constructionConfig = DynamicUIConfig(
    category: BusinessCategory.construction,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.services,
      ProfileSection.portfolio,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.activeProjects,
      DashboardWidget.inquiries,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addService,
      QuickAction.addPortfolioItem,
      QuickAction.manageInquiries,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.services,
      BusinessTab.portfolio,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // ============ AGRICULTURE CONFIG ============
  static const _agricultureConfig = DynamicUIConfig(
    category: BusinessCategory.agriculture,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.products,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.recentOrders,
      DashboardWidget.topProducts,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addProduct,
      QuickAction.addService,
      QuickAction.manageOrders,
      QuickAction.createPost,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.products,
      BusinessTab.orders,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // ============ MANUFACTURING CONFIG ============
  static const _manufacturingConfig = DynamicUIConfig(
    category: BusinessCategory.manufacturing,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.products,
      ProfileSection.services,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.recentOrders,
      DashboardWidget.production,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addProduct,
      QuickAction.manageOrders,
      QuickAction.createPost,
      QuickAction.viewAnalytics,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.products,
      BusinessTab.orders,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // ============ WEDDING & EVENTS CONFIG ============
  static const _weddingEventsConfig = DynamicUIConfig(
    category: BusinessCategory.weddingEvents,
    profileTemplate: 'generic_template',
    profileSections: [
      ProfileSection.hero,
      ProfileSection.quickActions,
      ProfileSection.highlights,
      ProfileSection.packages,
      ProfileSection.services,
      ProfileSection.portfolio,
      ProfileSection.gallery,
      ProfileSection.reviews,
      ProfileSection.hours,
      ProfileSection.location,
    ],
    dashboardWidgets: [
      DashboardWidget.stats,
      DashboardWidget.upcomingEvents,
      DashboardWidget.bookings,
      DashboardWidget.earnings,
    ],
    quickActions: [
      QuickAction.addPackage,
      QuickAction.addService,
      QuickAction.addPortfolioItem,
      QuickAction.manageBookings,
    ],
    bottomTabs: [
      BusinessTab.home,
      BusinessTab.packages,
      BusinessTab.services,
      BusinessTab.messages,
      BusinessTab.profile,
    ],
  );

  // Generic config removed (unused - categories have their own configs)
}

/// Profile sections that can be displayed
enum ProfileSection {
  hero,
  quickActions,
  highlights,
  menu,
  products,
  services,
  rooms,
  properties,
  vehicles,
  courses,
  classes,
  memberships,
  packages,
  portfolio,
  gallery,
  reviews,
  hours,
  location,
}

/// Dashboard widgets for business dashboard
enum DashboardWidget {
  stats,
  recentOrders,
  popularItems,
  topProducts,
  lowStock,
  recentReviews,
  todayAppointments,
  todayCheckIns,
  roomOccupancy,
  upcomingBookings,
  popularServices,
  staffPerformance,
  patientQueue,
  totalStudents,
  courseEnrollments,
  upcomingClasses,
  activeMembers,
  todayClasses,
  renewalsDue,
  serviceJobs,
  vehicleInventory,
  activeListings,
  inquiries,
  closedDeals,
  activeBookings,
  popularPackages,
  upcomingEvents,
  boardingPets,
  todayJobs,
  pendingRequests,
  activeProjects,
  bookings,
  fleetStatus,
  production,
  activeCases,
  earnings,
}

/// Quick actions available in business dashboard
enum QuickAction {
  addMenuItem,
  addProduct,
  addService,
  addRoom,
  addProperty,
  addVehicle,
  addCourse,
  addMembership,
  addPackage,
  addPortfolioItem,
  manageOrders,
  manageBookings,
  manageAppointments,
  manageClasses,
  manageInventory,
  manageInquiries,
  createPost,
  viewAnalytics,
}

/// Bottom navigation tabs for business app
enum BusinessTab {
  home,
  menu,
  products,
  services,
  rooms,
  bookings,
  orders,
  appointments,
  courses,
  enrollments,
  classes,
  memberships,
  vehicles,
  properties,
  inquiries,
  packages,
  portfolio,
  messages,
  profile,
}

/// Extension for UI display
extension ProfileSectionExtension on ProfileSection {
  String get displayName {
    switch (this) {
      case ProfileSection.hero:
        return 'Header';
      case ProfileSection.quickActions:
        return 'Quick Actions';
      case ProfileSection.highlights:
        return 'Highlights';
      case ProfileSection.menu:
        return 'Menu';
      case ProfileSection.products:
        return 'Products';
      case ProfileSection.services:
        return 'Services';
      case ProfileSection.rooms:
        return 'Rooms';
      case ProfileSection.properties:
        return 'Properties';
      case ProfileSection.vehicles:
        return 'Vehicles';
      case ProfileSection.courses:
        return 'Courses';
      case ProfileSection.classes:
        return 'Classes';
      case ProfileSection.memberships:
        return 'Memberships';
      case ProfileSection.packages:
        return 'Packages';
      case ProfileSection.portfolio:
        return 'Portfolio';
      case ProfileSection.gallery:
        return 'Gallery';
      case ProfileSection.reviews:
        return 'Reviews';
      case ProfileSection.hours:
        return 'Hours';
      case ProfileSection.location:
        return 'Location';
    }
  }

  IconData get icon {
    switch (this) {
      case ProfileSection.hero:
        return Icons.image;
      case ProfileSection.quickActions:
        return Icons.touch_app;
      case ProfileSection.highlights:
        return Icons.star;
      case ProfileSection.menu:
        return Icons.restaurant_menu;
      case ProfileSection.products:
        return Icons.shopping_bag;
      case ProfileSection.services:
        return Icons.room_service;
      case ProfileSection.rooms:
        return Icons.hotel;
      case ProfileSection.properties:
        return Icons.apartment;
      case ProfileSection.vehicles:
        return Icons.directions_car;
      case ProfileSection.courses:
        return Icons.school;
      case ProfileSection.classes:
        return Icons.class_;
      case ProfileSection.memberships:
        return Icons.card_membership;
      case ProfileSection.packages:
        return Icons.local_offer;
      case ProfileSection.portfolio:
        return Icons.work;
      case ProfileSection.gallery:
        return Icons.photo_library;
      case ProfileSection.reviews:
        return Icons.rate_review;
      case ProfileSection.hours:
        return Icons.access_time;
      case ProfileSection.location:
        return Icons.location_on;
    }
  }
}

extension BusinessTabExtension on BusinessTab {
  String get label {
    switch (this) {
      case BusinessTab.home:
        return 'Home';
      case BusinessTab.menu:
        return 'Menu';
      case BusinessTab.products:
        return 'Products';
      case BusinessTab.services:
        return 'Services';
      case BusinessTab.rooms:
        return 'Rooms';
      case BusinessTab.bookings:
        return 'Bookings';
      case BusinessTab.orders:
        return 'Orders';
      case BusinessTab.appointments:
        return 'Appointments';
      case BusinessTab.courses:
        return 'Courses';
      case BusinessTab.enrollments:
        return 'Enrollments';
      case BusinessTab.classes:
        return 'Classes';
      case BusinessTab.memberships:
        return 'Memberships';
      case BusinessTab.vehicles:
        return 'Vehicles';
      case BusinessTab.properties:
        return 'Properties';
      case BusinessTab.inquiries:
        return 'Inquiries';
      case BusinessTab.packages:
        return 'Packages';
      case BusinessTab.portfolio:
        return 'Portfolio';
      case BusinessTab.messages:
        return 'Messages';
      case BusinessTab.profile:
        return 'Profile';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessTab.home:
        return Icons.home;
      case BusinessTab.menu:
        return Icons.restaurant_menu;
      case BusinessTab.products:
        return Icons.inventory;
      case BusinessTab.services:
        return Icons.room_service;
      case BusinessTab.rooms:
        return Icons.hotel;
      case BusinessTab.bookings:
        return Icons.book_online;
      case BusinessTab.orders:
        return Icons.shopping_cart;
      case BusinessTab.appointments:
        return Icons.calendar_today;
      case BusinessTab.courses:
        return Icons.school;
      case BusinessTab.enrollments:
        return Icons.how_to_reg;
      case BusinessTab.classes:
        return Icons.class_;
      case BusinessTab.memberships:
        return Icons.card_membership;
      case BusinessTab.vehicles:
        return Icons.directions_car;
      case BusinessTab.properties:
        return Icons.apartment;
      case BusinessTab.inquiries:
        return Icons.question_answer;
      case BusinessTab.packages:
        return Icons.local_offer;
      case BusinessTab.portfolio:
        return Icons.work;
      case BusinessTab.messages:
        return Icons.message;
      case BusinessTab.profile:
        return Icons.person;
    }
  }
}

extension QuickActionExtension on QuickAction {
  String get label {
    switch (this) {
      case QuickAction.addMenuItem:
        return 'Add Menu Item';
      case QuickAction.addProduct:
        return 'Add Product';
      case QuickAction.addService:
        return 'Add Service';
      case QuickAction.addRoom:
        return 'Add Room';
      case QuickAction.addProperty:
        return 'Add Property';
      case QuickAction.addVehicle:
        return 'Add Vehicle';
      case QuickAction.addCourse:
        return 'Add Course';
      case QuickAction.addMembership:
        return 'Add Membership';
      case QuickAction.addPackage:
        return 'Add Package';
      case QuickAction.addPortfolioItem:
        return 'Add to Portfolio';
      case QuickAction.manageOrders:
        return 'Manage Orders';
      case QuickAction.manageBookings:
        return 'Manage Bookings';
      case QuickAction.manageAppointments:
        return 'Manage Appointments';
      case QuickAction.manageClasses:
        return 'Manage Classes';
      case QuickAction.manageInventory:
        return 'Manage Inventory';
      case QuickAction.manageInquiries:
        return 'Manage Inquiries';
      case QuickAction.createPost:
        return 'Create Post';
      case QuickAction.viewAnalytics:
        return 'View Analytics';
    }
  }

  IconData get icon {
    switch (this) {
      case QuickAction.addMenuItem:
        return Icons.add_circle;
      case QuickAction.addProduct:
        return Icons.add_shopping_cart;
      case QuickAction.addService:
        return Icons.add_business;
      case QuickAction.addRoom:
        return Icons.add_home;
      case QuickAction.addProperty:
        return Icons.add_location;
      case QuickAction.addVehicle:
        return Icons.add_road;
      case QuickAction.addCourse:
        return Icons.add_box;
      case QuickAction.addMembership:
        return Icons.add_card;
      case QuickAction.addPackage:
        return Icons.add;
      case QuickAction.addPortfolioItem:
        return Icons.add_photo_alternate;
      case QuickAction.manageOrders:
        return Icons.receipt_long;
      case QuickAction.manageBookings:
        return Icons.event_available;
      case QuickAction.manageAppointments:
        return Icons.calendar_month;
      case QuickAction.manageClasses:
        return Icons.groups;
      case QuickAction.manageInventory:
        return Icons.inventory_2;
      case QuickAction.manageInquiries:
        return Icons.contact_support;
      case QuickAction.createPost:
        return Icons.post_add;
      case QuickAction.viewAnalytics:
        return Icons.analytics;
    }
  }
}

/// Category-specific terminology for listings/offerings screen
class CategoryTerminology {
  final String screenTitle;
  final String filter1Label;
  final String filter1Icon;
  final String filter2Label;
  final String filter2Icon;
  final String emptyStateMessage;

  const CategoryTerminology({
    required this.screenTitle,
    required this.filter1Label,
    required this.filter1Icon,
    required this.filter2Label,
    required this.filter2Icon,
    required this.emptyStateMessage,
  });

  /// Get category-specific terminology
  static CategoryTerminology getForCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.foodBeverage:
        return const CategoryTerminology(
          screenTitle: 'Menu & Products',
          filter1Label: 'Menu Items',
          filter1Icon: 'restaurant_menu',
          filter2Label: 'Products',
          filter2Icon: 'shopping_bag',
          emptyStateMessage: 'Start adding menu items or products',
        );

      case BusinessCategory.hospitality:
        return const CategoryTerminology(
          screenTitle: 'Hotel & Amenities',
          filter1Label: 'Rooms',
          filter1Icon: 'hotel',
          filter2Label: 'Amenities',
          filter2Icon: 'room_service',
          emptyStateMessage: 'Start adding rooms and hotel amenities',
        );

      case BusinessCategory.retail:
        return const CategoryTerminology(
          screenTitle: 'Catalog & Services',
          filter1Label: 'Products',
          filter1Icon: 'inventory',
          filter2Label: 'Services',
          filter2Icon: 'handyman',
          emptyStateMessage: 'Start building your product catalog',
        );

      case BusinessCategory.grocery:
        return const CategoryTerminology(
          screenTitle: 'Grocery & Delivery',
          filter1Label: 'Groceries',
          filter1Icon: 'shopping_cart',
          filter2Label: 'Delivery',
          filter2Icon: 'local_shipping',
          emptyStateMessage: 'Start adding grocery items and delivery options',
        );

      case BusinessCategory.beautyWellness:
        return const CategoryTerminology(
          screenTitle: 'Treatment Menu',
          filter1Label: 'Treatments',
          filter1Icon: 'spa',
          filter2Label: 'Packages',
          filter2Icon: 'card_giftcard',
          emptyStateMessage: 'Build your treatment menu to attract new clients',
        );

      case BusinessCategory.healthcare:
        return const CategoryTerminology(
          screenTitle: 'Departments & Services',
          filter1Label: 'Consultations',
          filter1Icon: 'medical_services',
          filter2Label: 'Diagnostics',
          filter2Icon: 'healing',
          emptyStateMessage:
              'Add your departments, consultations, and diagnostic services',
        );

      case BusinessCategory.education:
        return const CategoryTerminology(
          screenTitle: 'Courses & Enrollments',
          filter1Label: 'Courses',
          filter1Icon: 'school',
          filter2Label: 'Enrollments',
          filter2Icon: 'people',
          emptyStateMessage:
              'Start adding courses to accept student enrollments',
        );

      case BusinessCategory.fitness:
        return const CategoryTerminology(
          screenTitle: 'Workouts & Memberships',
          filter1Label: 'Classes',
          filter1Icon: 'fitness_center',
          filter2Label: 'Memberships',
          filter2Icon: 'card_membership',
          emptyStateMessage: 'Start adding workout classes or membership plans',
        );

      case BusinessCategory.automotive:
        return const CategoryTerminology(
          screenTitle: 'Vehicles & Services',
          filter1Label: 'Vehicles',
          filter1Icon: 'directions_car',
          filter2Label: 'Services',
          filter2Icon: 'build',
          emptyStateMessage:
              'Add vehicles to your inventory or services to your catalog',
        );

      case BusinessCategory.realEstate:
        return const CategoryTerminology(
          screenTitle: 'Properties & Listings',
          filter1Label: 'For Sale',
          filter1Icon: 'apartment',
          filter2Label: 'For Rent',
          filter2Icon: 'real_estate_agent',
          emptyStateMessage:
              'Add property listings to your portfolio — sale, rent, or lease',
        );

      case BusinessCategory.travelTourism:
        return const CategoryTerminology(
          screenTitle: 'Tour Packages',
          filter1Label: 'Packages',
          filter1Icon: 'local_offer',
          filter2Label: 'Tours',
          filter2Icon: 'tour',
          emptyStateMessage:
              'Add tour packages — domestic, international, adventure, pilgrimage & more',
        );

      case BusinessCategory.entertainment:
        return const CategoryTerminology(
          screenTitle: 'Events & Experiences',
          filter1Label: 'Events',
          filter1Icon: 'event',
          filter2Label: 'Experiences',
          filter2Icon: 'celebration',
          emptyStateMessage:
              'Add events and experiences — shows, gaming, parties, concerts & more',
        );

      case BusinessCategory.petServices:
        return const CategoryTerminology(
          screenTitle: 'Pet Care & Services',
          filter1Label: 'Services',
          filter1Icon: 'pets',
          filter2Label: 'Supplies',
          filter2Icon: 'shopping_basket',
          emptyStateMessage:
              'Add pet care services — grooming, boarding, training, veterinary & more',
        );

      case BusinessCategory.homeServices:
        return const CategoryTerminology(
          screenTitle: 'Home Services & Repairs',
          filter1Label: 'Services',
          filter1Icon: 'home_repair_service',
          filter2Label: 'Repairs',
          filter2Icon: 'handyman',
          emptyStateMessage:
              'Add home services — plumbing, electrical, cleaning, AC repair & more',
        );

      case BusinessCategory.technology:
        return const CategoryTerminology(
          screenTitle: 'IT Services & Solutions',
          filter1Label: 'Services',
          filter1Icon: 'computer',
          filter2Label: 'Portfolio',
          filter2Icon: 'work',
          emptyStateMessage:
              'Add IT services — web dev, cloud, cybersecurity, AI/ML & more',
        );

      case BusinessCategory.legal:
        return const CategoryTerminology(
          screenTitle: 'Legal Services & Practice',
          filter1Label: 'Practice Areas',
          filter1Icon: 'gavel',
          filter2Label: 'Consultations',
          filter2Icon: 'description',
          emptyStateMessage:
              'Add legal services — consultations, case handling, document drafting & more',
        );

      case BusinessCategory.professional:
        return const CategoryTerminology(
          screenTitle: 'Professional Services & Consulting',
          filter1Label: 'Services',
          filter1Icon: 'business_center',
          filter2Label: 'Portfolio',
          filter2Icon: 'work',
          emptyStateMessage:
              'Add consulting services — strategy, marketing, HR, finance, design & more',
        );

      case BusinessCategory.transportation:
        return const CategoryTerminology(
          screenTitle: 'Fleet & Routes',
          filter1Label: 'Fleet',
          filter1Icon: 'local_shipping',
          filter2Label: 'Routes',
          filter2Icon: 'delivery_dining',
          emptyStateMessage: 'Start adding fleet vehicles or delivery routes',
        );

      case BusinessCategory.artCreative:
        return const CategoryTerminology(
          screenTitle: 'Creative Work',
          filter1Label: 'Portfolio',
          filter1Icon: 'palette',
          filter2Label: 'Commissions',
          filter2Icon: 'design_services',
          emptyStateMessage:
              'Start showcasing your creative work and commissions',
        );

      case BusinessCategory.construction:
        return const CategoryTerminology(
          screenTitle: 'Construction & Build',
          filter1Label: 'Projects',
          filter1Icon: 'construction',
          filter2Label: 'Contracting',
          filter2Icon: 'engineering',
          emptyStateMessage:
              'Start adding construction projects and contracting services',
        );

      case BusinessCategory.agriculture:
        return const CategoryTerminology(
          screenTitle: 'Produce & Equipment',
          filter1Label: 'Produce',
          filter1Icon: 'agriculture',
          filter2Label: 'Equipment',
          filter2Icon: 'eco',
          emptyStateMessage: 'Start adding produce and farming equipment',
        );

      case BusinessCategory.manufacturing:
        return const CategoryTerminology(
          screenTitle: 'Products & Solutions',
          filter1Label: 'Products',
          filter1Icon: 'precision_manufacturing',
          filter2Label: 'Solutions',
          filter2Icon: 'settings_suggest',
          emptyStateMessage: 'Start adding products or solutions',
        );

      case BusinessCategory.weddingEvents:
        return const CategoryTerminology(
          screenTitle: 'Event Planning',
          filter1Label: 'Packages',
          filter1Icon: 'card_giftcard',
          filter2Label: 'Add-ons',
          filter2Icon: 'celebration',
          emptyStateMessage: 'Start adding event packages and add-on services',
        );
    }
  }

  IconData getFilter1Icon() {
    return _getIconFromString(filter1Icon);
  }

  IconData getFilter2Icon() {
    return _getIconFromString(filter2Icon);
  }

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'shopping_bag':
        return Icons.shopping_bag_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'room_service':
        return Icons.room_service_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'handyman':
        return Icons.handyman_outlined;
      case 'spa':
        return Icons.spa_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'healing':
        return Icons.healing_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'class':
        return Icons.class_outlined;
      case 'fitness_center':
        return Icons.fitness_center_outlined;
      case 'card_membership':
        return Icons.card_membership_outlined;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'build':
        return Icons.build_outlined;
      case 'apartment':
        return Icons.apartment_outlined;
      case 'real_estate_agent':
        return Icons.real_estate_agent_outlined;
      case 'local_offer':
        return Icons.local_offer_outlined;
      case 'tour':
        return Icons.tour_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'confirmation_number':
        return Icons.confirmation_number_outlined;
      case 'pets':
        return Icons.pets_outlined;
      case 'shopping_basket':
        return Icons.shopping_basket_outlined;
      case 'home_repair_service':
        return Icons.home_repair_service_outlined;
      case 'devices':
        return Icons.devices_outlined;
      case 'computer':
        return Icons.computer_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'gavel':
        return Icons.gavel_outlined;
      case 'description':
        return Icons.description_outlined;
      case 'business_center':
        return Icons.business_center_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outlined;
      case 'local_shipping':
        return Icons.local_shipping_outlined;
      case 'delivery_dining':
        return Icons.delivery_dining_outlined;
      case 'palette':
        return Icons.palette_outlined;
      case 'design_services':
        return Icons.design_services_outlined;
      case 'construction':
        return Icons.construction_outlined;
      case 'engineering':
        return Icons.engineering_outlined;
      case 'agriculture':
        return Icons.agriculture_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing_outlined;
      case 'settings_suggest':
        return Icons.settings_suggest_outlined;
      case 'celebration':
        return Icons.celebration_outlined;
      case 'people':
        return Icons.people_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
