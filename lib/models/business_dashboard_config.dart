import 'package:flutter/material.dart';
import 'business_category_config.dart';

/// ============================================================================
/// UNIFIED BUSINESS DASHBOARD CONFIGURATION
/// ============================================================================
///
/// This is the SINGLE SOURCE OF TRUTH for all business dashboard configurations.
/// The system uses 10 CategoryGroups to provide appropriate stats, quick actions,
/// and terminology for all 23+ business categories.
///
/// Architecture:
/// - BusinessMainScreen -> BusinessHomeTab -> BusinessDashboardConfig
/// - BusinessHomeTab renders the unified dashboard for ALL business types
/// - This config provides category-specific stats, actions, and labels
///
/// CategoryGroup mapping (10 groups covering 23 categories):
/// - food: Restaurant, Cafe, Bakery, Food Truck
/// - retail: Retail, Grocery stores
/// - hospitality: Hotels, Resorts, Travel
/// - services: Beauty, Healthcare, Legal, Home Services, Pet Services
/// - fitness: Gyms, Yoga studios, Sports
/// - education: Schools, Training centers, Tutoring
/// - professional: Consultants, Agencies, Technology
/// - creative: Art, Photography, Design Studios
/// - events: Entertainment, Wedding & Events
/// - construction: Contractors, Interior Design, Architecture
/// ============================================================================

/// Dashboard stat item configuration
class DashboardStat {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(DashboardData data) getValue;
  final String? route;

  const DashboardStat({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.getValue,
    this.route,
  });
}

/// Quick action configuration
class QuickAction {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const QuickAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

/// Dashboard data model for stats
class DashboardData {
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int todayOrders;
  final int newInquiries;
  final int respondedInquiries;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final int totalItems;
  final int lowStockItems;
  final int todayAppointments;
  final int pendingAppointments;
  final int availableRooms;
  final int totalRooms;
  final int todayCheckIns;
  final int todayCheckOuts;
  final int preparingOrders;
  final int deliveryOrders;

  // Trend data (percentage change from yesterday)
  final double? ordersTrend;
  final double? revenueTrend;
  final double? appointmentsTrend;

  // Historical data for charts (last 7 days)
  final List<double> revenueHistory;
  final List<double> ordersHistory;

