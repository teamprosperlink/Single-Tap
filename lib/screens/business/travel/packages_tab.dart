import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';

/// Tour package categories (aligned with MakeMyTrip, Goibibo, TripAdvisor, Viator, Klook)
class TourCategories {
  static const List<String> all = [
    'Domestic Tour',
    'International Tour',
    'Pilgrimage / Spiritual',
    'Adventure / Trekking',
    'Honeymoon / Romantic',
    'Wildlife & Safari',
    'Beach & Island',
    'Heritage & Culture',
    'Hill Station / Mountain',
    'Cruise',
    'Road Trip',
    'Corporate / MICE',
    'Weekend Getaway',
    'Luxury Tour',
    'Backpacking / Budget',
    'Group Tour',
    'Family Holiday',
    'Other',
  ];

  static IconData getIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('domestic')) return Icons.flag;
    if (lower.contains('international')) return Icons.public;
    if (lower.contains('pilgrimage') || lower.contains('spiritual')) {
      return Icons.temple_hindu;
    }
    if (lower.contains('adventure') || lower.contains('trekking')) {
      return Icons.terrain;
    }
    if (lower.contains('honeymoon') || lower.contains('romantic')) {
      return Icons.favorite;
    }
    if (lower.contains('wildlife') || lower.contains('safari')) {
      return Icons.pets;
    }
    if (lower.contains('beach') || lower.contains('island')) {
      return Icons.beach_access;
    }
    if (lower.contains('heritage') || lower.contains('culture')) {
      return Icons.account_balance;
    }
    if (lower.contains('hill') || lower.contains('mountain')) {
      return Icons.landscape;
    }
    if (lower.contains('cruise')) return Icons.directions_boat;
    if (lower.contains('road trip')) return Icons.directions_car;
    if (lower.contains('corporate') || lower.contains('mice')) {
      return Icons.business;
    }
    if (lower.contains('weekend')) return Icons.weekend;
    if (lower.contains('luxury')) return Icons.diamond;
    if (lower.contains('backpacking') || lower.contains('budget')) {
      return Icons.backpack;
    }
    if (lower.contains('group')) return Icons.groups;
    if (lower.contains('family')) return Icons.family_restroom;
    return Icons.tour;
  }

  static Color getColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('domestic')) return const Color(0xFF4CAF50);
    if (lower.contains('international')) return const Color(0xFF2196F3);
    if (lower.contains('pilgrimage') || lower.contains('spiritual')) {
      return const Color(0xFFFF9800);
    }
    if (lower.contains('adventure') || lower.contains('trekking')) {
      return const Color(0xFFF44336);
    }
    if (lower.contains('honeymoon') || lower.contains('romantic')) {
      return const Color(0xFFE91E63);
    }
    if (lower.contains('wildlife') || lower.contains('safari')) {
      return const Color(0xFF795548);
    }
    if (lower.contains('beach') || lower.contains('island')) {
      return const Color(0xFF00BCD4);
    }
    if (lower.contains('heritage') || lower.contains('culture')) {
      return const Color(0xFF9C27B0);
    }
    if (lower.contains('hill') || lower.contains('mountain')) {
      return const Color(0xFF4DB6AC);
    }
    if (lower.contains('cruise')) return const Color(0xFF1565C0);
    if (lower.contains('road trip')) return const Color(0xFFFF5722);
    if (lower.contains('corporate') || lower.contains('mice')) {
      return const Color(0xFF37474F);
    }
    if (lower.contains('weekend')) return const Color(0xFF66BB6A);
    if (lower.contains('luxury')) return const Color(0xFFAB47BC);
    if (lower.contains('backpacking') || lower.contains('budget')) {
      return const Color(0xFF8BC34A);
    }
    if (lower.contains('group')) return const Color(0xFF42A5F5);
    if (lower.contains('family')) return const Color(0xFFFFB74D);
    return const Color(0xFF78909C);
  }
}

/// Difficulty levels for adventure/trekking tours
class DifficultyLevel {
  static const List<String> all = [
    'Easy',
    'Moderate',
    'Challenging',
    'Difficult',
    'Expert Only',
  ];
}

/// Package status
enum PackageStatus {
  active,
  upcoming,
  soldOut,
  inactive;

