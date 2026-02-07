import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';

/// Property types (aligned with NoBroker, MagicBricks, 99acres, Housing.com)
class PropertyTypes {
  static const List<String> all = [
    'Apartment / Flat',
    'Independent House',
    'Villa',
    'Penthouse',
    'Duplex',
    'Studio Apartment',
    'Builder Floor',
    'Farmhouse',
    'Row House',
    'Plot / Land',
    'Office Space',
    'Retail Shop',
    'Showroom',
    'Warehouse / Godown',
    'Industrial Space',
    'PG / Co-living',
    'Service Apartment',
    'Other',
  ];

  static IconData getIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('apartment') || lower.contains('flat')) {
      return Icons.apartment;
    }
    if (lower.contains('independent') ||
        lower.contains('house') ||
        lower.contains('bungalow')) {
      return Icons.home;
    }
    if (lower.contains('villa')) return Icons.villa;
    if (lower.contains('penthouse')) return Icons.location_city;
    if (lower.contains('duplex')) return Icons.home_work;
    if (lower.contains('studio')) return Icons.single_bed;
    if (lower.contains('builder floor')) return Icons.layers;
    if (lower.contains('farmhouse')) return Icons.agriculture;
    if (lower.contains('row house')) return Icons.holiday_village;
    if (lower.contains('plot') || lower.contains('land')) {
      return Icons.landscape;
    }
    if (lower.contains('office')) return Icons.work;
    if (lower.contains('retail') || lower.contains('shop')) {
      return Icons.storefront;
    }
    if (lower.contains('showroom')) return Icons.store;
    if (lower.contains('warehouse') || lower.contains('godown')) {
      return Icons.warehouse;
    }
    if (lower.contains('industrial')) return Icons.factory;
    if (lower.contains('pg') || lower.contains('co-living')) return Icons.group;
    if (lower.contains('service apartment')) return Icons.room_service;
    return Icons.domain;
  }

  static Color getColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('apartment') || lower.contains('flat')) {
      return const Color(0xFF2196F3);
    }
    if (lower.contains('independent') ||
        lower.contains('house') ||
        lower.contains('bungalow')) {
      return const Color(0xFF4CAF50);
    }
    if (lower.contains('villa')) return const Color(0xFFE91E63);
    if (lower.contains('penthouse')) return const Color(0xFF673AB7);
    if (lower.contains('duplex')) return const Color(0xFF795548);
    if (lower.contains('studio')) return const Color(0xFF00BCD4);
    if (lower.contains('builder floor')) return const Color(0xFF5C6BC0);
    if (lower.contains('farmhouse')) return const Color(0xFF66BB6A);
    if (lower.contains('row house')) return const Color(0xFFFF9800);
    if (lower.contains('plot') || lower.contains('land')) {
      return const Color(0xFF8BC34A);
    }
    if (lower.contains('office')) return const Color(0xFF3F51B5);
    if (lower.contains('retail') || lower.contains('shop')) {
      return const Color(0xFFFF5722);
    }
    if (lower.contains('showroom')) return const Color(0xFFEF6C00);
    if (lower.contains('warehouse') || lower.contains('godown')) {
      return const Color(0xFF9E9E9E);
    }
    if (lower.contains('industrial')) return const Color(0xFF546E7A);
    if (lower.contains('pg') || lower.contains('co-living')) {
      return const Color(0xFF26A69A);
    }
    if (lower.contains('service apartment')) return const Color(0xFF7E57C2);
    return const Color(0xFF757575);
  }
}

/// Furnishing status (aligned with MagicBricks, NoBroker, 99acres)
class FurnishingStatus {
  static const List<String> all = [
    'Furnished',
    'Semi-Furnished',
    'Unfurnished',
  ];
}

/// Facing direction (aligned with MagicBricks, 99acres)
class FacingDirection {
  static const List<String> all = [
    'North',
    'South',
    'East',
    'West',
    'North-East',
    'North-West',
    'South-East',
    'South-West',
  ];
}