  const DashboardData({
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.todayOrders = 0,
    this.newInquiries = 0,
    this.respondedInquiries = 0,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.totalItems = 0,
    this.lowStockItems = 0,
    this.todayAppointments = 0,
    this.pendingAppointments = 0,
    this.availableRooms = 0,
    this.totalRooms = 0,
    this.todayCheckIns = 0,
    this.todayCheckOuts = 0,
    this.preparingOrders = 0,
    this.deliveryOrders = 0,
    this.ordersTrend,
    this.revenueTrend,
    this.appointmentsTrend,
    this.revenueHistory = const [],
    this.ordersHistory = const [],
  });
}

/// Category group for dashboard configuration
/// These 10 groups cover all 23 BusinessCategory types with shared UI patterns
enum CategoryGroup {
  food,        // foodBeverage -> Restaurant, Cafe, Bakery, Food Truck
  retail,      // retail, grocery -> Shops, Supermarkets, Stores
  hospitality, // hospitality, travelTourism -> Hotels, Resorts, Travel
  services,    // beautyWellness, healthcare, automotive, homeServices, petServices, realEstate, legal, transportation -> Service-based businesses
  fitness,     // fitness -> Gyms, Yoga studios, Sports
  education,   // education -> Schools, Training centers, Tutoring
  professional,// professional, technology -> Consultants, Agencies, IT
  creative,    // artCreative -> Art, Photography, Design Studios
  events,      // entertainment, weddingEvents -> Events, Weddings
  construction,// construction, agriculture, manufacturing -> Projects, Production
}

/// Get category group from BusinessCategory
CategoryGroup getCategoryGroup(BusinessCategory? category) {
  if (category == null) return CategoryGroup.services;

  switch (category) {
    case BusinessCategory.foodBeverage:
      return CategoryGroup.food;
    case BusinessCategory.retail:
    case BusinessCategory.grocery:
      return CategoryGroup.retail;
    case BusinessCategory.hospitality:
    case BusinessCategory.travelTourism:
      return CategoryGroup.hospitality;
    case BusinessCategory.fitness:
      return CategoryGroup.fitness;
    case BusinessCategory.education:
      return CategoryGroup.education;
    case BusinessCategory.professional:
    case BusinessCategory.technology:
      return CategoryGroup.professional;
    case BusinessCategory.artCreative:
      return CategoryGroup.creative;
    case BusinessCategory.entertainment:
    case BusinessCategory.weddingEvents:
      return CategoryGroup.events;
    case BusinessCategory.construction:
      return CategoryGroup.construction;
    case BusinessCategory.beautyWellness:
    case BusinessCategory.healthcare:
    case BusinessCategory.automotive:
    case BusinessCategory.homeServices:
    case BusinessCategory.petServices:
    case BusinessCategory.realEstate:
    case BusinessCategory.legal:
    case BusinessCategory.transportation:
    case BusinessCategory.agriculture:
    case BusinessCategory.manufacturing:
      return CategoryGroup.services;
  }
}

/// Dashboard configuration for each category group
class BusinessDashboardConfig {
  /// Get stats for a category group
  static List<DashboardStat> getStats(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return _foodStats;
      case CategoryGroup.retail:
        return _retailStats;
      case CategoryGroup.hospitality:
        return _hospitalityStats;
      case CategoryGroup.fitness:
        return _fitnessStats;
      case CategoryGroup.education:
        return _educationStats;
      case CategoryGroup.professional:
        return _professionalStats;
      case CategoryGroup.services:
        return _serviceStats;
      case CategoryGroup.creative:
        return _creativeStats;
      case CategoryGroup.events:
        return _eventsStats;
      case CategoryGroup.construction:
        return _constructionStats;
    }
  }

