import 'package:flutter/material.dart';
import '../../models/archetype_type.dart';
import '../../models/business_category_config.dart';

/// Business Configuration Engine
/// Maps 24 business categories to 5 behavioral archetypes
/// Provides terminology and feature helpers for business logic
///
/// NOTE: The main business dashboard uses BusinessHomeTab which is driven by
/// BusinessDashboardConfig (using 10 CategoryGroups). The archetype system here
/// provides additional terminology and feature support helpers.
class BusinessConfig {
  /// Get archetype for a business category
  static ArchetypeType getArchetype(BusinessCategory category) {
    switch (category) {
      // ========== ARCHETYPE 1: RETAIL ==========
      case BusinessCategory.grocery:
      case BusinessCategory.retail:
        return ArchetypeType.retail;

      // ========== ARCHETYPE 2: MENU ==========
      case BusinessCategory.foodBeverage:
      case BusinessCategory.automotive:
        return ArchetypeType.menu;

      // ========== ARCHETYPE 3: APPOINTMENT ==========
      case BusinessCategory.beautyWellness:
      case BusinessCategory.healthcare:
      case BusinessCategory.education:
      case BusinessCategory.realEstate:
      case BusinessCategory.legal:
      case BusinessCategory.homeServices:
      case BusinessCategory.fitness:
      case BusinessCategory.petServices:
      case BusinessCategory.weddingEvents:
      case BusinessCategory.professional:
        return ArchetypeType.appointment;

      // ========== ARCHETYPE 4: HOSPITALITY ==========
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
        return ArchetypeType.hospitality;

      // ========== ARCHETYPE 5: PORTFOLIO ==========
      case BusinessCategory.construction:
      case BusinessCategory.technology:
      case BusinessCategory.artCreative:
      case BusinessCategory.entertainment:
      case BusinessCategory.transportation:
      case BusinessCategory.agriculture:
      case BusinessCategory.manufacturing:
        return ArchetypeType.portfolio;
    }
  }

  /// Get terminology for archetype (e.g., "Products" for retail, "Services" for menu)
  static String getItemsLabel(ArchetypeType archetype) {
    switch (archetype) {
      case ArchetypeType.retail:
        return 'Products';
      case ArchetypeType.menu:
        return 'Menu Items';
      case ArchetypeType.appointment:
        return 'Services';
      case ArchetypeType.hospitality:
        return 'Rooms';
      case ArchetypeType.portfolio:
        return 'Projects';
    }
  }

  /// Get transactions label (e.g., "Orders" for retail, "Bookings" for hospitality)
  static String getTransactionsLabel(ArchetypeType archetype) {
    switch (archetype) {
      case ArchetypeType.retail:
      case ArchetypeType.menu:
        return 'Orders';
      case ArchetypeType.appointment:
        return 'Appointments';
      case ArchetypeType.hospitality:
        return 'Bookings';
      case ArchetypeType.portfolio:
        return 'Quote Requests';
    }
  }

  /// Get icon for archetype
  static IconData getArchetypeIcon(ArchetypeType archetype) {
    switch (archetype) {
      case ArchetypeType.retail:
        return Icons.inventory_2;
      case ArchetypeType.menu:
        return Icons.restaurant_menu;
      case ArchetypeType.appointment:
        return Icons.calendar_today;
      case ArchetypeType.hospitality:
        return Icons.hotel;
      case ArchetypeType.portfolio:
        return Icons.work;
    }
  }

  /// Get color for archetype
  static Color getArchetypeColor(ArchetypeType archetype) {
    switch (archetype) {
      case ArchetypeType.retail:
        return const Color(0xFF10B981); // Green
      case ArchetypeType.menu:
        return const Color(0xFFF59E0B); // Amber
      case ArchetypeType.appointment:
        return const Color(0xFF3B82F6); // Blue
      case ArchetypeType.hospitality:
        return const Color(0xFF6366F1); // Indigo
      case ArchetypeType.portfolio:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  /// Check if category supports specific feature
  static bool supportsFeature(BusinessCategory category, String feature) {
    final archetype = getArchetype(category);

    switch (feature) {
      case 'inventory':
        return archetype == ArchetypeType.retail;
      case 'menu':
        return archetype == ArchetypeType.menu;
      case 'appointments':
        return archetype == ArchetypeType.appointment ||
            archetype == ArchetypeType.menu;
      case 'bookings':
        return archetype == ArchetypeType.hospitality;
      case 'portfolio':
        return archetype == ArchetypeType.portfolio;
      case 'orders':
        return archetype == ArchetypeType.retail ||
            archetype == ArchetypeType.menu;
      case 'rooms':
        return archetype == ArchetypeType.hospitality;
      case 'staff':
        return archetype == ArchetypeType.appointment ||
            archetype == ArchetypeType.menu ||
            archetype == ArchetypeType.hospitality;
      default:
        return false;
    }
  }
}

