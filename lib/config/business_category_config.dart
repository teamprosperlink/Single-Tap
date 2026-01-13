import 'package:flutter/material.dart';

/// Business category enum for all supported business types
enum BusinessCategory {
  // Retail & Shopping
  retail,
  grocery,

  // Food & Beverage
  foodBeverage,

  // Hospitality
  hospitality,

  // Services
  beautyWellness,
  healthcare,
  fitness,
  petServices,
  homeServices,
  automotive,

  // Professional
  education,
  professionalServices,
  technologyIT,
  legalServices,
  financialServices,

  // Other
  realEstate,
  travelTourism,
  entertainment,
  transportation,
  artCreative,
  construction,
  agriculture,
  manufacturing,
  weddingEvents,

  // Default
  other,
}

/// Extension to get BusinessCategory from business type string
extension BusinessCategoryExtension on BusinessCategory {
  /// Get the display name for this category
  String get displayName {
    switch (this) {
      case BusinessCategory.retail:
        return 'Retail Store';
      case BusinessCategory.grocery:
        return 'Grocery & Essentials';
      case BusinessCategory.foodBeverage:
        return 'Restaurant & Cafe';
      case BusinessCategory.hospitality:
        return 'Hospitality & Tourism';
      case BusinessCategory.beautyWellness:
        return 'Beauty & Wellness';
      case BusinessCategory.healthcare:
        return 'Healthcare';
      case BusinessCategory.fitness:
        return 'Fitness & Sports';
      case BusinessCategory.petServices:
        return 'Pet Services';
      case BusinessCategory.homeServices:
        return 'Home Services';
      case BusinessCategory.automotive:
        return 'Automotive';
      case BusinessCategory.education:
        return 'Education & Training';
      case BusinessCategory.professionalServices:
        return 'Professional Services';
      case BusinessCategory.technologyIT:
        return 'Technology & IT';
      case BusinessCategory.legalServices:
        return 'Legal Services';
      case BusinessCategory.financialServices:
        return 'Financial Services';
      case BusinessCategory.realEstate:
        return 'Real Estate';
      case BusinessCategory.travelTourism:
        return 'Travel & Tourism';
      case BusinessCategory.entertainment:
        return 'Entertainment & Media';
      case BusinessCategory.transportation:
        return 'Transportation & Logistics';
      case BusinessCategory.artCreative:
        return 'Art & Creative';
      case BusinessCategory.construction:
        return 'Construction';
      case BusinessCategory.agriculture:
        return 'Agriculture & Nursery';
      case BusinessCategory.manufacturing:
        return 'Manufacturing';
      case BusinessCategory.weddingEvents:
        return 'Wedding & Events';
      case BusinessCategory.other:
        return 'Other';
    }
  }

  /// Get the primary content tab label for this category
  String get contentTabLabel {
    switch (this) {
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        return 'Products';
      case BusinessCategory.foodBeverage:
        return 'Menu';
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
        return 'Rooms';
      case BusinessCategory.beautyWellness:
      case BusinessCategory.healthcare:
      case BusinessCategory.fitness:
      case BusinessCategory.petServices:
      case BusinessCategory.homeServices:
      case BusinessCategory.automotive:
      case BusinessCategory.professionalServices:
      case BusinessCategory.technologyIT:
      case BusinessCategory.legalServices:
      case BusinessCategory.financialServices:
      case BusinessCategory.artCreative:
      case BusinessCategory.construction:
      case BusinessCategory.manufacturing:
        return 'Services';
      case BusinessCategory.education:
        return 'Courses';
      case BusinessCategory.realEstate:
        return 'Listings';
      case BusinessCategory.entertainment:
        return 'Events';
      case BusinessCategory.transportation:
        return 'Vehicles';
      case BusinessCategory.agriculture:
        return 'Products';
      case BusinessCategory.weddingEvents:
        return 'Packages';
      case BusinessCategory.other:
        return 'Services';
    }
  }

