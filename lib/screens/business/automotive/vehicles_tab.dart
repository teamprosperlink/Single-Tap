import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';

/// Vehicle categories (aligned with CarDekho, AutoTrader, Cars24)
class VehicleCategories {
  static const List<String> all = [
    'Hatchback',
    'Sedan',
    'SUV',
    'Crossover',
    'Truck / Pickup',
    'Van / MUV',
    'Coupe',
    'Convertible',
    'Wagon',
    'Motorcycle',
    'Scooter',
    'Electric',
    'Hybrid',
    'Luxury',
    'Sports',
    'Commercial',
    'Classic / Vintage',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hatchback':
        return Icons.directions_car;
      case 'sedan':
        return Icons.directions_car;
      case 'suv':
        return Icons.directions_car_filled;
      case 'crossover':
        return Icons.directions_car_filled;
      case 'truck / pickup':
        return Icons.local_shipping;
      case 'van / muv':
        return Icons.airport_shuttle;
      case 'coupe':
        return Icons.directions_car;
      case 'convertible':
        return Icons.directions_car;
      case 'wagon':
        return Icons.directions_car;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'scooter':
        return Icons.two_wheeler;
      case 'electric':
        return Icons.electric_car;
      case 'hybrid':
        return Icons.eco;
      case 'luxury':
        return Icons.star;
      case 'sports':
        return Icons.speed;
      case 'commercial':
        return Icons.local_shipping;
      case 'classic / vintage':
        return Icons.auto_awesome;
      default:
        return Icons.directions_car;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'hatchback':
        return const Color(0xFF4CAF50);
      case 'sedan':
        return const Color(0xFF2196F3);
      case 'suv':
        return const Color(0xFF795548);
      case 'crossover':
        return const Color(0xFF009688);
      case 'truck / pickup':
        return const Color(0xFF607D8B);
      case 'van / muv':
        return const Color(0xFF9E9E9E);
      case 'coupe':
        return const Color(0xFFE91E63);
      case 'convertible':
        return const Color(0xFFFF9800);
      case 'wagon':
        return const Color(0xFF00BCD4);
      case 'motorcycle':
        return const Color(0xFF212121);
      case 'scooter':
        return const Color(0xFF455A64);
      case 'electric':
        return const Color(0xFF00BCD4);
      case 'hybrid':
        return const Color(0xFF8BC34A);
      case 'luxury':
        return const Color(0xFF673AB7);
      case 'sports':
        return const Color(0xFFF44336);
      case 'commercial':
        return const Color(0xFF37474F);
      case 'classic / vintage':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF757575);
    }
  }
}

/// Vehicle condition
enum VehicleCondition {
  newVehicle,
  excellent,
  good,
  fair,
  needsWork;

  String get displayName {
    switch (this) {
      case VehicleCondition.newVehicle:
        return 'New';
      case VehicleCondition.excellent:
        return 'Excellent';
      case VehicleCondition.good:
        return 'Good';
      case VehicleCondition.fair:
        return 'Fair';
      case VehicleCondition.needsWork:
        return 'Needs Work';
    }
  }

  Color get color {
    switch (this) {
      case VehicleCondition.newVehicle:
        return Colors.blue;
      case VehicleCondition.excellent:
        return Colors.green;
      case VehicleCondition.good:
        return Colors.lightGreen;
      case VehicleCondition.fair:
        return Colors.orange;
      case VehicleCondition.needsWork:
        return Colors.red;
    }
  }

  static VehicleCondition fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'new':
      case 'newvehicle':
        return VehicleCondition.newVehicle;
      case 'excellent':
        return VehicleCondition.excellent;
      case 'good':
        return VehicleCondition.good;
      case 'fair':
        return VehicleCondition.fair;
      case 'needswork':
      case 'needs_work':
        return VehicleCondition.needsWork;
      default:
        return VehicleCondition.good;
    }
  }
}

/// Vehicle listing status
enum VehicleStatus {
  available,
  reserved,
  sold,
  pending;

  String get displayName {
    switch (this) {
      case VehicleStatus.available:
        return 'Available';
      case VehicleStatus.reserved:
        return 'Reserved';
      case VehicleStatus.sold:
        return 'Sold';
      case VehicleStatus.pending:
        return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case VehicleStatus.available:
        return Colors.green;
      case VehicleStatus.reserved:
        return Colors.orange;
      case VehicleStatus.sold:
        return Colors.grey;
      case VehicleStatus.pending:
        return Colors.blue;
    }
  }

  static VehicleStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'reserved':
        return VehicleStatus.reserved;
      case 'sold':
        return VehicleStatus.sold;
      case 'pending':
        return VehicleStatus.pending;
      default:
        return VehicleStatus.available;
    }
  }
}

