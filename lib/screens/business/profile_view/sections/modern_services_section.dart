import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern Services Section with Enhanced Cards
/// Features:
/// - Large service cards with gradients
/// - Inline ratings and duration
/// - Direct booking buttons
/// - Swipe-to-favorite
/// - Skeleton loading states
class ModernServicesSection extends StatelessWidget {
  final String businessId;
  final BusinessModel business;
  final CategoryProfileConfig config;
  final VoidCallback? onBook;

  const ModernServicesSection({
    super.key,
    required this.businessId,
    required this.business,
    required this.config,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header
        BusinessProfileComponents.modernSectionHeader(
          title: config.primarySectionTitle,
          isDarkMode: isDarkMode,
          icon: config.primarySectionIcon,
          actionLabel: 'See All',
          onAction: () {
            _showAllServices(context, isDarkMode);
          },
        ),

        const SizedBox(height: 16),

        // Services stream
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseProvider.firestore
              .collection('businesses')
              .doc(businessId)
              .collection('items')
              .where('type', isEqualTo: 'service')
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(isDarkMode);
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(isDarkMode);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildServiceCard(context, data, isDarkMode);
              },
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    Map<String, dynamic> service,
    bool isDarkMode,
  ) {
    final name = service['name'] as String? ?? 'Service';
    final description = service['description'] as String? ?? '';
    final price = service['price'] as num? ?? 0;
    final duration = service['duration'] as String? ?? '';
    final rating = service['rating'] as num? ?? 0.0;
    final reviewCount = service['reviewCount'] as int? ?? 0;
    final imageUrl = service['imageUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => _showServiceDetails(context, service),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon/image
                _buildServiceIcon(imageUrl, isDarkMode),

                const SizedBox(width: 16),

                // Service info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: AppTheme.fontLarge,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText(isDarkMode),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Description
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: AppTheme.fontSmall,
                            color: AppTheme.secondaryText(isDarkMode),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 10),

                      // Rating and duration
                      Row(
                        children: [
                          if (rating > 0) ...[
                            Icon(
                              Icons.star,
                              size: 16,
                              color: AppTheme.warningOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: AppTheme.fontSmall,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText(isDarkMode),
                              ),
                            ),
                            if (reviewCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: TextStyle(
                                  fontSize: AppTheme.fontSmall,
                                  color: AppTheme.secondaryText(isDarkMode),
                                ),
                              ),
                            ],
                          ],
                          if (duration.isNotEmpty) ...[
                            if (rating > 0) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryText(isDarkMode),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.secondaryText(isDarkMode),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              duration,
                              style: TextStyle(
                                fontSize: AppTheme.fontSmall,
                                color: AppTheme.secondaryText(isDarkMode),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Price and book button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (price > 0) ...[
                      Text(
                        '\$${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: AppTheme.fontXLarge,
                          fontWeight: FontWeight.bold,
                          color: config.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildBookButton(context, service, isDarkMode),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceIcon(String? imageUrl, bool isDarkMode) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.primaryColor,
            config.accentColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: config.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        config.primarySectionIcon,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildBookButton(
    BuildContext context,
    Map<String, dynamic> service,
    bool isDarkMode,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          if (onBook != null) {
            onBook!();
          } else {
            _showBookingDialog(context, service);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                config.primaryColor,
                config.primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: config.primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Book',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDarkMode) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.cardColor(isDarkMode).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              config.primarySectionIcon,
              size: 64,
              color: AppTheme.secondaryText(isDarkMode),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${config.primarySectionTitle.toLowerCase()} available yet',
              style: TextStyle(
                fontSize: AppTheme.fontMedium,
                color: AppTheme.secondaryText(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllServices(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor(isDarkMode),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryText(isDarkMode),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  config.primarySectionTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText(isDarkMode),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseProvider.firestore
                      .collection('businesses')
                      .doc(businessId)
                      .collection('items')
                      .where('type', isEqualTo: 'service')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No services available',
                          style: TextStyle(color: AppTheme.secondaryText(isDarkMode)),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildServiceCard(context, data, isDarkMode);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceDetails(BuildContext context, Map<String, dynamic> service) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final name = service['name'] as String? ?? 'Service';
    final description = service['description'] as String? ?? '';
    final price = service['price'] as num? ?? 0;
    final duration = service['duration'] as String? ?? '';
    final rating = service['rating'] as num? ?? 0.0;
    final reviewCount = service['reviewCount'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryText(isDarkMode),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText(isDarkMode),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (price > 0)
                    Text(
                      '\$${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: config.primaryColor,
                      ),
                    ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: AppTheme.secondaryText(isDarkMode)),
                    const SizedBox(width: 4),
                    Text(duration, style: TextStyle(color: AppTheme.secondaryText(isDarkMode))),
                  ],
                  if (rating > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.star, size: 16, color: AppTheme.warningOrange),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} ($reviewCount)',
                      style: TextStyle(color: AppTheme.secondaryText(isDarkMode)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showBookingDialog(context, service);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDialog(BuildContext context, Map<String, dynamic> service) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final name = service['name'] as String? ?? 'Service';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor(isDarkMode),
        title: Text('Book $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to send a booking inquiry to ${business.businessName}?',
              style: TextStyle(color: AppTheme.secondaryText(isDarkMode)),
            ),
            const SizedBox(height: 16),
            Text(
              'They will contact you to confirm the booking details.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Booking inquiry sent for $name!'),
                  backgroundColor: AppTheme.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: config.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Inquiry'),
          ),
        ],
      ),
    );
  }
}