  /// Get the icon for the primary content tab
  IconData get contentTabIcon {
    switch (this) {
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        return Icons.inventory_2_outlined;
      case BusinessCategory.foodBeverage:
        return Icons.restaurant_menu_outlined;
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
        return Icons.hotel_outlined;
      case BusinessCategory.beautyWellness:
        return Icons.spa_outlined;
      case BusinessCategory.healthcare:
        return Icons.medical_services_outlined;
      case BusinessCategory.fitness:
        return Icons.fitness_center_outlined;
      case BusinessCategory.petServices:
        return Icons.pets_outlined;
      case BusinessCategory.homeServices:
        return Icons.home_repair_service_outlined;
      case BusinessCategory.automotive:
        return Icons.directions_car_outlined;
      case BusinessCategory.education:
        return Icons.school_outlined;
      case BusinessCategory.professionalServices:
        return Icons.business_center_outlined;
      case BusinessCategory.technologyIT:
        return Icons.computer_outlined;
      case BusinessCategory.legalServices:
        return Icons.gavel_outlined;
      case BusinessCategory.financialServices:
        return Icons.account_balance_outlined;
      case BusinessCategory.realEstate:
        return Icons.home_work_outlined;
      case BusinessCategory.entertainment:
        return Icons.theater_comedy_outlined;
      case BusinessCategory.transportation:
        return Icons.local_shipping_outlined;
      case BusinessCategory.artCreative:
        return Icons.palette_outlined;
      case BusinessCategory.construction:
        return Icons.construction_outlined;
      case BusinessCategory.agriculture:
        return Icons.grass_outlined;
      case BusinessCategory.manufacturing:
        return Icons.factory_outlined;
      case BusinessCategory.weddingEvents:
        return Icons.celebration_outlined;
      case BusinessCategory.other:
        return Icons.miscellaneous_services_outlined;
    }
  }

  /// Get the active icon for the primary content tab
  IconData get contentTabActiveIcon {
    switch (this) {
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        return Icons.inventory_2;
      case BusinessCategory.foodBeverage:
        return Icons.restaurant_menu;
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
        return Icons.hotel;
      case BusinessCategory.beautyWellness:
        return Icons.spa;
      case BusinessCategory.healthcare:
        return Icons.medical_services;
      case BusinessCategory.fitness:
        return Icons.fitness_center;
      case BusinessCategory.petServices:
        return Icons.pets;
      case BusinessCategory.homeServices:
        return Icons.home_repair_service;
      case BusinessCategory.automotive:
        return Icons.directions_car;
      case BusinessCategory.education:
        return Icons.school;
      case BusinessCategory.professionalServices:
        return Icons.business_center;
      case BusinessCategory.technologyIT:
        return Icons.computer;
      case BusinessCategory.legalServices:
        return Icons.gavel;
      case BusinessCategory.financialServices:
        return Icons.account_balance;
      case BusinessCategory.realEstate:
        return Icons.home_work;
      case BusinessCategory.entertainment:
        return Icons.theater_comedy;
      case BusinessCategory.transportation:
        return Icons.local_shipping;
      case BusinessCategory.artCreative:
        return Icons.palette;
      case BusinessCategory.construction:
        return Icons.construction;
      case BusinessCategory.agriculture:
        return Icons.grass;
      case BusinessCategory.manufacturing:
        return Icons.factory;
      case BusinessCategory.weddingEvents:
        return Icons.celebration;
      case BusinessCategory.other:
        return Icons.miscellaneous_services;
    }
  }

  /// Get category from business type string
  static BusinessCategory fromBusinessType(String? businessType) {
    if (businessType == null) return BusinessCategory.other;

    final type = businessType.toLowerCase();

    if (type.contains('retail') || type.contains('store')) {
      return BusinessCategory.retail;
    } else if (type.contains('grocery') || type.contains('supermarket') || type.contains('essentials')) {
      return BusinessCategory.grocery;
    } else if (type.contains('restaurant') || type.contains('cafe') || type.contains('food') || type.contains('beverage')) {
      return BusinessCategory.foodBeverage;
    } else if (type.contains('hotel') || type.contains('hospitality') || type.contains('lodge') || type.contains('resort')) {
      return BusinessCategory.hospitality;
    } else if (type.contains('beauty') || type.contains('wellness') || type.contains('salon') || type.contains('spa')) {
      return BusinessCategory.beautyWellness;
    } else if (type.contains('health') || type.contains('clinic') || type.contains('hospital') || type.contains('medical')) {
      return BusinessCategory.healthcare;
    } else if (type.contains('fitness') || type.contains('gym') || type.contains('sports')) {
      return BusinessCategory.fitness;
    } else if (type.contains('pet')) {
      return BusinessCategory.petServices;
    } else if (type.contains('home service') || type.contains('plumbing') || type.contains('electric')) {
      return BusinessCategory.homeServices;
    } else if (type.contains('auto') || type.contains('car') || type.contains('vehicle')) {
      return BusinessCategory.automotive;
    } else if (type.contains('education') || type.contains('school') || type.contains('training') || type.contains('tutor')) {
      return BusinessCategory.education;
    } else if (type.contains('professional') || type.contains('consulting')) {
      return BusinessCategory.professionalServices;
    } else if (type.contains('tech') || type.contains('it ') || type.contains('software')) {
      return BusinessCategory.technologyIT;
    } else if (type.contains('legal') || type.contains('law')) {
      return BusinessCategory.legalServices;
    } else if (type.contains('financial') || type.contains('accounting') || type.contains('bank')) {
      return BusinessCategory.financialServices;
    } else if (type.contains('real estate') || type.contains('property')) {
      return BusinessCategory.realEstate;
    } else if (type.contains('travel') || type.contains('tourism') || type.contains('tour')) {
      return BusinessCategory.travelTourism;
    } else if (type.contains('entertainment') || type.contains('media') || type.contains('event')) {
      return BusinessCategory.entertainment;
    } else if (type.contains('transport') || type.contains('logistics') || type.contains('delivery')) {
      return BusinessCategory.transportation;
    } else if (type.contains('art') || type.contains('creative') || type.contains('design')) {
      return BusinessCategory.artCreative;
    } else if (type.contains('construction') || type.contains('builder')) {
      return BusinessCategory.construction;
    } else if (type.contains('agriculture') || type.contains('farm') || type.contains('nursery')) {
      return BusinessCategory.agriculture;
    } else if (type.contains('manufacturing') || type.contains('factory')) {
      return BusinessCategory.manufacturing;
    } else if (type.contains('wedding') || type.contains('event plann')) {
      return BusinessCategory.weddingEvents;
    }

    return BusinessCategory.other;
  }
}

