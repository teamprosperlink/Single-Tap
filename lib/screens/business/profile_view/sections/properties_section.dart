import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/category_profile_config.dart';

/// Property model for real estate listings
class PropertyItem {
  final String id;
  final String title;
  final String? description;
  final String propertyType; // Apartment, House, Villa, Plot, Commercial
  final String listingType; // Sale, Rent, Lease
  final double price;
  final String? priceUnit; // per month, per sqft, etc.
  final int? bedrooms;
  final int? bathrooms;
  final double? area; // in sqft
  final String? areaUnit;
  final String? location;
  final List<String> images;
  final List<String> amenities;
  final bool isAvailable;
  final bool isFeatured;

  PropertyItem({
    required this.id,
    required this.title,
    this.description,
    required this.propertyType,
    required this.listingType,
    required this.price,
    this.priceUnit,
    this.bedrooms,
    this.bathrooms,
    this.area,
    this.areaUnit = 'sqft',
    this.location,
    this.images = const [],
    this.amenities = const [],
    this.isAvailable = true,
    this.isFeatured = false,
  });

  factory PropertyItem.fromMap(Map<String, dynamic> map, String id) {
    return PropertyItem(
      id: id,
      title: map['title'] ?? '',
      description: map['description'],
      propertyType: map['propertyType'] ?? 'Property',
      listingType: map['listingType'] ?? 'Sale',
      price: (map['price'] ?? 0).toDouble(),
      priceUnit: map['priceUnit'],
      bedrooms: map['bedrooms'],
      bathrooms: map['bathrooms'],
      area: map['area']?.toDouble(),
      areaUnit: map['areaUnit'] ?? 'sqft',
      location: map['location'],
      images: List<String>.from(map['images'] ?? []),
      amenities: List<String>.from(map['amenities'] ?? []),
      isAvailable: map['isAvailable'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
    );
  }
}

/// Section displaying properties for real estate businesses
class PropertiesSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final List<PropertyItem>? properties; // Optional pre-loaded properties
  final VoidCallback? onPropertyTap;
  final VoidCallback? onEnquire;

  const PropertiesSection({
    super.key,
    required this.businessId,
    required this.config,
    this.properties,
    this.onPropertyTap,
    this.onEnquire,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // For demo, using sample properties
    // In production, stream from Firestore: businesses/{id}/properties
    final displayProperties = properties ?? _getSampleProperties();

    if (displayProperties.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDarkMode, displayProperties.length),
        ...displayProperties.map((property) => PropertyCard(
              property: property,
              config: config,
              isDarkMode: isDarkMode,
              onTap: onPropertyTap,
              onEnquire: onEnquire,
            )),
      ],
    );
  }

  List<PropertyItem> _getSampleProperties() {
    // Sample data for demonstration
    return [
      PropertyItem(
        id: '1',
        title: '3 BHK Apartment in Prime Location',
        description: 'Spacious apartment with modern amenities',
        propertyType: 'Apartment',
        listingType: 'Sale',
        price: 8500000,
        bedrooms: 3,
        bathrooms: 2,
        area: 1450,
        location: 'Koramangala, Bangalore',
        amenities: ['Parking', 'Gym', 'Pool', 'Security'],
        isFeatured: true,
      ),
      PropertyItem(
        id: '2',
        title: '2 BHK for Rent',
        description: 'Well-maintained apartment near metro',
        propertyType: 'Apartment',
        listingType: 'Rent',
        price: 35000,
        priceUnit: '/month',
        bedrooms: 2,
        bathrooms: 2,
        area: 1100,
        location: 'HSR Layout, Bangalore',
        amenities: ['Parking', 'Power Backup'],
      ),
    ];
  }

  Widget _buildSectionHeader(bool isDarkMode, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.apartment,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Properties',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count listings',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
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
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying a property listing
class PropertyCard extends StatelessWidget {
  final PropertyItem property;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final VoidCallback? onEnquire;

  const PropertyCard({
    super.key,
    required this.property,
    required this.config,
    required this.isDarkMode,
    this.onTap,
    this.onEnquire,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildPropertyImage(),
                ),
                // Listing type badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getListingTypeColor(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'For ${property.listingType}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Featured badge
                if (property.isFeatured)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Property type badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      property.propertyType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Property details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    property.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Location
                  if (property.location != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location!,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Property specs
                  Row(
                    children: [
                      if (property.bedrooms != null)
                        _SpecChip(
                          icon: Icons.bed,
                          value: '${property.bedrooms} Bed',
                          isDarkMode: isDarkMode,
                        ),
                      if (property.bathrooms != null) ...[
                        const SizedBox(width: 12),
                        _SpecChip(
                          icon: Icons.bathtub,
                          value: '${property.bathrooms} Bath',
                          isDarkMode: isDarkMode,
                        ),
                      ],
                      if (property.area != null) ...[
                        const SizedBox(width: 12),
                        _SpecChip(
                          icon: Icons.square_foot,
                          value:
                              '${property.area!.toStringAsFixed(0)} ${property.areaUnit}',
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price and enquire button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatPrice(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: config.primaryColor,
                            ),
                          ),
                          if (property.priceUnit != null)
                            Text(
                              property.priceUnit!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: onEnquire,
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Enquire'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyImage() {
    if (property.images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: property.images.first,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildImagePlaceholder(),
        errorWidget: (context, url, error) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.apartment,
          size: 48,
          color: config.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getListingTypeColor() {
    switch (property.listingType.toLowerCase()) {
      case 'sale':
        return Colors.green;
      case 'rent':
        return Colors.blue;
      case 'lease':
        return Colors.orange;
      default:
        return config.primaryColor;
    }
  }

  String _formatPrice() {
    if (property.price >= 10000000) {
      return '₹${(property.price / 10000000).toStringAsFixed(2)} Cr';
    } else if (property.price >= 100000) {
      return '₹${(property.price / 100000).toStringAsFixed(2)} L';
    } else if (property.price >= 1000) {
      return '₹${(property.price / 1000).toStringAsFixed(1)}K';
    }
    return '₹${property.price.toStringAsFixed(0)}';
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool isDarkMode;

  const _SpecChip({
    required this.icon,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
