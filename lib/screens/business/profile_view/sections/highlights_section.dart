import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';

/// Section showing category-specific highlight chips
/// (e.g., cuisines for restaurants, services for salons)
class HighlightsSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const HighlightsSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final highlights = _getHighlights();

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: highlights.map((highlight) {
          return _HighlightChip(
            label: highlight.label,
            icon: highlight.icon,
            color: highlight.color ?? config.primaryColor,
            isDarkMode: isDarkMode,
          );
        }).toList(),
      ),
    );
  }

  List<_Highlight> _getHighlights() {
    final highlights = <_Highlight>[];
    final categoryData = business.categoryData ?? {};

    for (final field in config.highlightFields) {
      final value = categoryData[field];

      if (value == null) continue;

      if (value is List) {
        for (final item in value) {
          if (item is String && item.isNotEmpty) {
            highlights.add(_Highlight(
              label: item,
              icon: _getIconForField(field),
              color: _getColorForValue(field, item),
            ));
          }
        }
      } else if (value is String && value.isNotEmpty) {
        highlights.add(_Highlight(
          label: value,
          icon: _getIconForField(field),
          color: _getColorForValue(field, value),
        ));
      }
    }

    // Add hours status
    if (business.hours != null) {
      final isOpen = business.hours!.isCurrentlyOpen;
      highlights.insert(
        0,
        _Highlight(
          label: isOpen ? 'Open Now' : 'Closed',
          icon: Icons.access_time,
          color: isOpen ? Colors.green : Colors.red,
        ),
      );
    }

    return highlights;
  }

  IconData _getIconForField(String field) {
    switch (field) {
      case 'cuisineTypes':
        return Icons.restaurant;
      case 'foodType':
        return Icons.eco;
      case 'diningOptions':
        return Icons.storefront;
      case 'serviceCategories':
        return Icons.content_cut;
      case 'genderServed':
        return Icons.people;
      case 'bookingType':
        return Icons.calendar_today;
      case 'specializations':
        return Icons.medical_services;
      case 'appointmentType':
        return Icons.schedule;
      case 'amenities':
        return Icons.star;
      case 'checkInTime':
      case 'checkOutTime':
        return Icons.access_time;
      case 'propertyTypes':
        return Icons.apartment;
      case 'servicesType':
        return Icons.home_repair_service;
      case 'productCategories':
        return Icons.category;
      case 'orderOptions':
        return Icons.shopping_bag;
      case 'deliveryOptions':
        return Icons.local_shipping;
      case 'activities':
        return Icons.fitness_center;
      case 'membershipType':
        return Icons.card_membership;
      case 'subjects':
        return Icons.menu_book;
      case 'classType':
        return Icons.groups;
      case 'vehicleTypes':
        return Icons.directions_car;
      case 'servicesOffered':
        return Icons.build;
      case 'tourTypes':
        return Icons.tour;
      case 'expertise':
        return Icons.psychology;
      case 'clientType':
        return Icons.business;
      case 'creativeServices':
        return Icons.palette;
      case 'eventTypes':
        return Icons.celebration;
      case 'serviceTypes':
        return Icons.handyman;
      case 'serviceArea':
        return Icons.map;
      case 'eventServices':
        return Icons.event;
      default:
        return Icons.label;
    }
  }

  Color? _getColorForValue(String field, String value) {
    // Special colors for certain values
    if (field == 'foodType') {
      if (value.toLowerCase().contains('veg') &&
          !value.toLowerCase().contains('non')) {
        return Colors.green;
      } else if (value.toLowerCase().contains('non-veg') ||
          value.toLowerCase().contains('non veg')) {
        return Colors.red;
      }
    }

    if (field == 'genderServed') {
      if (value.toLowerCase() == 'men') return Colors.blue;
      if (value.toLowerCase() == 'women') return Colors.pink;
      if (value.toLowerCase() == 'unisex') return Colors.purple;
    }

    return null; // Use default color
  }
}

class _Highlight {
  final String label;
  final IconData icon;
  final Color? color;

  _Highlight({
    required this.label,
    required this.icon,
    this.color,
  });
}

class _HighlightChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  const _HighlightChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// About section with business description
class AboutSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const AboutSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (business.description == null || business.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            business.description!,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          if (business.yearEstablished != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  'Established ${business.yearEstablished}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