  /// Get quick actions for a category group
  static List<QuickAction> getQuickActions(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return _foodActions;
      case CategoryGroup.retail:
        return _retailActions;
      case CategoryGroup.hospitality:
        return _hospitalityActions;
      case CategoryGroup.fitness:
        return _fitnessActions;
      case CategoryGroup.education:
        return _educationActions;
      case CategoryGroup.professional:
        return _professionalActions;
      case CategoryGroup.services:
        return _serviceActions;
      case CategoryGroup.creative:
        return _creativeActions;
      case CategoryGroup.events:
        return _eventsActions;
      case CategoryGroup.construction:
        return _constructionActions;
    }
  }

  /// Get title for stats section
  static String getStatsTitle(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return "Today's Kitchen";
      case CategoryGroup.retail:
        return "Store Overview";
      case CategoryGroup.hospitality:
        return "Property Status";
      case CategoryGroup.fitness:
        return "Today's Activity";
      case CategoryGroup.education:
        return "Today's Schedule";
      case CategoryGroup.professional:
        return "Work Overview";
      case CategoryGroup.services:
        return "Today's Snapshot";
      case CategoryGroup.creative:
        return "Studio Overview";
      case CategoryGroup.events:
        return "Event Overview";
      case CategoryGroup.construction:
        return "Project Overview";
    }
  }

  /// Get title for revenue card
  static String getRevenueTitle(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return "Kitchen Revenue";
      case CategoryGroup.retail:
        return "Store Revenue";
      case CategoryGroup.hospitality:
        return "Property Revenue";
      case CategoryGroup.fitness:
        return "Membership Revenue";
      case CategoryGroup.education:
        return "Course Revenue";
      case CategoryGroup.professional:
        return "Project Revenue";
      case CategoryGroup.services:
        return "Service Revenue";
      case CategoryGroup.creative:
        return "Studio Revenue";
      case CategoryGroup.events:
        return "Event Revenue";
      case CategoryGroup.construction:
        return "Project Revenue";
    }
  }

  /// Get activity section title
  static String getActivityTitle(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return "Kitchen Activity";
      case CategoryGroup.retail:
        return "Store Activity";
      case CategoryGroup.hospitality:
        return "Property Activity";
      case CategoryGroup.fitness:
        return "Member Activity";
      case CategoryGroup.education:
        return "Class Activity";
      case CategoryGroup.professional:
        return "Project Activity";
      case CategoryGroup.services:
        return "Service Activity";
      case CategoryGroup.creative:
        return "Studio Activity";
      case CategoryGroup.events:
        return "Event Activity";
      case CategoryGroup.construction:
        return "Project Activity";
    }
  }

  /// Get activity type labels for a category group
  static String getActivityLabel(CategoryGroup group, String activityType) {
    switch (group) {
      case CategoryGroup.food:
        switch (activityType) {
          case 'order':
            return 'New Order';
          case 'completed':
            return 'Order Completed';
          case 'delivery':
            return 'Out for Delivery';
          default:
            return 'Activity';
        }
      case CategoryGroup.retail:
        switch (activityType) {
          case 'order':
            return 'Product Sold';
          case 'completed':
            return 'Sale Completed';
          case 'inventory':
            return 'Inventory Updated';
          default:
            return 'Activity';
        }
      case CategoryGroup.hospitality:
        switch (activityType) {
          case 'booking':
            return 'New Booking';
          case 'checkin':
            return 'Guest Checked In';
          case 'checkout':
            return 'Guest Checked Out';
          default:
            return 'Activity';
        }
      case CategoryGroup.fitness:
        switch (activityType) {
          case 'booking':
            return 'Class Booked';
          case 'checkin':
            return 'Member Check-in';
          case 'completed':
            return 'Session Completed';
          default:
            return 'Activity';
        }
      case CategoryGroup.education:
        switch (activityType) {
          case 'booking':
            return 'New Enrollment';
          case 'checkin':
            return 'Attendance Marked';
          case 'completed':
            return 'Class Completed';
          default:
            return 'Activity';
        }
      case CategoryGroup.professional:
        switch (activityType) {
          case 'booking':
            return 'New Project';
          case 'meeting':
            return 'Meeting Scheduled';
          case 'completed':
            return 'Milestone Completed';
          default:
            return 'Activity';
        }
      case CategoryGroup.services:
        switch (activityType) {
          case 'booking':
            return 'New Appointment';
          case 'message':
            return 'Inquiry Received';
          case 'completed':
            return 'Service Completed';
          default:
            return 'Activity';
        }
      case CategoryGroup.creative:
        switch (activityType) {
          case 'booking':
            return 'New Commission';
          case 'message':
            return 'Inquiry Received';
          case 'completed':
            return 'Project Delivered';
          default:
            return 'Activity';
        }
      case CategoryGroup.events:
        switch (activityType) {
          case 'booking':
            return 'New Event Booking';
          case 'inquiry':
            return 'Event Inquiry';
          case 'completed':
            return 'Event Completed';
          default:
            return 'Activity';
        }
      case CategoryGroup.construction:
        switch (activityType) {
          case 'booking':
            return 'New Project Request';
          case 'quote':
            return 'Quote Sent';
          case 'completed':
            return 'Project Completed';
          default:
            return 'Activity';
        }
    }
  }

  // ============ FOOD & BEVERAGE STATS ============
  static final List<DashboardStat> _foodStats = [
    DashboardStat(
      id: 'orders',
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF42A5F5),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
    DashboardStat(
      id: 'preparing',
      label: 'Preparing',
      icon: Icons.restaurant,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.preparingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'delivery',
      label: 'Delivery',
      icon: Icons.delivery_dining,
      color: const Color(0xFF7E57C2),
      getValue: (data) => '${data.deliveryOrders}',
      route: 'orders',
    ),
  ];

  // ============ RETAIL STATS ============
  static final List<DashboardStat> _retailStats = [
    DashboardStat(
      id: 'orders',
      label: 'Orders',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF42A5F5),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
    DashboardStat(
      id: 'lowStock',
      label: 'Low Stock',
      icon: Icons.warning_amber_outlined,
      color: const Color(0xFFEF5350),
      getValue: (data) => '${data.lowStockItems}',
      route: 'products',
    ),
    DashboardStat(
      id: 'items',
      label: 'In Stock',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF66BB6A),
      getValue: (data) => '${data.totalItems}',
      route: 'products',
    ),
  ];

  // ============ HOSPITALITY STATS ============
  static final List<DashboardStat> _hospitalityStats = [
    DashboardStat(
      id: 'checkIns',
      label: 'Check-ins',
      icon: Icons.login_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'checkOuts',
      label: 'Check-outs',
      icon: Icons.logout_outlined,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.todayCheckOuts}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'rooms',
      label: 'Available',
      icon: Icons.hotel_outlined,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.availableRooms}/${data.totalRooms}',
      route: 'rooms',
    ),
    DashboardStat(
      id: 'bookings',
      label: 'Bookings',
      icon: Icons.calendar_month_outlined,
      color: const Color(0xFF7E57C2),
      getValue: (data) => '${data.pendingOrders}',
      route: 'bookings',
    ),
  ];

  // ============ SERVICE STATS (Beauty, Healthcare, Legal, etc.) ============
  static final List<DashboardStat> _serviceStats = [
    DashboardStat(
      id: 'appointments',
      label: 'Appointments',
      icon: Icons.calendar_today_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'appointments',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'completed',
      label: 'Completed',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.completedOrders}',
      route: 'history',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ FITNESS STATS ============
  static final List<DashboardStat> _fitnessStats = [
    DashboardStat(
      id: 'classes',
      label: 'Classes',
      icon: Icons.fitness_center,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'classes',
    ),
    DashboardStat(
      id: 'members',
      label: 'Check-ins',
      icon: Icons.people_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'members',
    ),
    DashboardStat(
      id: 'bookings',
      label: 'Bookings',
      icon: Icons.event_available,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.pendingOrders}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ EDUCATION STATS ============
  static final List<DashboardStat> _educationStats = [
    DashboardStat(
      id: 'classes',
      label: 'Classes',
      icon: Icons.school_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'classes',
    ),
    DashboardStat(
      id: 'students',
      label: 'Attendance',
      icon: Icons.people_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'attendance',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ PROFESSIONAL STATS ============
  static final List<DashboardStat> _professionalStats = [
    DashboardStat(
      id: 'projects',
      label: 'Projects',
      icon: Icons.work_outline,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'projects',
    ),
    DashboardStat(
      id: 'meetings',
      label: 'Meetings',
      icon: Icons.videocam_outlined,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayAppointments}',
      route: 'meetings',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ CREATIVE STATS ============
  static final List<DashboardStat> _creativeStats = [
    DashboardStat(
      id: 'commissions',
      label: 'Commissions',
      icon: Icons.palette_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'commissions',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'completed',
      label: 'Delivered',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.completedOrders}',
      route: 'history',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ EVENTS STATS ============
  static final List<DashboardStat> _eventsStats = [
    DashboardStat(
      id: 'bookings',
      label: 'Bookings',
      icon: Icons.event_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'upcoming',
      label: 'Upcoming',
      icon: Icons.calendar_month_outlined,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayAppointments}',
      route: 'calendar',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ CONSTRUCTION STATS ============
  static final List<DashboardStat> _constructionStats = [
    DashboardStat(
      id: 'projects',
      label: 'Projects',
      icon: Icons.construction_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'projects',
    ),
    DashboardStat(
      id: 'quotes',
      label: 'Quotes',
      icon: Icons.request_quote_outlined,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'quotes',
    ),
    DashboardStat(
      id: 'completed',
      label: 'Completed',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.completedOrders}',
      route: 'history',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ FOOD QUICK ACTIONS ============
  static const List<QuickAction> _foodActions = [
    QuickAction(
      id: 'orders',
      label: 'View Orders',
      subtitle: 'Manage orders',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF00D67D),
      route: 'orders',
    ),
    QuickAction(
      id: 'menu',
      label: 'Edit Menu',
      subtitle: 'Menu items',
      icon: Icons.restaurant_menu,
      color: Color(0xFFFFA726),
      route: 'menu',
    ),
    QuickAction(
      id: 'tables',
      label: 'Tables',
      subtitle: 'Reservations',
      icon: Icons.table_restaurant,
      color: Color(0xFF42A5F5),
      route: 'tables',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ RETAIL QUICK ACTIONS ============
  static const List<QuickAction> _retailActions = [
    QuickAction(
      id: 'orders',
      label: 'View Orders',
      subtitle: 'Manage orders',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF00D67D),
      route: 'orders',
    ),
    QuickAction(
      id: 'products',
      label: 'Products',
      subtitle: 'Inventory',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF42A5F5),
      route: 'products',
    ),
    QuickAction(
      id: 'add',
      label: 'Add Product',
      subtitle: 'New listing',
      icon: Icons.add_box_outlined,
      color: Color(0xFFFFA726),
      route: 'add_product',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ HOSPITALITY QUICK ACTIONS ============
  static const List<QuickAction> _hospitalityActions = [
    QuickAction(
      id: 'checkin',
      label: 'Check-in',
      subtitle: "Today's arrivals",
      icon: Icons.login_outlined,
      color: Color(0xFF00D67D),
      route: 'checkins',
    ),
    QuickAction(
      id: 'checkout',
      label: 'Check-out',
      subtitle: "Today's departures",
      icon: Icons.logout_outlined,
      color: Color(0xFFFFA726),
      route: 'checkouts',
    ),
    QuickAction(
      id: 'rooms',
      label: 'Manage Rooms',
      subtitle: 'Room status',
      icon: Icons.hotel_outlined,
      color: Color(0xFF42A5F5),
      route: 'rooms',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ SERVICE QUICK ACTIONS ============
  static const List<QuickAction> _serviceActions = [
    QuickAction(
      id: 'appointments',
      label: 'Appointments',
      subtitle: 'View schedule',
      icon: Icons.calendar_today_outlined,
      color: Color(0xFF00D67D),
      route: 'appointments',
    ),
    QuickAction(
      id: 'services',
      label: 'Services',
      subtitle: 'Offerings',
      icon: Icons.build_outlined,
      color: Color(0xFF42A5F5),
      route: 'services',
    ),
    QuickAction(
      id: 'clients',
      label: 'Clients',
      subtitle: 'Customer list',
      icon: Icons.people_outline,
      color: Color(0xFFFFA726),
      route: 'clients',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ FITNESS QUICK ACTIONS ============
  static const List<QuickAction> _fitnessActions = [
    QuickAction(
      id: 'classes',
      label: 'Classes',
      subtitle: 'View schedule',
      icon: Icons.fitness_center,
      color: Color(0xFF00D67D),
      route: 'classes',
    ),
    QuickAction(
      id: 'members',
      label: 'Members',
      subtitle: 'Memberships',
      icon: Icons.card_membership,
      color: Color(0xFF42A5F5),
      route: 'members',
    ),
    QuickAction(
      id: 'checkins',
      label: 'Check-ins',
      subtitle: "Today's visits",
      icon: Icons.login_outlined,
      color: Color(0xFFFFA726),
      route: 'checkins',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ EDUCATION QUICK ACTIONS ============
  static const List<QuickAction> _educationActions = [
    QuickAction(
      id: 'courses',
      label: 'Courses',
      subtitle: 'Course catalog',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF00D67D),
      route: 'courses',
    ),
    QuickAction(
      id: 'enrollments',
      label: 'Enrollments',
      subtitle: 'Student list',
      icon: Icons.people_outline,
      color: Color(0xFF42A5F5),
      route: 'enrollments',
    ),
    QuickAction(
      id: 'attendance',
      label: 'Attendance',
      subtitle: 'Mark present',
      icon: Icons.fact_check_outlined,
      color: Color(0xFFFFA726),
      route: 'attendance',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ PROFESSIONAL QUICK ACTIONS ============
  static const List<QuickAction> _professionalActions = [
    QuickAction(
      id: 'projects',
      label: 'Projects',
      subtitle: 'Active work',
      icon: Icons.work_outline,
      color: Color(0xFF00D67D),
      route: 'projects',
    ),
    QuickAction(
      id: 'portfolio',
      label: 'Portfolio',
      subtitle: 'Showcase',
      icon: Icons.collections_outlined,
      color: Color(0xFF42A5F5),
      route: 'portfolio',
    ),
    QuickAction(
      id: 'clients',
      label: 'Clients',
      subtitle: 'Client list',
      icon: Icons.people_outline,
      color: Color(0xFFFFA726),
      route: 'clients',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ CREATIVE QUICK ACTIONS ============
  static const List<QuickAction> _creativeActions = [
    QuickAction(
      id: 'portfolio',
      label: 'Portfolio',
      subtitle: 'Showcase work',
      icon: Icons.collections_outlined,
      color: Color(0xFF00D67D),
      route: 'portfolio',
    ),
    QuickAction(
      id: 'commissions',
      label: 'Commissions',
      subtitle: 'Requests',
      icon: Icons.palette_outlined,
      color: Color(0xFF42A5F5),
      route: 'commissions',
    ),
    QuickAction(
      id: 'gallery',
      label: 'Gallery',
      subtitle: 'Manage images',
      icon: Icons.photo_library_outlined,
      color: Color(0xFFFFA726),
      route: 'gallery',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ EVENTS QUICK ACTIONS ============
  static const List<QuickAction> _eventsActions = [
    QuickAction(
      id: 'bookings',
      label: 'Bookings',
      subtitle: 'Event bookings',
      icon: Icons.event_outlined,
      color: Color(0xFF00D67D),
      route: 'bookings',
    ),
    QuickAction(
      id: 'packages',
      label: 'Packages',
      subtitle: 'Event packages',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF42A5F5),
      route: 'packages',
    ),
    QuickAction(
      id: 'calendar',
      label: 'Calendar',
      subtitle: 'Schedule',
      icon: Icons.calendar_month_outlined,
      color: Color(0xFFFFA726),
      route: 'calendar',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  // ============ CONSTRUCTION QUICK ACTIONS ============
  static const List<QuickAction> _constructionActions = [
    QuickAction(
      id: 'projects',
      label: 'Projects',
      subtitle: 'Active work',
      icon: Icons.construction_outlined,
      color: Color(0xFF00D67D),
      route: 'projects',
    ),
    QuickAction(
      id: 'quotes',
      label: 'Quotes',
      subtitle: 'Requests',
      icon: Icons.request_quote_outlined,
      color: Color(0xFF42A5F5),
      route: 'quotes',
    ),
    QuickAction(
      id: 'portfolio',
      label: 'Portfolio',
      subtitle: 'Past work',
      icon: Icons.collections_outlined,
      color: Color(0xFFFFA726),
      route: 'portfolio',
    ),
    QuickAction(
      id: 'analytics',
      label: 'Analytics',
      subtitle: 'View insights',
      icon: Icons.analytics_outlined,
      color: Color(0xFF7E57C2),
      route: 'analytics',
    ),
  ];

  /// Format currency
  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