  String get displayName {
    switch (this) {
      case PackageStatus.active:
        return 'Active';
      case PackageStatus.upcoming:
        return 'Upcoming';
      case PackageStatus.soldOut:
        return 'Sold Out';
      case PackageStatus.inactive:
        return 'Inactive';
    }
  }

  Color get color {
    switch (this) {
      case PackageStatus.active:
        return const Color(0xFF4CAF50);
      case PackageStatus.upcoming:
        return const Color(0xFF2196F3);
      case PackageStatus.soldOut:
        return const Color(0xFFF44336);
      case PackageStatus.inactive:
        return Colors.grey;
    }
  }

  static PackageStatus fromString(String? value) {
    if (value == null) return PackageStatus.active;

    // Normalize camelCase to match enum names
    switch (value) {
      case 'active':
      case 'Active':
        return PackageStatus.active;
      case 'upcoming':
      case 'Upcoming':
        return PackageStatus.upcoming;
      case 'soldOut':
      case 'sold_out':
      case 'Sold Out':
        return PackageStatus.soldOut;
      case 'inactive':
      case 'Inactive':
        return PackageStatus.inactive;
      default:
        return PackageStatus.active;
    }
  }
}

/// Tour package model (aligned with MakeMyTrip, TripAdvisor, Viator, Klook)
class TourPackageModel {
  final String id;
  final String businessId;
  final String title;
  final String? description;
  final String category;
  final PackageStatus status;
  final double pricePerPerson;
  final double? originalPrice;
  final String? destination;
  final String? departureCity;
  final int durationDays;
  final int durationNights;
  final int? minGroupSize;
  final int? maxGroupSize;
  final String? difficulty;
  final List<String>? inclusions;
  final List<String>? exclusions;
  final List<String>? highlights;
  final List<String>? itinerary;
  final List<String>? images;
  final String? mealsIncluded;
  final String? transportMode;
  final String? accommodationType;
  final bool isFeatured;
  final bool isCustomizable;
  final bool hasPickupDrop;
  final bool hasGuide;
  final double? rating;
  final int? reviewCount;
  final int? bookingsCount;
  final DateTime? nextDepartureDate;
  final DateTime createdAt;

  TourPackageModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.description,
    required this.category,
    this.status = PackageStatus.active,
    required this.pricePerPerson,
    this.originalPrice,
    this.destination,
    this.departureCity,
    required this.durationDays,
    required this.durationNights,
    this.minGroupSize,
    this.maxGroupSize,
    this.difficulty,
    this.inclusions,
    this.exclusions,
    this.highlights,
    this.itinerary,
    this.images,
    this.mealsIncluded,
    this.transportMode,
    this.accommodationType,
    this.isFeatured = false,
    this.isCustomizable = false,
    this.hasPickupDrop = false,
    this.hasGuide = false,
    this.rating,
    this.reviewCount,
    this.bookingsCount,
    this.nextDepartureDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get durationDisplay => '$durationDays Days / $durationNights Nights';

  String get groupSizeDisplay {
    if (minGroupSize != null && maxGroupSize != null) {
      return '$minGroupSize - $maxGroupSize persons';
    }
    if (maxGroupSize != null) return 'Up to $maxGroupSize persons';
    return '';
  }