/// Vehicle model
class VehicleModel {
  final String id;
  final String businessId;
  final String make;
  final String model;
  final int year;
  final String category;
  final VehicleCondition condition;
  final VehicleStatus status;
  final double price;
  final int mileage;
  final String? vin;
  final String? color;
  final String? transmission; // Automatic, Manual, CVT
  final String? fuelType; // Gas, Diesel, Electric, Hybrid
  final String? engine; // e.g., "2.0L 4-Cylinder"
  final int? doors;
  final int? seats;
  final List<String>? features; // A/C, Sunroof, Navigation, etc.
  final List<String>? images;
  final String? description;
  final bool isFeatured;
  final bool isCertified;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.businessId,
    required this.make,
    required this.model,
    required this.year,
    required this.category,
    this.condition = VehicleCondition.good,
    this.status = VehicleStatus.available,
    required this.price,
    this.mileage = 0,
    this.vin,
    this.color,
    this.transmission,
    this.fuelType,
    this.engine,
    this.doors,
    this.seats,
    this.features,
    this.images,
    this.description,
    this.isFeatured = false,
    this.isCertified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get title => '$year $make $model';

  String get formattedMileage {
    if (mileage >= 1000) {
      return '${(mileage / 1000).toStringAsFixed(0)}K mi';
    }
    return '$mileage mi';
  }

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      category: data['category'] ?? 'Other',
      condition: VehicleCondition.fromString(data['condition']),
      status: VehicleStatus.fromString(data['status']),
      price: (data['price'] ?? 0).toDouble(),
      mileage: data['mileage'] ?? 0,
      vin: data['vin'],
      color: data['color'],
      transmission: data['transmission'],
      fuelType: data['fuelType'],
      engine: data['engine'],
      doors: data['doors'],
      seats: data['seats'],
      features:
          data['features'] != null ? List<String>.from(data['features']) : null,
      images:
          data['images'] != null ? List<String>.from(data['images']) : null,
      description: data['description'],
      isFeatured: data['isFeatured'] ?? false,
      isCertified: data['isCertified'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'make': make,
      'model': model,
      'year': year,
      'category': category,
      'condition': condition.name,
      'status': status.name,
      'price': price,
      'mileage': mileage,
      'vin': vin,
      'color': color,
      'transmission': transmission,
      'fuelType': fuelType,
      'engine': engine,
      'doors': doors,
      'seats': seats,
      'features': features,
      'images': images,
      'description': description,
      'isFeatured': isFeatured,
      'isCertified': isCertified,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Automotive vehicles/inventory tab
class AutomotiveVehiclesTab extends StatefulWidget {
  final BusinessModel business;

  const AutomotiveVehiclesTab({super.key, required this.business});

  @override
  State<AutomotiveVehiclesTab> createState() => _AutomotiveVehiclesTabState();
}

class _AutomotiveVehiclesTabState extends State<AutomotiveVehiclesTab> {
  String _selectedFilter = 'Available';
  String? _selectedCategory;

  final List<String> _statusFilters = [
    'Available',
    'Reserved',
    'Sold',
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
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = filter);
                  },
                  selectedColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
        ),