/// Configuration for category-specific terminology
class CategoryTerminology {
  final String screenTitle;
  final String filter1Label;
  final IconData filter1Icon;
  final String filter2Label;
  final IconData filter2Icon;
  final String emptyStateMessage;
  final String addButtonLabel;

  // Dashboard metrics labels
  final String metric1Label;
  final IconData metric1Icon;
  final String metric2Label;
  final IconData metric2Icon;
  final String metric3Label;
  final IconData metric3Icon;

  // Quick actions
  final List<QuickAction> quickActions;

  const CategoryTerminology({
    required this.screenTitle,
    required this.filter1Label,
    required this.filter1Icon,
    required this.filter2Label,
    required this.filter2Icon,
    required this.emptyStateMessage,
    required this.addButtonLabel,
    required this.metric1Label,
    required this.metric1Icon,
    required this.metric2Label,
    required this.metric2Icon,
    required this.metric3Label,
    required this.metric3Icon,
    required this.quickActions,
  });

  /// Get terminology for a category
  static CategoryTerminology getForCategory(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.retail:
        return _retailTerminology;
      case BusinessCategory.grocery:
        return _groceryTerminology;
      case BusinessCategory.foodBeverage:
        return _foodBeverageTerminology;
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
        return _hospitalityTerminology;
      case BusinessCategory.beautyWellness:
        return _beautyWellnessTerminology;
      case BusinessCategory.healthcare:
        return _healthcareTerminology;
      case BusinessCategory.fitness:
        return _fitnessTerminology;
      default:
        return _defaultTerminology;
    }
  }

  // Retail terminology
  static const _retailTerminology = CategoryTerminology(
    screenTitle: 'Products Catalog',
    filter1Label: 'Products',
    filter1Icon: Icons.inventory_2_outlined,
    filter2Label: 'Services',
    filter2Icon: Icons.handyman_outlined,
    emptyStateMessage: 'Start adding products to your catalog',
    addButtonLabel: 'Add Product',
    metric1Label: 'Orders',
    metric1Icon: Icons.shopping_bag_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Pending',
    metric3Icon: Icons.pending_outlined,
    quickActions: [
      QuickAction(icon: Icons.shopping_bag, label: 'Orders', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.inventory_2, label: 'Products', color: Colors.blue),
      QuickAction(icon: Icons.warehouse, label: 'Inventory', color: Colors.orange),
    ],
  );

  // Grocery terminology
  static const _groceryTerminology = CategoryTerminology(
    screenTitle: 'Grocery & Delivery',
    filter1Label: 'Groceries',
    filter1Icon: Icons.shopping_basket_outlined,
    filter2Label: 'Delivery',
    filter2Icon: Icons.local_shipping_outlined,
    emptyStateMessage: 'Start adding groceries for delivery',
    addButtonLabel: 'Add Item',
    metric1Label: 'Orders',
    metric1Icon: Icons.shopping_cart_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Pending',
    metric3Icon: Icons.pending_outlined,
    quickActions: [
      QuickAction(icon: Icons.shopping_cart, label: 'Orders', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.shopping_basket, label: 'Inventory', color: Colors.blue),
      QuickAction(icon: Icons.qr_code_2, label: 'QR Menu', color: Colors.purple),
    ],
  );

  // Food & Beverage terminology
  static const _foodBeverageTerminology = CategoryTerminology(
    screenTitle: 'Menu Management',
    filter1Label: 'Food',
    filter1Icon: Icons.restaurant_outlined,
    filter2Label: 'Drinks',
    filter2Icon: Icons.local_bar_outlined,
    emptyStateMessage: 'Start adding items to your menu',
    addButtonLabel: 'Add Menu Item',
    metric1Label: 'Orders',
    metric1Icon: Icons.receipt_long_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Kitchen',
    metric3Icon: Icons.soup_kitchen_outlined,
    quickActions: [
      QuickAction(icon: Icons.receipt_long, label: 'Orders', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.soup_kitchen, label: 'Kitchen', color: Colors.orange),
      QuickAction(icon: Icons.qr_code_2, label: 'QR Menu', color: Colors.purple),
    ],
  );

  // Hospitality terminology
  static const _hospitalityTerminology = CategoryTerminology(
    screenTitle: 'Room Management',
    filter1Label: 'Rooms',
    filter1Icon: Icons.hotel_outlined,
    filter2Label: 'Amenities',
    filter2Icon: Icons.room_service_outlined,
    emptyStateMessage: 'Start adding rooms to your property',
    addButtonLabel: 'Add Room',
    metric1Label: 'Bookings',
    metric1Icon: Icons.book_online_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Check-ins',
    metric3Icon: Icons.login_outlined,
    quickActions: [
      QuickAction(icon: Icons.book_online, label: 'Bookings', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.hotel, label: 'Room Status', color: Colors.blue),
      QuickAction(icon: Icons.people, label: 'Guests', color: Colors.purple),
    ],
  );

  // Beauty & Wellness terminology
  static const _beautyWellnessTerminology = CategoryTerminology(
    screenTitle: 'Services & Treatments',
    filter1Label: 'Services',
    filter1Icon: Icons.spa_outlined,
    filter2Label: 'Packages',
    filter2Icon: Icons.card_giftcard_outlined,
    emptyStateMessage: 'Start adding services and treatments',
    addButtonLabel: 'Add Service',
    metric1Label: 'Appointments',
    metric1Icon: Icons.event_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Today',
    metric3Icon: Icons.today_outlined,
    quickActions: [
      QuickAction(icon: Icons.calendar_month, label: 'Schedule', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.people, label: 'Staff', color: Colors.blue),
      QuickAction(icon: Icons.star, label: 'Reviews', color: Colors.amber),
    ],
  );

  // Healthcare terminology
  static const _healthcareTerminology = CategoryTerminology(
    screenTitle: 'Medical Services',
    filter1Label: 'Services',
    filter1Icon: Icons.medical_services_outlined,
    filter2Label: 'Procedures',
    filter2Icon: Icons.healing_outlined,
    emptyStateMessage: 'Start adding medical services',
    addButtonLabel: 'Add Service',
    metric1Label: 'Appointments',
    metric1Icon: Icons.event_outlined,
    metric2Label: 'Patients',
    metric2Icon: Icons.people_outlined,
    metric3Label: 'Records',
    metric3Icon: Icons.folder_outlined,
    quickActions: [
      QuickAction(icon: Icons.calendar_month, label: 'Appts', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.people, label: 'Patients', color: Colors.blue),
      QuickAction(icon: Icons.folder, label: 'Records', color: Colors.purple),
    ],
  );

  // Fitness terminology
  static const _fitnessTerminology = CategoryTerminology(
    screenTitle: 'Classes & Programs',
    filter1Label: 'Classes',
    filter1Icon: Icons.fitness_center_outlined,
    filter2Label: 'Programs',
    filter2Icon: Icons.assignment_outlined,
    emptyStateMessage: 'Start adding fitness classes',
    addButtonLabel: 'Add Class',
    metric1Label: 'Members',
    metric1Icon: Icons.card_membership_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Classes',
    metric3Icon: Icons.event_outlined,
    quickActions: [
      QuickAction(icon: Icons.calendar_month, label: 'Schedule', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.people, label: 'Members', color: Colors.blue),
      QuickAction(icon: Icons.fitness_center, label: 'Classes', color: Colors.orange),
    ],
  );

  // Default terminology
  static const _defaultTerminology = CategoryTerminology(
    screenTitle: 'Services & Products',
    filter1Label: 'Products',
    filter1Icon: Icons.inventory_2_outlined,
    filter2Label: 'Services',
    filter2Icon: Icons.handyman_outlined,
    emptyStateMessage: 'Start adding products or services',
    addButtonLabel: 'Add New',
    metric1Label: 'Inquiries',
    metric1Icon: Icons.inbox_outlined,
    metric2Label: 'Revenue',
    metric2Icon: Icons.currency_rupee_outlined,
    metric3Label: 'Pending',
    metric3Icon: Icons.pending_outlined,
    quickActions: [
      QuickAction(icon: Icons.inbox, label: 'Inquiries', color: Color(0xFF00D67D)),
      QuickAction(icon: Icons.inventory_2, label: 'Services', color: Colors.blue),
      QuickAction(icon: Icons.analytics, label: 'Analytics', color: Colors.purple),
    ],
  );
}

/// Quick action item for dashboard
class QuickAction {
  final IconData icon;
  final String label;
  final Color color;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}