  factory TourPackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TourPackageModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      status: PackageStatus.fromString(data['status']),
      pricePerPerson: (data['pricePerPerson'] ?? 0).toDouble(),
      originalPrice: data['originalPrice']?.toDouble(),
      destination: data['destination'],
      departureCity: data['departureCity'],
      durationDays: data['durationDays'] ?? 1,
      durationNights: data['durationNights'] ?? 0,
      minGroupSize: data['minGroupSize'],
      maxGroupSize: data['maxGroupSize'],
      difficulty: data['difficulty'],
      inclusions: data['inclusions'] != null
          ? List<String>.from(data['inclusions'])
          : null,
      exclusions: data['exclusions'] != null
          ? List<String>.from(data['exclusions'])
          : null,
      highlights: data['highlights'] != null
          ? List<String>.from(data['highlights'])
          : null,
      itinerary: data['itinerary'] != null
          ? List<String>.from(data['itinerary'])
          : null,
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      mealsIncluded: data['mealsIncluded'],
      transportMode: data['transportMode'],
      accommodationType: data['accommodationType'],
      isFeatured: data['isFeatured'] ?? false,
      isCustomizable: data['isCustomizable'] ?? false,
      hasPickupDrop: data['hasPickupDrop'] ?? false,
      hasGuide: data['hasGuide'] ?? false,
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'],
      bookingsCount: data['bookingsCount'],
      nextDepartureDate: data['nextDepartureDate'] != null
          ? (data['nextDepartureDate'] as Timestamp).toDate()
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
      'category': category,
      'status': status.name,
      'pricePerPerson': pricePerPerson,
      'originalPrice': originalPrice,
      'destination': destination,
      'departureCity': departureCity,
      'durationDays': durationDays,
      'durationNights': durationNights,
      'minGroupSize': minGroupSize,
      'maxGroupSize': maxGroupSize,
      'difficulty': difficulty,
      'inclusions': inclusions,
      'exclusions': exclusions,
      'highlights': highlights,
      'itinerary': itinerary,
      'images': images,
      'mealsIncluded': mealsIncluded,
      'transportMode': transportMode,
      'accommodationType': accommodationType,
      'isFeatured': isFeatured,
      'isCustomizable': isCustomizable,
      'hasPickupDrop': hasPickupDrop,
      'hasGuide': hasGuide,
      'rating': rating,
      'reviewCount': reviewCount,
      'bookingsCount': bookingsCount,
      'nextDepartureDate': nextDepartureDate != null
          ? Timestamp.fromDate(nextDepartureDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Travel packages management tab
class PackagesTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const PackagesTab({super.key, required this.business, this.onRefresh});

  @override
  State<PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<PackagesTab> {
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDarkMode),
            _buildFilterChips(isDarkMode),
            Expanded(child: _buildPackagesList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPackageForm(context),
        backgroundColor: const Color(0xFF06B6D4),
        icon: const Icon(Icons.add),
        label: const Text('Add Package'),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tour, color: Color(0xFF06B6D4), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tour Packages',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Manage your tour packages',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _convertStatusToFirestore(String uiLabel) {
    // Convert UI labels (from filter chips) to enum names stored in Firestore
    switch (uiLabel) {
      case 'Active':
        return 'active';
      case 'Upcoming':
        return 'upcoming';
      case 'Sold Out':
        return 'soldOut';
      case 'Inactive':
        return 'inactive';
      default:
        return 'active';
    }
  }

  Widget _buildFilterChips(bool isDarkMode) {
    final categories = ['All', ...TourCategories.all.take(8)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Category filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF06B6D4),
                    backgroundColor: isDarkMode
                        ? const Color(0xFF2D2D44)
                        : Colors.white,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Status filter
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['All', 'Active', 'Upcoming', 'Sold Out'].map((status) {
                final isSelected = status == _selectedStatus;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white54 : Colors.grey[700]),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFF06B6D4,
                    ).withValues(alpha: 0.8),
                    backgroundColor: isDarkMode
                        ? const Color(0xFF2D2D44)
                        : Colors.grey[100],
                    onSelected: (_) => setState(() => _selectedStatus = status),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPackagesList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('packages');

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    if (_selectedStatus != 'All') {
      // Convert UI label to camelCase to match Firestore storage (status.name)
      final statusValue = _convertStatusToFirestore(_selectedStatus);
      query = query.where('status', isEqualTo: statusValue);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final packages = snapshot.data!.docs
            .map((doc) => TourPackageModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            return _PackageCard(
              package: packages[index],
              onTap: () => _showPackageDetails(packages[index]),
              onEdit: () => _showPackageForm(context, package: packages[index]),
              onDelete: () => _deletePackage(packages[index]),
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
          Icon(Icons.tour, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No packages yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tour packages — domestic, international,\nadventure, pilgrimage & more',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showPackageForm(BuildContext context, {TourPackageModel? package}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageFormSheet(
        businessId: widget.business.id,
        package: package,
        onSaved: () {
          Navigator.pop(context);
          widget.onRefresh?.call();
        },
      ),
    );
  }

  void _showPackageDetails(TourPackageModel package) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageDetailsSheet(package: package),
    );
  }

  Future<void> _deletePackage(TourPackageModel package) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Delete "${package.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('packages')
          .doc(package.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Package deleted')));
      }
    }
  }
}

