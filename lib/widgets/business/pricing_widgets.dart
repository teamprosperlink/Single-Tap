import 'package:flutter/material.dart';

/// Service pricing table widget for appointment-based businesses
/// (Healthcare, Beauty, Education, etc.)
class ServicePricingTable extends StatelessWidget {
  final List<ServiceItem> services;
  final VoidCallback? onBookTap;
  final bool isDarkMode;

  const ServicePricingTable({
    super.key,
    required this.services,
    this.onBookTap,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Services & Pricing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServicePricingRow(
              service: service,
              onBookTap: onBookTap,
              isDarkMode: isDarkMode,
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.price_check_outlined,
              size: 48,
              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No services available',
              style: TextStyle(
                fontSize: 14,
                color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicePricingRow extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback? onBookTap;
  final bool isDarkMode;

  const _ServicePricingRow({
    required this.service,
    this.onBookTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isDarkMode ? Colors.transparent : Colors.white,
      child: Row(
        children: [
          // Service Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (service.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Duration
          if (service.duration != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    service.duration!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF42A5F5),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),

          // Price & Book Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${service.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? const Color(0xFF00D67D) : const Color(0xFF00A85B),
                ),
              ),
              if (onBookTap != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onBookTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Book',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Room pricing card widget for hospitality businesses
class RoomPricingCard extends StatelessWidget {
  final RoomPriceInfo room;
  final VoidCallback? onCheckAvailability;
  final bool isDarkMode;

  const RoomPricingCard({
    super.key,
    required this.room,
    this.onCheckAvailability,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? const Color(0xFF2D2D44) : Colors.white).withValues(alpha: 0.9),
            (isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50]!).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Image
                if (room.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      room.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                    ),
                  )
                else
                  _buildImagePlaceholder(),
                const SizedBox(width: 14),

                // Room Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (room.capacity != null)
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Up to ${room.capacity} guests',
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Amenities chips
                      if (room.amenities != null && room.amenities!.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: room.amenities!.take(3).map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                amenity,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF00D67D),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),

            // Pricing and Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.priceRange != null ? 'From' : 'Price',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${room.pricePerNight.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? const Color(0xFF00D67D) : const Color(0xFF00A85B),
                      ),
                    ),
                    Text(
                      'per night',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (onCheckAvailability != null)
                  ElevatedButton(
                    onPressed: onCheckAvailability,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D67D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Check Availability',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF00D67D).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.hotel,
        color: Color(0xFF00D67D),
        size: 32,
      ),
    );
  }
}

/// Package pricing tier widget for portfolio/professional services
class PackagePricingTier extends StatelessWidget {
  final List<PricingPackage> packages;
  final Function(PricingPackage)? onSelectPackage;
  final bool isDarkMode;

  const PackagePricingTier({
    super.key,
    required this.packages,
    this.onSelectPackage,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Pricing Packages',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final package = packages[index];
              final isPopular = package.isPopular ?? false;

              return Container(
                width: 260,
                margin: EdgeInsets.only(
                  right: index < packages.length - 1 ? 12 : 0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPopular
                        ? [
                            const Color(0xFF00D67D).withValues(alpha: 0.2),
                            const Color(0xFF00D67D).withValues(alpha: 0.05),
                          ]
                        : [
                            (isDarkMode ? const Color(0xFF2D2D44) : Colors.white).withValues(alpha: 0.9),
                            (isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50]!).withValues(alpha: 0.9),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPopular
                        ? const Color(0xFF00D67D).withValues(alpha: 0.4)
                        : (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    width: isPopular ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Popular Badge
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D67D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      if (isPopular) const SizedBox(height: 12),

                      // Package Name
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? const Color(0xFF00D67D) : const Color(0xFF00A85B),
                            ),
                          ),
                          Text(
                            package.price.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? const Color(0xFF00D67D) : const Color(0xFF00A85B),
                            ),
                          ),
                        ],
                      ),
                      if (package.pricingUnit != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          package.pricingUnit!,
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Features
                      Expanded(
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: package.features.length,
                          itemBuilder: (context, idx) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: const Color(0xFF00D67D),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      package.features[idx],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Select Button
                      if (onSelectPackage != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => onSelectPackage!(package),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPopular
                                  ? const Color(0xFF00D67D)
                                  : (isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
                              foregroundColor: isPopular ? Colors.white : const Color(0xFF00D67D),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              package.ctaText ?? 'Select Package',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 48,
              color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No packages available',
              style: TextStyle(
                fontSize: 14,
                color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper models for pricing widgets
class ServiceItem {
  final String name;
  final String? description;
  final double price;
  final String? duration;

  ServiceItem({
    required this.name,
    this.description,
    required this.price,
    this.duration,
  });
}

class RoomPriceInfo {
  final String roomType;
  final double pricePerNight;
  final String? priceRange;
  final int? capacity;
  final List<String>? amenities;
  final String? imageUrl;

  RoomPriceInfo({
    required this.roomType,
    required this.pricePerNight,
    this.priceRange,
    this.capacity,
    this.amenities,
    this.imageUrl,
  });
}

class PricingPackage {
  final String name;
  final double price;
  final String? pricingUnit;
  final List<String> features;
  final bool? isPopular;
  final String? ctaText;

  PricingPackage({
    required this.name,
    required this.price,
    this.pricingUnit,
    required this.features,
    this.isPopular,
    this.ctaText,
  });
}