/// Ownership type (aligned with 99acres, MagicBricks)
class OwnershipType {
  static const List<String> all = [
    'Freehold',
    'Leasehold',
    'Co-operative Society',
    'Power of Attorney',
  ];
}

/// Possession status
class PossessionStatus {
  static const List<String> all = [
    'Ready to Move',
    'Under Construction',
    'New Launch',
  ];
}

/// Listing type
enum ListingType {
  sale,
  rent,
  lease;

  String get displayName {
    switch (this) {
      case ListingType.sale:
        return 'For Sale';
      case ListingType.rent:
        return 'For Rent';
      case ListingType.lease:
        return 'For Lease';
    }
  }

  Color get color {
    switch (this) {
      case ListingType.sale:
        return Colors.green;
      case ListingType.rent:
        return Colors.blue;
      case ListingType.lease:
        return Colors.purple;
    }
  }

  static ListingType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'rent':
        return ListingType.rent;
      case 'lease':
        return ListingType.lease;
      default:
        return ListingType.sale;
    }
  }
}

/// Property status
enum PropertyStatus {
  available,
  pending,
  underContract,
  sold,
  rented,
  offMarket;

  String get displayName {
    switch (this) {
      case PropertyStatus.available:
        return 'Available';
      case PropertyStatus.pending:
        return 'Pending';
      case PropertyStatus.underContract:
        return 'Under Contract';
      case PropertyStatus.sold:
        return 'Sold';
      case PropertyStatus.rented:
        return 'Rented';
      case PropertyStatus.offMarket:
        return 'Off Market';
    }
  }

  Color get color {
    switch (this) {
      case PropertyStatus.available:
        return Colors.green;
      case PropertyStatus.pending:
        return Colors.orange;
      case PropertyStatus.underContract:
        return Colors.blue;
      case PropertyStatus.sold:
        return Colors.purple;
      case PropertyStatus.rented:
        return Colors.teal;
      case PropertyStatus.offMarket:
        return Colors.grey;
    }
  }

  static PropertyStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return PropertyStatus.pending;
      case 'undercontract':
      case 'under_contract':
        return PropertyStatus.underContract;
      case 'sold':
        return PropertyStatus.sold;
      case 'rented':
        return PropertyStatus.rented;
      case 'offmarket':
      case 'off_market':
        return PropertyStatus.offMarket;
      default:
        return PropertyStatus.available;
    }
  }
}

/// Property model (aligned with NoBroker, MagicBricks, 99acres, Zillow)
class PropertyModel {
  final String id;
  final String businessId;
  final String title;
  final String? description;
  final String propertyType;
  final ListingType listingType;
  final PropertyStatus status;
  final double price;
  final double? pricePerSqft;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? locality;
  final double? latitude;
  final double? longitude;
  final int bedrooms;
  final int bathrooms;
  final int? balconies;
  final int? sqft;
  final int? carpetArea;
  final int? builtUpArea;
  final int? lotSize;
  final int? yearBuilt;
  final int? floorNumber;
  final int? totalFloors;
  final int? parkingSpaces;
  final String? furnishing; // Furnished, Semi-Furnished, Unfurnished
  final String? facing; // North, South, East, West, etc.
  final String? ownership; // Freehold, Leasehold, etc.
  final String? possession; // Ready to Move, Under Construction
  final String? bhkConfig; // 1 BHK, 2 BHK, etc.
  final String? reraId;
  final List<String>? amenities; // Society amenities
  final List<String>? features; // Pool, Gym, Garage, etc.
  final List<String>? images;
  final String? virtualTourUrl;
  final String? floorPlanUrl;
  final bool isFeatured;
  final bool isPetFriendly;
  final bool isVerified;
  final bool isReraApproved;
  final DateTime? availableFrom;
  final DateTime createdAt;

  PropertyModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.description,
    required this.propertyType,
    this.listingType = ListingType.sale,
    this.status = PropertyStatus.available,
    required this.price,
    this.pricePerSqft,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.locality,
    this.latitude,
    this.longitude,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.balconies,
    this.sqft,
    this.carpetArea,
    this.builtUpArea,
    this.lotSize,
    this.yearBuilt,
    this.floorNumber,
    this.totalFloors,
    this.parkingSpaces,
    this.furnishing,
    this.facing,
    this.ownership,
    this.possession,
    this.bhkConfig,
    this.reraId,
    this.amenities,
    this.features,
    this.images,
    this.virtualTourUrl,
    this.floorPlanUrl,
    this.isFeatured = false,
    this.isPetFriendly = false,
    this.isVerified = false,
    this.isReraApproved = false,
    this.availableFrom,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (zipCode != null && zipCode!.isNotEmpty) parts.add(zipCode!);
    return parts.join(', ');
  }

  String get bedroomsBathrooms {
    return '$bedrooms bed · $bathrooms bath';
  }

  String get displayBHK {
    if (bhkConfig != null && bhkConfig!.isNotEmpty) return bhkConfig!;
    if (bedrooms > 0) return '$bedrooms BHK';
    return '';
  }

  String get floorInfo {
    if (floorNumber != null && totalFloors != null) {
      return 'Floor $floorNumber of $totalFloors';
    }
    if (floorNumber != null) return 'Floor $floorNumber';
    return '';
  }

  factory PropertyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      propertyType: data['propertyType'] ?? 'Other',
      listingType: ListingType.fromString(data['listingType']),
      status: PropertyStatus.fromString(data['status']),
      price: (data['price'] ?? 0).toDouble(),
      pricePerSqft: data['pricePerSqft']?.toDouble(),
      address: data['address'],
      city: data['city'],
      state: data['state'],
      zipCode: data['zipCode'],
      locality: data['locality'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      bedrooms: data['bedrooms'] ?? 0,
      bathrooms: data['bathrooms'] ?? 0,
      balconies: data['balconies'],
      sqft: data['sqft'],
      carpetArea: data['carpetArea'],
      builtUpArea: data['builtUpArea'],
      lotSize: data['lotSize'],
      yearBuilt: data['yearBuilt'],
      floorNumber: data['floorNumber'],
      totalFloors: data['totalFloors'],
      parkingSpaces: data['parkingSpaces'],
      furnishing: data['furnishing'],
      facing: data['facing'],
      ownership: data['ownership'],
      possession: data['possession'],
      bhkConfig: data['bhkConfig'],
      reraId: data['reraId'],
      amenities: data['amenities'] != null
          ? List<String>.from(data['amenities'])
          : null,
      features: data['features'] != null
          ? List<String>.from(data['features'])
          : null,
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      virtualTourUrl: data['virtualTourUrl'],
      floorPlanUrl: data['floorPlanUrl'],
      isFeatured: data['isFeatured'] ?? false,
      isPetFriendly: data['isPetFriendly'] ?? false,
      isVerified: data['isVerified'] ?? false,
      isReraApproved: data['isReraApproved'] ?? false,
      availableFrom: data['availableFrom'] != null
          ? (data['availableFrom'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'title': title,
      'description': description,
      'propertyType': propertyType,
      'listingType': listingType.name,
      'status': status.name,
      'price': price,
      'pricePerSqft': pricePerSqft,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'locality': locality,
      'latitude': latitude,
      'longitude': longitude,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'balconies': balconies,
      'sqft': sqft,
      'carpetArea': carpetArea,
      'builtUpArea': builtUpArea,
      'lotSize': lotSize,
      'yearBuilt': yearBuilt,
      'floorNumber': floorNumber,
      'totalFloors': totalFloors,
      'parkingSpaces': parkingSpaces,
      'furnishing': furnishing,
      'facing': facing,
      'ownership': ownership,
      'possession': possession,
      'bhkConfig': bhkConfig,
      'reraId': reraId,
      'amenities': amenities,
      'features': features,
      'images': images,
      'virtualTourUrl': virtualTourUrl,
      'floorPlanUrl': floorPlanUrl,
      'isFeatured': isFeatured,
      'isPetFriendly': isPetFriendly,
      'isVerified': isVerified,
      'isReraApproved': isReraApproved,
      'availableFrom': availableFrom != null
          ? Timestamp.fromDate(availableFrom!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Real estate properties tab
class RealEstatePropertiesTab extends StatefulWidget {
  final BusinessModel business;

  const RealEstatePropertiesTab({super.key, required this.business});

  @override
  State<RealEstatePropertiesTab> createState() =>
      _RealEstatePropertiesTabState();
}

class _RealEstatePropertiesTabState extends State<RealEstatePropertiesTab> {
  String _selectedStatus = 'Available';
  ListingType? _selectedListingType;

  final List<String> _statusFilters = [
    'Available',
    'Pending',
    'Sold/Rented',
    'All',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary stats
        _buildSummaryStats(),

        // Status filters
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _statusFilters.length,
            itemBuilder: (context, index) {
              final filter = _statusFilters[index];
              final isSelected = _selectedStatus == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = filter);
                  },
                  selectedColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
        ),

        // Listing type filters
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ListingType.values.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedListingType == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Types'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedListingType = null);
                    },
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }

              final type = ListingType.values[index - 1];
              final isSelected = _selectedListingType == type;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(
                      () => _selectedListingType = selected ? type : null,
                    );
                  },
                  selectedColor: type.color.withValues(alpha: 0.2),
                  checkmarkColor: type.color,
                ),
              );
            },
          ),
        ),

        // Properties list
        Expanded(child: _buildPropertiesList()),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPropertyForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('properties')
          .snapshots(),
      builder: (context, snapshot) {
        final properties = snapshot.data?.docs ?? [];
        final forSale = properties.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['listingType'] == 'sale' && data['status'] == 'available';
        }).length;
        final forRent = properties.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['listingType'] == 'rent' ||
                  data['listingType'] == 'lease') &&
              data['status'] == 'available';
        }).length;
        final totalValue = properties.fold<double>(0, (total, doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'available' || data['status'] == 'pending') {
            return total + (data['price'] ?? 0).toDouble();
          }
          return total;
        });

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.sell,
                  value: forSale.toString(),
                  label: 'For Sale',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.key,
                  value: forRent.toString(),
                  label: 'For Rent',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.attach_money,
                  value: _formatPrice(totalValue),
                  label: 'Portfolio',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(1)} Cr';
    } else if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(1)} L';
    } else if (price >= 1000) {
      return '₹${(price / 1000).toStringAsFixed(0)}K';
    }
    return '₹${price.toStringAsFixed(0)}';
  }

  Widget _buildPropertiesList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('properties');

    if (_selectedStatus == 'Available') {
      query = query.where('status', isEqualTo: 'available');
    } else if (_selectedStatus == 'Pending') {
      query = query.where('status', whereIn: ['pending', 'underContract']);
    } else if (_selectedStatus == 'Sold/Rented') {
      query = query.where('status', whereIn: ['sold', 'rented']);
    }

    if (_selectedListingType != null) {
      query = query.where('listingType', isEqualTo: _selectedListingType!.name);
    }

    query = query.orderBy('createdAt', descending: true).limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final properties = snapshot.data!.docs
            .map((doc) => PropertyModel.fromFirestore(doc))
            .toList();

        if (properties.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: properties.length,
          itemBuilder: (context, index) {
            return _PropertyCard(
              property: properties[index],
              onTap: () => _showPropertyDetails(properties[index]),
              onEdit: () => _showPropertyForm(property: properties[index]),
              onStatusChange: (status) =>
                  _updateStatus(properties[index], status),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No properties listed',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add properties to your portfolio',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showPropertyForm({PropertyModel? property}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PropertyFormSheet(
        businessId: widget.business.id,
        property: property,
        onSaved: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showPropertyDetails(PropertyModel property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PropertyDetailsSheet(
        property: property,
        businessId: widget.business.id,
        onEdit: () {
          Navigator.pop(context);
          _showPropertyForm(property: property);
        },
      ),
    );
  }

  Future<void> _updateStatus(
    PropertyModel property,
    PropertyStatus status,
  ) async {
    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('properties')
          .doc(property.id)
          .update({'status': status.name});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${status.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Property card widget
class _PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Function(PropertyStatus) onStatusChange;

  const _PropertyCard({
    required this.property,
    required this.onTap,
    required this.onEdit,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = PropertyTypes.getColor(property.propertyType);
    final formatter = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Image area
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                image: property.images != null && property.images!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(property.images!.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (property.images == null || property.images!.isEmpty)
                    Center(
                      child: Icon(
                        PropertyTypes.getIcon(property.propertyType),
                        size: 64,
                        color: typeColor.withValues(alpha: 0.3),
                      ),
                    ),
                  // Status badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: property.status.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.status.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Listing type badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: property.listingType.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.listingType.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Featured badge
                  if (property.isFeatured)
                    Positioned(
                      bottom: 8,
                      left: 8,
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
                            Icon(Icons.star, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Price
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${_formatPropertyPrice(property.price)}${property.listingType != ListingType.sale ? '/mo' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'available') {
                            onStatusChange(PropertyStatus.available);
                          } else if (value == 'pending') {
                            onStatusChange(PropertyStatus.pending);
                          } else if (value == 'sold') {
                            onStatusChange(PropertyStatus.sold);
                          } else if (value == 'rented') {
                            onStatusChange(PropertyStatus.rented);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'available',
                            child: Text('Mark Available'),
                          ),
                          const PopupMenuItem(
                            value: 'pending',
                            child: Text('Mark Pending'),
                          ),
                          if (property.listingType == ListingType.sale)
                            const PopupMenuItem(
                              value: 'sold',
                              child: Text('Mark Sold'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'rented',
                              child: Text('Mark Rented'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (property.fullAddress.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.fullAddress,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  // Specs row
                  Row(
                    children: [
                      _buildSpecChip(Icons.bed, '${property.bedrooms} bed'),
                      const SizedBox(width: 8),
                      _buildSpecChip(
                        Icons.bathtub,
                        '${property.bathrooms} bath',
                      ),
                      if (property.sqft != null) ...[
                        const SizedBox(width: 8),
                        _buildSpecChip(
                          Icons.square_foot,
                          '${formatter.format(property.sqft)} sqft',
                        ),
                      ],
                      if (property.isPetFriendly) ...[
                        const SizedBox(width: 8),
                        _buildSpecChip(
                          Icons.pets,
                          'Pets OK',
                          color: Colors.green,
                        ),
                      ],
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

  Widget _buildSpecChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  String _formatPropertyPrice(double price) {
    if (price >= 10000000) {
      return '${(price / 10000000).toStringAsFixed(2)} Cr';
    } else if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      final formatter = NumberFormat('#,###');
      return formatter.format(price);
    }
    return price.toStringAsFixed(0);
  }
}

/// Property form sheet
class _PropertyFormSheet extends StatefulWidget {
  final String businessId;
  final PropertyModel? property;
  final VoidCallback onSaved;

  const _PropertyFormSheet({
    required this.businessId,
    this.property,
    required this.onSaved,
  });

  @override
  State<_PropertyFormSheet> createState() => _PropertyFormSheetState();
}

class _PropertyFormSheetState extends State<_PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _addressController;
  late TextEditingController _localityController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _balconiesController;
  late TextEditingController _sqftController;
  late TextEditingController _carpetAreaController;
  late TextEditingController _yearBuiltController;
  late TextEditingController _floorNumberController;
  late TextEditingController _totalFloorsController;
  late TextEditingController _parkingController;
  late TextEditingController _reraIdController;

  String _selectedType = PropertyTypes.all.first;
  ListingType _selectedListingType = ListingType.sale;
  String? _selectedFurnishing;
  String? _selectedFacing;
  String? _selectedOwnership;
  String? _selectedPossession;
  bool _isFeatured = false;
  bool _isPetFriendly = false;
  bool _isVerified = false;
  bool _isReraApproved = false;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(
      text: p?.price.toStringAsFixed(0) ?? '',
    );
    _addressController = TextEditingController(text: p?.address ?? '');
    _localityController = TextEditingController(text: p?.locality ?? '');
    _cityController = TextEditingController(text: p?.city ?? '');
    _stateController = TextEditingController(text: p?.state ?? '');
    _zipController = TextEditingController(text: p?.zipCode ?? '');
    _bedroomsController = TextEditingController(
      text: p?.bedrooms.toString() ?? '0',
    );
    _bathroomsController = TextEditingController(
      text: p?.bathrooms.toString() ?? '0',
    );
    _balconiesController = TextEditingController(
      text: p?.balconies?.toString() ?? '',
    );
    _sqftController = TextEditingController(text: p?.sqft?.toString() ?? '');
    _carpetAreaController = TextEditingController(
      text: p?.carpetArea?.toString() ?? '',
    );
    _yearBuiltController = TextEditingController(
      text: p?.yearBuilt?.toString() ?? '',
    );
    _floorNumberController = TextEditingController(
      text: p?.floorNumber?.toString() ?? '',
    );
    _totalFloorsController = TextEditingController(
      text: p?.totalFloors?.toString() ?? '',
    );
    _parkingController = TextEditingController(
      text: p?.parkingSpaces?.toString() ?? '',
    );
    _reraIdController = TextEditingController(text: p?.reraId ?? '');

    if (p != null) {
      _selectedType = p.propertyType;
      _selectedListingType = p.listingType;
      _selectedFurnishing = p.furnishing;
      _selectedFacing = p.facing;
      _selectedOwnership = p.ownership;
      _selectedPossession = p.possession;
      _isFeatured = p.isFeatured;
      _isPetFriendly = p.isPetFriendly;
      _isVerified = p.isVerified;
      _isReraApproved = p.isReraApproved;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _balconiesController.dispose();
    _sqftController.dispose();
    _carpetAreaController.dispose();
    _yearBuiltController.dispose();
    _floorNumberController.dispose();
    _totalFloorsController.dispose();
    _parkingController.dispose();
    _reraIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.property != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  isEditing ? 'Edit Property' : 'Add Property',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Property Title *',
                    hintText: 'e.g., Beautiful 3BR Home in Downtown',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Type and Listing Type
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Property Type',
                          border: OutlineInputBorder(),
                        ),
                        items: PropertyTypes.all.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<ListingType>(
                        initialValue: _selectedListingType,
                        decoration: const InputDecoration(
                          labelText: 'Listing Type',
                          border: OutlineInputBorder(),
                        ),
                        items: ListingType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedListingType = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Price *',
                    prefixText: '₹ ',
                    suffixText: _selectedListingType != ListingType.sale
                        ? '/month'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // City, State, Zip
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _zipController,
                        decoration: const InputDecoration(
                          labelText: 'ZIP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bedrooms and Bathrooms
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bedroomsController,
                        decoration: const InputDecoration(
                          labelText: 'Bedrooms',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _bathroomsController,
                        decoration: const InputDecoration(
                          labelText: 'Bathrooms',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sqft and Year Built
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sqftController,
                        decoration: const InputDecoration(
                          labelText: 'Square Feet',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _yearBuiltController,
                        decoration: const InputDecoration(
                          labelText: 'Year Built',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Balconies and Parking
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _balconiesController,
                        decoration: const InputDecoration(
                          labelText: 'Balconies',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _parkingController,
                        decoration: const InputDecoration(
                          labelText: 'Parking Spaces',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Carpet Area and Floor
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _carpetAreaController,
                        decoration: const InputDecoration(
                          labelText: 'Carpet Area (sqft)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _floorNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Floor No.',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _totalFloorsController,
                        decoration: const InputDecoration(
                          labelText: 'Total Floors',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Locality
                TextFormField(
                  controller: _localityController,
                  decoration: const InputDecoration(
                    labelText: 'Locality / Neighborhood',
                    hintText: 'e.g., Koramangala, BKC, HSR Layout',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Furnishing and Facing
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFurnishing,
                        decoration: const InputDecoration(
                          labelText: 'Furnishing',
                          border: OutlineInputBorder(),
                        ),
                        items: [null, ...FurnishingStatus.all].map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s ?? 'Not Specified'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedFurnishing = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacing,
                        decoration: const InputDecoration(
                          labelText: 'Facing',
                          border: OutlineInputBorder(),
                        ),
                        items: [null, ...FacingDirection.all].map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s ?? 'Not Specified'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedFacing = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ownership and Possession
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedOwnership,
                        decoration: const InputDecoration(
                          labelText: 'Ownership',
                          border: OutlineInputBorder(),
                        ),
                        items: [null, ...OwnershipType.all].map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s ?? 'Not Specified'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedOwnership = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPossession,
                        decoration: const InputDecoration(
                          labelText: 'Possession',
                          border: OutlineInputBorder(),
                        ),
                        items: [null, ...PossessionStatus.all].map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s ?? 'Not Specified'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedPossession = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // RERA ID
                TextFormField(
                  controller: _reraIdController,
                  decoration: const InputDecoration(
                    labelText: 'RERA Registration ID',
                    hintText: 'e.g., P52100012345',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Toggles
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Featured'),
                        value: _isFeatured,
                        onChanged: (v) => setState(() => _isFeatured = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Pet Friendly'),
                        value: _isPetFriendly,
                        onChanged: (v) => setState(() => _isPetFriendly = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Verified'),
                        value: _isVerified,
                        onChanged: (v) => setState(() => _isVerified = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('RERA Approved'),
                        value: _isReraApproved,
                        onChanged: (v) => setState(() => _isReraApproved = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProperty,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Property' : 'Add Property'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final bedrooms = int.tryParse(_bedroomsController.text) ?? 0;
      final data = {
        'businessId': widget.businessId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'propertyType': _selectedType,
        'listingType': _selectedListingType.name,
        'status': widget.property?.status.name ?? 'available',
        'price': double.tryParse(_priceController.text) ?? 0,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'locality': _localityController.text.trim().isNotEmpty
            ? _localityController.text.trim()
            : null,
        'city': _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        'state': _stateController.text.trim().isNotEmpty
            ? _stateController.text.trim()
            : null,
        'zipCode': _zipController.text.trim().isNotEmpty
            ? _zipController.text.trim()
            : null,
        'bedrooms': bedrooms,
        'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
        'balconies': _balconiesController.text.isNotEmpty
            ? int.tryParse(_balconiesController.text)
            : null,
        'sqft': _sqftController.text.isNotEmpty
            ? int.tryParse(_sqftController.text)
            : null,
        'carpetArea': _carpetAreaController.text.isNotEmpty
            ? int.tryParse(_carpetAreaController.text)
            : null,
        'yearBuilt': _yearBuiltController.text.isNotEmpty
            ? int.tryParse(_yearBuiltController.text)
            : null,
        'floorNumber': _floorNumberController.text.isNotEmpty
            ? int.tryParse(_floorNumberController.text)
            : null,
        'totalFloors': _totalFloorsController.text.isNotEmpty
            ? int.tryParse(_totalFloorsController.text)
            : null,
        'parkingSpaces': _parkingController.text.isNotEmpty
            ? int.tryParse(_parkingController.text)
            : null,
        'furnishing': _selectedFurnishing,
        'facing': _selectedFacing,
        'ownership': _selectedOwnership,
        'possession': _selectedPossession,
        'bhkConfig': bedrooms > 0 ? '$bedrooms BHK' : null,
        'reraId': _reraIdController.text.trim().isNotEmpty
            ? _reraIdController.text.trim()
            : null,
        'isFeatured': _isFeatured,
        'isPetFriendly': _isPetFriendly,
        'isVerified': _isVerified,
        'isReraApproved': _isReraApproved,
        'createdAt': widget.property?.createdAt != null
            ? Timestamp.fromDate(widget.property!.createdAt)
            : Timestamp.now(),
      };

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('properties');

      if (widget.property != null) {
        await collection.doc(widget.property!.id).update(data);
      } else {
        await collection.add(data);
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

/// Property details sheet
class _PropertyDetailsSheet extends StatelessWidget {
  final PropertyModel property;
  final String businessId;
  final VoidCallback onEdit;

  const _PropertyDetailsSheet({
    required this.property,
    required this.businessId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = PropertyTypes.getColor(property.propertyType);
    final formatter = NumberFormat('#,###');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image area
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    image:
                        property.images != null && property.images!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(property.images!.first),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (property.images == null || property.images!.isEmpty)
                        Center(
                          child: Icon(
                            PropertyTypes.getIcon(property.propertyType),
                            size: 80,
                            color: typeColor.withValues(alpha: 0.3),
                          ),
                        ),
                      // Handle
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      // Edit button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      // Status badges
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: property.status.color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                property.status.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: property.listingType.color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                property.listingType.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  property.propertyType,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${_formatDetailPrice(property.price)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                              if (property.listingType != ListingType.sale)
                                Text(
                                  '/month',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Address
                      if (property.fullAddress.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                property.fullAddress,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Key specs
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              Icons.bed,
                              property.bedrooms.toString(),
                              'Beds',
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            _buildStatItem(
                              Icons.bathtub,
                              property.bathrooms.toString(),
                              'Baths',
                            ),
                            if (property.sqft != null) ...[
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatItem(
                                Icons.square_foot,
                                formatter.format(property.sqft),
                                'Sq Ft',
                              ),
                            ],
                            if (property.yearBuilt != null) ...[
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              _buildStatItem(
                                Icons.calendar_today,
                                property.yearBuilt.toString(),
                                'Built',
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Property details (furnishing, facing, floor, etc.)
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (property.furnishing != null)
                            _buildFeatureChip(
                              Icons.chair,
                              property.furnishing!,
                            ),
                          if (property.facing != null)
                            _buildFeatureChip(
                              Icons.explore,
                              '${property.facing!} Facing',
                            ),
                          if (property.floorNumber != null)
                            _buildFeatureChip(Icons.layers, property.floorInfo),
                          if (property.balconies != null &&
                              property.balconies! > 0)
                            _buildFeatureChip(
                              Icons.balcony,
                              '${property.balconies} ${property.balconies == 1 ? "Balcony" : "Balconies"}',
                            ),
                          if (property.parkingSpaces != null)
                            _buildFeatureChip(
                              Icons.local_parking,
                              '${property.parkingSpaces} Parking',
                            ),
                          if (property.ownership != null)
                            _buildFeatureChip(
                              Icons.description,
                              property.ownership!,
                            ),
                          if (property.possession != null)
                            _buildFeatureChip(Icons.key, property.possession!),
                          if (property.carpetArea != null)
                            _buildFeatureChip(
                              Icons.crop_square,
                              '${property.carpetArea} sqft carpet',
                            ),
                          if (property.isPetFriendly)
                            _buildFeatureChip(
                              Icons.pets,
                              'Pet Friendly',
                              color: Colors.green,
                            ),
                          if (property.isVerified)
                            _buildFeatureChip(
                              Icons.verified,
                              'Verified',
                              color: Colors.blue,
                            ),
                          if (property.isReraApproved)
                            _buildFeatureChip(
                              Icons.shield,
                              'RERA Approved',
                              color: Colors.green,
                            ),
                          if (property.isFeatured)
                            _buildFeatureChip(
                              Icons.star,
                              'Featured',
                              color: Colors.amber,
                            ),
                        ],
                      ),

                      // RERA ID
                      if (property.reraId != null &&
                          property.reraId!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'RERA: ${property.reraId}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Description
                      if (property.description != null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(property.description!),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailPrice(double price) {
    if (price >= 10000000) {
      return '${(price / 10000000).toStringAsFixed(2)} Cr';
    } else if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      final formatter = NumberFormat('#,###');
      return formatter.format(price);
    }
    return price.toStringAsFixed(0);
  }
}