/// Package card widget
class _PackageCard extends StatelessWidget {
  final TourPackageModel package;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PackageCard({
    required this.package,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final catColor = TourCategories.getColor(package.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header with status & category badge
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  colors: [catColor, catColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Background icon
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      TourCategories.getIcon(package.category),
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: package.status.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        package.status.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Featured badge
                  if (package.isFeatured)
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
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
                  // Category
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TourCategories.getIcon(package.category),
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            package.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Price
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (package.originalPrice != null &&
                              package.originalPrice! > package.pricePerPerson)
                            Text(
                              '₹${_formatPrice(package.originalPrice!)}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹${_formatPrice(package.pricePerPerson)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'per person',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    package.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Destination
                  if (package.destination != null)
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: catColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            package.destination!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Specs row
                  Row(
                    children: [
                      _buildSpecChip(
                        Icons.schedule,
                        package.durationDisplay,
                        isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      if (package.groupSizeDisplay.isNotEmpty)
                        _buildSpecChip(
                          Icons.group,
                          package.groupSizeDisplay,
                          isDarkMode,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Tags row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (package.hasGuide)
                        _buildTag('Guide', Icons.person, Colors.blue),
                      if (package.hasPickupDrop)
                        _buildTag(
                          'Pickup',
                          Icons.airport_shuttle,
                          Colors.green,
                        ),
                      if (package.isCustomizable)
                        _buildTag('Customizable', Icons.tune, Colors.purple),
                      if (package.mealsIncluded != null)
                        _buildTag(
                          package.mealsIncluded!,
                          Icons.restaurant,
                          Colors.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Rating & actions row
                  Row(
                    children: [
                      if (package.rating != null) ...[
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(
                          package.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (package.reviewCount != null)
                          Text(
                            ' (${package.reviewCount})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        color: Colors.red[400],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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

  Widget _buildSpecChip(IconData icon, String text, bool isDarkMode) {
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
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)} L';
    } else if (price >= 1000) {
      final formatter = NumberFormat('#,###');
      return formatter.format(price);
    }
    return price.toStringAsFixed(0);
  }
}

/// Package form sheet
class _PackageFormSheet extends StatefulWidget {
  final String businessId;
  final TourPackageModel? package;
  final VoidCallback onSaved;

  const _PackageFormSheet({
    required this.businessId,
    this.package,
    required this.onSaved,
  });

  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _destinationController;
  late TextEditingController _departureCityController;
  late TextEditingController _daysController;
  late TextEditingController _nightsController;
  late TextEditingController _minGroupController;
  late TextEditingController _maxGroupController;

  String _selectedCategory = TourCategories.all.first;
  String? _selectedDifficulty;
  String? _selectedMeals;
  String? _selectedTransport;
  String? _selectedAccommodation;
  bool _isFeatured = false;
  bool _isCustomizable = false;
  bool _hasPickupDrop = false;
  bool _hasGuide = false;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(
      text: p?.pricePerPerson.toStringAsFixed(0) ?? '',
    );
    _originalPriceController = TextEditingController(
      text: p?.originalPrice?.toStringAsFixed(0) ?? '',
    );
    _destinationController = TextEditingController(text: p?.destination ?? '');
    _departureCityController = TextEditingController(
      text: p?.departureCity ?? '',
    );
    _daysController = TextEditingController(
      text: p?.durationDays.toString() ?? '1',
    );
    _nightsController = TextEditingController(
      text: p?.durationNights.toString() ?? '0',
    );
    _minGroupController = TextEditingController(
      text: p?.minGroupSize?.toString() ?? '',
    );
    _maxGroupController = TextEditingController(
      text: p?.maxGroupSize?.toString() ?? '',
    );

    if (p != null) {
      _selectedCategory = p.category;
      _selectedDifficulty = p.difficulty;
      _selectedMeals = p.mealsIncluded;
      _selectedTransport = p.transportMode;
      _selectedAccommodation = p.accommodationType;
      _isFeatured = p.isFeatured;
      _isCustomizable = p.isCustomizable;
      _hasPickupDrop = p.hasPickupDrop;
      _hasGuide = p.hasGuide;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _destinationController.dispose();
    _departureCityController.dispose();
    _daysController.dispose();
    _nightsController.dispose();
    _minGroupController.dispose();
    _maxGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.package != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isEditing ? 'Edit Package' : 'Add Tour Package',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Package Title *',
                        hintText: 'e.g., Royal Rajasthan Heritage Tour',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category & Difficulty
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                            ),
                            items: TourCategories.all.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedDifficulty,
                            decoration: const InputDecoration(
                              labelText: 'Difficulty',
                              border: OutlineInputBorder(),
                            ),
                            items: [null, ...DifficultyLevel.all].map((d) {
                              return DropdownMenuItem<String?>(
                                value: d,
                                child: Text(
                                  d ?? 'Not Specified',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedDifficulty = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Destination & Departure
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _destinationController,
                            decoration: const InputDecoration(
                              labelText: 'Destination *',
                              hintText: 'e.g., Jaipur - Udaipur - Jodhpur',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _departureCityController,
                            decoration: const InputDecoration(
                              labelText: 'Departure City',
                              hintText: 'e.g., Delhi, Mumbai',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price / Person *',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _originalPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Original Price',
                              prefixText: '₹ ',
                              hintText: 'Before discount',
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

                    // Duration
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _daysController,
                            decoration: const InputDecoration(
                              labelText: 'Days *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nightsController,
                            decoration: const InputDecoration(
                              labelText: 'Nights *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _minGroupController,
                            decoration: const InputDecoration(
                              labelText: 'Min Group',
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
                            controller: _maxGroupController,
                            decoration: const InputDecoration(
                              labelText: 'Max Group',
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

                    // Meals, Transport, Accommodation
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedMeals,
                            decoration: const InputDecoration(
                              labelText: 'Meals',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                [
                                  null,
                                  'Breakfast Only',
                                  'Breakfast + Dinner',
                                  'All Meals',
                                  'No Meals',
                                ].map((m) {
                                  return DropdownMenuItem<String?>(
                                    value: m,
                                    child: Text(
                                      m ?? 'Not Specified',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedMeals = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedTransport,
                            decoration: const InputDecoration(
                              labelText: 'Transport',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                [
                                  null,
                                  'AC Bus / Volvo',
                                  'Private Car / SUV',
                                  'Train',
                                  'Flight',
                                  'Mixed',
                                  'Self-Drive',
                                ].map((t) {
                                  return DropdownMenuItem<String?>(
                                    value: t,
                                    child: Text(
                                      t ?? 'Not Specified',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedTransport = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Accommodation
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedAccommodation,
                      decoration: const InputDecoration(
                        labelText: 'Accommodation',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                            null,
                            '3-Star Hotel',
                            '4-Star Hotel',
                            '5-Star Hotel',
                            'Resort',
                            'Homestay',
                            'Tent / Camp',
                            'Hostel / Dormitory',
                            'Houseboat',
                            'Mixed',
                          ].map((a) {
                            return DropdownMenuItem<String?>(
                              value: a,
                              child: Text(
                                a ?? 'Not Specified',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedAccommodation = v),
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
                            title: const Text('Customizable'),
                            value: _isCustomizable,
                            onChanged: (v) =>
                                setState(() => _isCustomizable = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Pickup & Drop'),
                            value: _hasPickupDrop,
                            onChanged: (v) =>
                                setState(() => _hasPickupDrop = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Tour Guide'),
                            value: _hasGuide,
                            onChanged: (v) => setState(() => _hasGuide = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePackage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Package' : 'Add Package',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePackage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'businessId': widget.businessId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'category': _selectedCategory,
        'status': widget.package?.status.name ?? 'active',
        'pricePerPerson': double.tryParse(_priceController.text) ?? 0,
        'originalPrice': _originalPriceController.text.isNotEmpty
            ? double.tryParse(_originalPriceController.text)
            : null,
        'destination': _destinationController.text.trim().isNotEmpty
            ? _destinationController.text.trim()
            : null,
        'departureCity': _departureCityController.text.trim().isNotEmpty
            ? _departureCityController.text.trim()
            : null,
        'durationDays': int.tryParse(_daysController.text) ?? 1,
        'durationNights': int.tryParse(_nightsController.text) ?? 0,
        'minGroupSize': _minGroupController.text.isNotEmpty
            ? int.tryParse(_minGroupController.text)
            : null,
        'maxGroupSize': _maxGroupController.text.isNotEmpty
            ? int.tryParse(_maxGroupController.text)
            : null,
        'difficulty': _selectedDifficulty,
        'mealsIncluded': _selectedMeals,
        'transportMode': _selectedTransport,
        'accommodationType': _selectedAccommodation,
        'isFeatured': _isFeatured,
        'isCustomizable': _isCustomizable,
        'hasPickupDrop': _hasPickupDrop,
        'hasGuide': _hasGuide,
        'createdAt': widget.package?.createdAt != null
            ? Timestamp.fromDate(widget.package!.createdAt)
            : Timestamp.now(),
      };

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('packages');

      if (widget.package != null) {
        await collection.doc(widget.package!.id).update(data);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/// Package details sheet
class _PackageDetailsSheet extends StatelessWidget {
  final TourPackageModel package;

  const _PackageDetailsSheet({required this.package});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final catColor = TourCategories.getColor(package.category);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    TourCategories.getIcon(package.category),
                                    size: 14,
                                    color: catColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    package.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: catColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              package.title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            if (package.destination != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.place, size: 16, color: catColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    package.destination!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (package.originalPrice != null &&
                              package.originalPrice! > package.pricePerPerson)
                            Text(
                              '₹${_formatDetailPrice(package.originalPrice!)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹${_formatDetailPrice(package.pricePerPerson)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                          Text(
                            'per person',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Key details grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2D2D44)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildDetailItem(
                          Icons.schedule,
                          'Duration',
                          package.durationDisplay,
                        ),
                        if (package.departureCity != null)
                          _buildDetailItem(
                            Icons.flight_takeoff,
                            'Departure',
                            package.departureCity!,
                          ),
                        if (package.groupSizeDisplay.isNotEmpty)
                          _buildDetailItem(
                            Icons.group,
                            'Group Size',
                            package.groupSizeDisplay,
                          ),
                        if (package.difficulty != null)
                          _buildDetailItem(
                            Icons.trending_up,
                            'Difficulty',
                            package.difficulty!,
                          ),
                        if (package.mealsIncluded != null)
                          _buildDetailItem(
                            Icons.restaurant,
                            'Meals',
                            package.mealsIncluded!,
                          ),
                        if (package.transportMode != null)
                          _buildDetailItem(
                            Icons.directions_bus,
                            'Transport',
                            package.transportMode!,
                          ),
                        if (package.accommodationType != null)
                          _buildDetailItem(
                            Icons.hotel,
                            'Stay',
                            package.accommodationType!,
                          ),
                      ],
                    ),
                  ),

                  // Tags
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (package.hasGuide)
                        _buildFeatureChip(
                          Icons.person,
                          'Tour Guide Included',
                          Colors.blue,
                        ),
                      if (package.hasPickupDrop)
                        _buildFeatureChip(
                          Icons.airport_shuttle,
                          'Pickup & Drop',
                          Colors.green,
                        ),
                      if (package.isCustomizable)
                        _buildFeatureChip(
                          Icons.tune,
                          'Customizable',
                          Colors.purple,
                        ),
                      if (package.isFeatured)
                        _buildFeatureChip(
                          Icons.star,
                          'Featured Package',
                          Colors.amber,
                        ),
                    ],
                  ),

                  // Description
                  if (package.description != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'About This Tour',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      package.description!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],

                  // Highlights
                  if (package.highlights != null &&
                      package.highlights!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Highlights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...package.highlights!.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: catColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Inclusions
                  if (package.inclusions != null &&
                      package.inclusions!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Inclusions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...package.inclusions!.map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.add_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                i,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Exclusions
                  if (package.exclusions != null &&
                      package.exclusions!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Exclusions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...package.exclusions!.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.remove_circle,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Itinerary
                  if (package.itinerary != null &&
                      package.itinerary!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Itinerary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...package.itinerary!.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Rating
                  if (package.rating != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 4),
                        Text(
                          package.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (package.reviewCount != null)
                          Text(
                            ' (${package.reviewCount} reviews)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        if (package.bookingsCount != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.shopping_bag,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${package.bookingsCount} bookings',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailPrice(double price) {
    if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      final formatter = NumberFormat('#,###');
      return formatter.format(price);
    }
    return price.toStringAsFixed(0);
  }
}