        // Category filters
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: VehicleCategories.all.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategory == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Types'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = null);
                    },
                    selectedColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }

              final category = VehicleCategories.all[index - 1];
              final isSelected = _selectedCategory == category;
              final color = VehicleCategories.getColor(category);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    VehicleCategories.getIcon(category),
                    size: 18,
                    color: isSelected ? color : Colors.grey,
                  ),
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(
                        () => _selectedCategory = selected ? category : null);
                  },
                  selectedColor: color.withValues(alpha: 0.2),
                  checkmarkColor: color,
                ),
              );
            },
          ),
        ),

        // Vehicles list
        Expanded(
          child: _buildVehiclesList(),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showVehicleForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
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
          .collection('vehicles')
          .snapshots(),
      builder: (context, snapshot) {
        final vehicles = snapshot.data?.docs ?? [];
        final available = vehicles
            .where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'available')
            .length;
        final totalValue = vehicles.fold<double>(0, (total, doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'available' || data['status'] == 'reserved') {
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
                  icon: Icons.directions_car,
                  value: vehicles.length.toString(),
                  label: 'Total Inventory',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  value: available.toString(),
                  label: 'Available',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.attach_money,
                  value: '\$${_formatPrice(totalValue)}',
                  label: 'Inventory Value',
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
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }

  Widget _buildVehiclesList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('vehicles');

    if (_selectedFilter != 'All') {
      query =
          query.where('status', isEqualTo: _selectedFilter.toLowerCase());
    }

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
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

        final vehicles = snapshot.data!.docs
            .map((doc) => VehicleModel.fromFirestore(doc))
            .toList();

        if (vehicles.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            return _VehicleCard(
              vehicle: vehicles[index],
              onTap: () => _showVehicleDetails(vehicles[index]),
              onEdit: () => _showVehicleForm(vehicle: vehicles[index]),
              onStatusChange: (status) =>
                  _updateStatus(vehicles[index], status),
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
          Icon(
            Icons.directions_car,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No vehicles in inventory',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add vehicles to your inventory',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showVehicleForm({VehicleModel? vehicle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleFormSheet(
        businessId: widget.business.id,
        vehicle: vehicle,
        onSaved: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showVehicleDetails(VehicleModel vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleDetailsSheet(
        vehicle: vehicle,
        businessId: widget.business.id,
        onEdit: () {
          Navigator.pop(context);
          _showVehicleForm(vehicle: vehicle);
        },
      ),
    );
  }

  Future<void> _updateStatus(VehicleModel vehicle, VehicleStatus status) async {
    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('vehicles')
          .doc(vehicle.id)
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Vehicle card widget
class _VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Function(VehicleStatus) onStatusChange;

  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onEdit,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = VehicleCategories.getColor(vehicle.category);
    final formatter = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Image placeholder or first image
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                image: vehicle.images != null && vehicle.images!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(vehicle.images!.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (vehicle.images == null || vehicle.images!.isEmpty)
                    Center(
                      child: Icon(
                        VehicleCategories.getIcon(vehicle.category),
                        size: 64,
                        color: categoryColor.withValues(alpha: 0.3),
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
                        color: vehicle.status.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vehicle.status.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Featured/Certified badges
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (vehicle.isFeatured)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        if (vehicle.isCertified) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Certified',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
                        '\$${formatter.format(vehicle.price)}',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    vehicle.category,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        vehicle.condition.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    vehicle.condition.displayName,
                                    style: TextStyle(
                                      color: vehicle.condition.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'available') {
                            onStatusChange(VehicleStatus.available);
                          } else if (value == 'reserved') {
                            onStatusChange(VehicleStatus.reserved);
                          } else if (value == 'sold') {
                            onStatusChange(VehicleStatus.sold);
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
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 20, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Mark Available'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reserved',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark,
                                    size: 20, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Mark Reserved'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sold',
                            child: Row(
                              children: [
                                Icon(Icons.sell, size: 20, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Mark Sold'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Specs row
                  Row(
                    children: [
                      _buildSpecChip(Icons.speed, vehicle.formattedMileage),
                      if (vehicle.transmission != null) ...[
                        const SizedBox(width: 8),
                        _buildSpecChip(
                            Icons.settings, vehicle.transmission!),
                      ],
                      if (vehicle.fuelType != null) ...[
                        const SizedBox(width: 8),
                        _buildSpecChip(
                            Icons.local_gas_station, vehicle.fuelType!),
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

  Widget _buildSpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vehicle form sheet
class _VehicleFormSheet extends StatefulWidget {
  final String businessId;
  final VehicleModel? vehicle;
  final VoidCallback onSaved;

  const _VehicleFormSheet({
    required this.businessId,
    this.vehicle,
    required this.onSaved,
  });

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _priceController;
  late TextEditingController _mileageController;
  late TextEditingController _vinController;
  late TextEditingController _colorController;
  late TextEditingController _engineController;
  late TextEditingController _descriptionController;

  String _selectedCategory = VehicleCategories.all.first;
  VehicleCondition _selectedCondition = VehicleCondition.good;
  String? _selectedTransmission;
  String? _selectedFuelType;
  bool _isFeatured = false;
  bool _isCertified = false;

  final List<String> _transmissions = ['Automatic', 'Manual', 'CVT'];
  final List<String> _fuelTypes = ['Gasoline', 'Diesel', 'Electric', 'Hybrid'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _makeController = TextEditingController(text: v?.make ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(
        text: v?.year.toString() ?? DateTime.now().year.toString());
    _priceController =
        TextEditingController(text: v?.price.toStringAsFixed(0) ?? '');
    _mileageController =
        TextEditingController(text: v?.mileage.toString() ?? '0');
    _vinController = TextEditingController(text: v?.vin ?? '');
    _colorController = TextEditingController(text: v?.color ?? '');
    _engineController = TextEditingController(text: v?.engine ?? '');
    _descriptionController = TextEditingController(text: v?.description ?? '');

    if (v != null) {
      _selectedCategory = v.category;
      _selectedCondition = v.condition;
      _selectedTransmission = v.transmission;
      _selectedFuelType = v.fuelType;
      _isFeatured = v.isFeatured;
      _isCertified = v.isCertified;
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _mileageController.dispose();
    _vinController.dispose();
    _colorController.dispose();
    _engineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicle != null;

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
                // Handle
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
                  isEditing ? 'Edit Vehicle' : 'Add New Vehicle',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Make and Model
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _makeController,
                        decoration: const InputDecoration(
                          labelText: 'Make *',
                          hintText: 'e.g., Toyota',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model *',
                          hintText: 'e.g., Camry',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Year and Category
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'Year *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: VehicleCategories.all.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price and Mileage
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price *',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _mileageController,
                        decoration: const InputDecoration(
                          labelText: 'Mileage',
                          suffixText: 'miles',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Condition
                DropdownButtonFormField<VehicleCondition>(
                  initialValue: _selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: VehicleCondition.values.map((cond) {
                    return DropdownMenuItem(
                      value: cond,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cond.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(cond.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCondition = v);
                  },
                ),
                const SizedBox(height: 16),

                // Transmission and Fuel
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedTransmission,
                        decoration: const InputDecoration(
                          labelText: 'Transmission',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Select'),
                          ),
                          ..._transmissions.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedTransmission = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedFuelType,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Select'),
                          ),
                          ..._fuelTypes.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f));
                          }),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedFuelType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Color and VIN
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _vinController,
                        decoration: const InputDecoration(
                          labelText: 'VIN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Engine
                TextFormField(
                  controller: _engineController,
                  decoration: const InputDecoration(
                    labelText: 'Engine',
                    hintText: 'e.g., 2.5L 4-Cylinder',
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
                        title: const Text('Certified'),
                        value: _isCertified,
                        onChanged: (v) => setState(() => _isCertified = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveVehicle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Vehicle' : 'Add Vehicle'),
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

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'businessId': widget.businessId,
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.tryParse(_yearController.text) ?? DateTime.now().year,
        'category': _selectedCategory,
        'condition': _selectedCondition.name,
        'status': widget.vehicle?.status.name ?? 'available',
        'price': double.tryParse(_priceController.text) ?? 0,
        'mileage': int.tryParse(_mileageController.text) ?? 0,
        'vin':
            _vinController.text.trim().isNotEmpty ? _vinController.text.trim() : null,
        'color': _colorController.text.trim().isNotEmpty
            ? _colorController.text.trim()
            : null,
        'transmission': _selectedTransmission,
        'fuelType': _selectedFuelType,
        'engine': _engineController.text.trim().isNotEmpty
            ? _engineController.text.trim()
            : null,
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'isFeatured': _isFeatured,
        'isCertified': _isCertified,
        'createdAt': widget.vehicle?.createdAt != null
            ? Timestamp.fromDate(widget.vehicle!.createdAt)
            : Timestamp.now(),
      };

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('vehicles');

      if (widget.vehicle != null) {
        await collection.doc(widget.vehicle!.id).update(data);
      } else {
        await collection.add(data);
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

/// Vehicle details sheet
class _VehicleDetailsSheet extends StatelessWidget {
  final VehicleModel vehicle;
  final String businessId;
  final VoidCallback onEdit;

  const _VehicleDetailsSheet({
    required this.vehicle,
    required this.businessId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = VehicleCategories.getColor(vehicle.category);
    final formatter = NumberFormat('#,###');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    image: vehicle.images != null && vehicle.images!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(vehicle.images!.first),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (vehicle.images == null || vehicle.images!.isEmpty)
                        Center(
                          child: Icon(
                            VehicleCategories.getIcon(vehicle.category),
                            size: 80,
                            color: categoryColor.withValues(alpha: 0.3),
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
                                  vehicle.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: vehicle.status.color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        vehicle.status.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: vehicle.condition.color
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        vehicle.condition.displayName,
                                        style: TextStyle(
                                          color: vehicle.condition.color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${formatter.format(vehicle.price)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Specs grid
                      _buildSection(
                        'Specifications',
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildSpecItem(
                                Icons.speed, 'Mileage', vehicle.formattedMileage),
                            if (vehicle.transmission != null)
                              _buildSpecItem(Icons.settings, 'Transmission',
                                  vehicle.transmission!),
                            if (vehicle.fuelType != null)
                              _buildSpecItem(Icons.local_gas_station, 'Fuel',
                                  vehicle.fuelType!),
                            if (vehicle.engine != null)
                              _buildSpecItem(
                                  Icons.engineering, 'Engine', vehicle.engine!),
                            if (vehicle.color != null)
                              _buildSpecItem(
                                  Icons.palette, 'Color', vehicle.color!),
                            _buildSpecItem(Icons.category, 'Type', vehicle.category),
                          ],
                        ),
                      ),

                      if (vehicle.vin != null) ...[
                        const SizedBox(height: 24),
                        _buildSection(
                          'VIN',
                          Text(
                            vehicle.vin!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],

                      if (vehicle.description != null) ...[
                        const SizedBox(height: 24),
                        _buildSection(
                          'Description',
                          Text(vehicle.description!),
                        ),
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

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
