import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';

/// Service item model for display
class ServiceItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int? duration; // in minutes
  final String? category;
  final bool isAvailable;

  ServiceItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.duration,
    this.category,
    this.isAvailable = true,
  });

  factory ServiceItem.fromMap(Map<String, dynamic> map, String id) {
    return ServiceItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      duration: map['duration'],
      category: map['category'],
      isAvailable: map['isAvailable'] ?? true,
    );
  }
}

/// Section displaying services for salons, healthcare, etc.
class ServicesSection extends StatelessWidget {
  final String businessId;
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBookService;

  const ServicesSection({
    super.key,
    required this.businessId,
    required this.business,
    required this.config,
    this.onBookService,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // For now, use the services list from business model
    // In production, this would stream from Firestore subcollection
    final services = business.services;

    if (services.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDarkMode),
        ...services.map((service) => _ServiceCard(
              serviceName: service,
              config: config,
              isDarkMode: isDarkMode,
              onBook: onBookService,
            )),
      ],
    );
  }

  Widget _buildSectionHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            config.primarySectionIcon,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            config.primarySectionTitle,
            style: TextStyle(
              fontSize: AppTheme.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text(
              config.emptyStateIcon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              config.emptyStateMessage,
              style: TextStyle(
                color: AppTheme.secondaryText(isDarkMode),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String serviceName;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onBook;

  const _ServiceCard({
    required this.serviceName,
    required this.config,
    required this.isDarkMode,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getServiceIcon(serviceName),
              color: config.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (onBook != null)
            TextButton(
              onPressed: onBook,
              style: TextButton.styleFrom(
                foregroundColor: config.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Book'),
            ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    final lower = service.toLowerCase();

    // Beauty & Wellness
    if (lower.contains('hair')) return Icons.content_cut;
    if (lower.contains('facial')) return Icons.face;
    if (lower.contains('massage')) return Icons.spa;
    if (lower.contains('nail')) return Icons.pan_tool;
    if (lower.contains('makeup')) return Icons.brush;
    if (lower.contains('wax')) return Icons.remove;

    // Healthcare
    if (lower.contains('consult')) return Icons.medical_services;
    if (lower.contains('dental')) return Icons.medical_services;
    if (lower.contains('eye')) return Icons.visibility;
    if (lower.contains('therapy')) return Icons.healing;
    if (lower.contains('checkup')) return Icons.favorite;

    // Fitness
    if (lower.contains('personal')) return Icons.fitness_center;
    if (lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('class')) return Icons.groups;

    // Home Services
    if (lower.contains('plumb')) return Icons.plumbing;
    if (lower.contains('electric')) return Icons.electrical_services;
    if (lower.contains('clean')) return Icons.cleaning_services;
    if (lower.contains('ac') || lower.contains('air')) return Icons.ac_unit;
    if (lower.contains('paint')) return Icons.format_paint;

    // Automotive
    if (lower.contains('service') && lower.contains('car')) return Icons.car_repair;
    if (lower.contains('wash')) return Icons.local_car_wash;
    if (lower.contains('repair')) return Icons.build;

    return Icons.miscellaneous_services;
  }
}

/// Detailed service card with pricing and duration
class ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onBook;

  const ServiceCard({
    super.key,
    required this.service,
    required this.config,
    required this.isDarkMode,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: 6),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText(isDarkMode),
                  ),
                ),
                if (service.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText(isDarkMode),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: config.primaryColor,
                      ),
                    ),
                    if (service.duration != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${service.duration} min',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onBook != null && service.isAvailable) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: config.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (!service.isAvailable) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unavailable',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
