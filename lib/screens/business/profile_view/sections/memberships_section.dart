import 'package:flutter/material.dart';
import '../../../../config/category_profile_config.dart';

/// Membership plan model
class MembershipPlan {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String duration; // "1 Month", "3 Months", "1 Year"
  final List<String> features;
  final bool isPopular;
  final double? originalPrice; // For showing discounts

  MembershipPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.duration,
    this.features = const [],
    this.isPopular = false,
    this.originalPrice,
  });

  factory MembershipPlan.fromMap(Map<String, dynamic> map, String id) {
    return MembershipPlan(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      duration: map['duration'] ?? '',
      features: List<String>.from(map['features'] ?? []),
      isPopular: map['isPopular'] ?? false,
      originalPrice: map['originalPrice']?.toDouble(),
    );
  }

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price;

  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }
}

/// Section displaying membership plans
class MembershipsSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final List<MembershipPlan>? plans;
  final VoidCallback? onPlanSelect;

  const MembershipsSection({
    super.key,
    required this.businessId,
    required this.config,
    this.plans,
    this.onPlanSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // For demo, using sample plans
    final displayPlans = plans ?? _getSamplePlans();

    if (displayPlans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDarkMode),
        SizedBox(
          height: 340,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: displayPlans.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 280,
                  child: MembershipCard(
                    plan: displayPlans[index],
                    config: config,
                    isDarkMode: isDarkMode,
                    onSelect: onPlanSelect,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<MembershipPlan> _getSamplePlans() {
    return [
      MembershipPlan(
        id: '1',
        name: 'Monthly',
        description: 'Perfect for trying out',
        price: 2999,
        duration: '1 Month',
        features: [
          'Access to all gym equipment',
          'Basic group classes',
          'Locker room access',
        ],
      ),
      MembershipPlan(
        id: '2',
        name: 'Quarterly',
        description: 'Best value for money',
        price: 7499,
        originalPrice: 8997,
        duration: '3 Months',
        features: [
          'Access to all gym equipment',
          'All group classes included',
          'Locker room access',
          '1 Personal training session',
          'Nutrition consultation',
        ],
        isPopular: true,
      ),
      MembershipPlan(
        id: '3',
        name: 'Annual',
        description: 'Maximum savings',
        price: 24999,
        originalPrice: 35988,
        duration: '1 Year',
        features: [
          'Unlimited gym access',
          'All group classes included',
          'Premium locker',
          '4 Personal training sessions',
          'Monthly nutrition consultation',
          'Guest passes (2/month)',
          'Freeze membership (30 days)',
        ],
      ),
    ];
  }

  Widget _buildSectionHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.card_membership,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Membership Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a membership plan
class MembershipCard extends StatelessWidget {
  final MembershipPlan plan;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onSelect;

  const MembershipCard({
    super.key,
    required this.plan,
    required this.config,
    required this.isDarkMode,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: plan.isPopular
            ? Border.all(color: config.primaryColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with plan name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plan.isPopular
                  ? config.primaryColor
                  : config.primaryColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: plan.isPopular
                            ? Colors.white
                            : (isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (plan.isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Popular',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: config.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (plan.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: plan.isPopular
                          ? Colors.white70
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${plan.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '/${plan.duration.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                if (plan.hasDiscount) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${plan.originalPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Save ${plan.discountPercent}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Features list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: plan.features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Select button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      plan.isPopular ? config.primaryColor : Colors.transparent,
                  foregroundColor:
                      plan.isPopular ? Colors.white : config.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: plan.isPopular
                        ? BorderSide.none
                        : BorderSide(color: config.primaryColor),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Choose Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
