import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';

/// Pet service categories (industry-standard for Indian pet care market)
class PetServiceCategories {
  static const List<String> all = [
    'Grooming',
    'Boarding',
    'Training',
    'Daycare',
    'Walking',
    'Veterinary',
    'Vaccination',
    'Dental Care',
    'Pet Spa',
    'Pet Taxi',
    'Pet Sitting',
    'Adoption',
    'Emergency Care',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'grooming':
        return Icons.content_cut;
      case 'boarding':
        return Icons.night_shelter;
      case 'training':
        return Icons.school;
      case 'daycare':
        return Icons.wb_sunny;
      case 'walking':
        return Icons.directions_walk;
      case 'veterinary':
        return Icons.local_hospital;
      case 'vaccination':
        return Icons.vaccines;
      case 'dental care':
        return Icons.medical_services;
      case 'pet spa':
        return Icons.spa;
      case 'pet taxi':
        return Icons.local_taxi;
      case 'pet sitting':
        return Icons.home;
      case 'adoption':
        return Icons.favorite;
      case 'emergency care':
        return Icons.emergency;
      default:
        return Icons.pets;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'grooming':
        return const Color(0xFFA855F7);
      case 'boarding':
        return const Color(0xFF3B82F6);
      case 'training':
        return const Color(0xFF10B981);
      case 'daycare':
        return const Color(0xFFF59E0B);
      case 'walking':
        return const Color(0xFF06B6D4);
      case 'veterinary':
        return const Color(0xFFEF4444);
      case 'vaccination':
        return const Color(0xFF8B5CF6);
      case 'dental care':
        return const Color(0xFFEC4899);
      case 'pet spa':
        return const Color(0xFFD946EF);
      case 'pet taxi':
        return const Color(0xFF64748B);
      case 'pet sitting':
        return const Color(0xFF14B8A6);
      case 'adoption':
        return const Color(0xFFF43F5E);
      case 'emergency care':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFA855F7);
    }
  }
}

/// Pet service model for Firestore
class PetServiceModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String? priceUnit; // per session, per night, per walk, per month
  final String petType; // Dogs, Cats, All Pets, etc.
  final int durationMinutes;
  final bool isAvailable;
  final bool isEmergency;
  final String? imageUrl;
  final List<String> includes;
  final DateTime createdAt;

  PetServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.priceUnit,
    required this.petType,
    required this.durationMinutes,
    this.isAvailable = true,
    this.isEmergency = false,
    this.imageUrl,
    this.includes = const [],
    required this.createdAt,
  });

  factory PetServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Other',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      priceUnit: data['priceUnit'],
      petType: data['petType'] ?? 'All Pets',
      durationMinutes: data['durationMinutes'] ?? 30,
      isAvailable: data['isAvailable'] ?? true,
      isEmergency: data['isEmergency'] ?? false,
      imageUrl: data['imageUrl'],
      includes: List<String>.from(data['includes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'priceUnit': priceUnit,
      'petType': petType,
      'durationMinutes': durationMinutes,
      'isAvailable': isAvailable,
      'isEmergency': isEmergency,
      'imageUrl': imageUrl,
      'includes': includes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Pet Services Tab — manage grooming, boarding, training, etc.
class PetServicesTab extends StatefulWidget {
  final BusinessModel business;

  const PetServicesTab({super.key, required this.business});

  @override
  State<PetServicesTab> createState() => _PetServicesTabState();
}

class _PetServicesTabState extends State<PetServicesTab> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Category filter chips
        _buildCategoryFilters(isDark),

        // Services list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseProvider.firestore
                .collection('businesses')
                .doc(widget.business.id)
                .collection('pet_services')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final services = docs
                  .map((d) => PetServiceModel.fromFirestore(d))
                  .toList();

              final filtered = _selectedCategory == 'All'
                  ? services
                  : services
                        .where((s) => s.category == _selectedCategory)
                        .toList();

              if (filtered.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return _buildServiceCard(filtered[index], isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(bool isDark) {
    final categories = ['All', ...PetServiceCategories.all];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(cat),
              avatar: cat == 'All'
                  ? null
                  : Icon(
                      PetServiceCategories.getIcon(cat),
                      size: 16,
                      color: isSelected ? Colors.white : null,
                    ),
              selectedColor: const Color(0xFFA855F7),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.black87,
                fontSize: 13,
              ),
              onSelected: (selected) {
                setState(() => _selectedCategory = cat);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceCard(PetServiceModel service, bool isDark) {
    final catColor = PetServiceCategories.getColor(service.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showServiceDetails(service),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PetServiceCategories.getIcon(service.category),
                  color: catColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Service info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (service.isEmergency)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '24/7',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.pets, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          service.petType,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${service.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\u{20B9}${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA855F7),
                    ),
                  ),
                  if (service.priceUnit != null)
                    Text(
                      service.priceUnit!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? 'No services added yet'
                : 'No $_selectedCategory services',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add pet care services',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddServiceSheet(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showServiceDetails(PetServiceModel service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = PetServiceCategories.getColor(service.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Service header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      PetServiceCategories.getIcon(service.category),
                      color: catColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            service.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: catColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Price & details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DetailItem(
                      icon: Icons.currency_rupee,
                      label: 'Price',
                      value:
                          '\u{20B9}${service.price.toStringAsFixed(0)}${service.priceUnit != null ? " / ${service.priceUnit}" : ""}',
                      isDark: isDark,
                    ),
                    _DetailItem(
                      icon: Icons.access_time,
                      label: 'Duration',
                      value: '${service.durationMinutes} min',
                      isDark: isDark,
                    ),
                    _DetailItem(
                      icon: Icons.pets,
                      label: 'Pet Type',
                      value: service.petType,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description
              if (service.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Includes
              if (service.includes.isNotEmpty) ...[
                Text(
                  'Includes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...service.includes.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: catColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Status badges
              Row(
                children: [
                  _StatusBadge(
                    label: service.isAvailable ? 'Available' : 'Unavailable',
                    color: service.isAvailable ? Colors.green : Colors.grey,
                    isDark: isDark,
                  ),
                  if (service.isEmergency) ...[
                    const SizedBox(width: 8),
                    _StatusBadge(
                      label: '24/7 Emergency',
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddServiceSheet(existing: service);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA855F7),
                        side: const BorderSide(color: Color(0xFFA855F7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteService(service);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteService(PetServiceModel service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Remove "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('pet_services')
          .doc(service.id)
          .delete();
    }
  }

  void _showAddServiceSheet({PetServiceModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PetServiceFormSheet(
        businessId: widget.business.id,
        existing: existing,
      ),
    );
  }
}

// ─────────────────── Form Sheet ───────────────────

class _PetServiceFormSheet extends StatefulWidget {
  final String businessId;
  final PetServiceModel? existing;

  const _PetServiceFormSheet({required this.businessId, this.existing});

  @override
  State<_PetServiceFormSheet> createState() => _PetServiceFormSheetState();
}

class _PetServiceFormSheetState extends State<_PetServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _category;
  late String _description;
  late double _price;
  late String _priceUnit;
  late String _petType;
  late int _duration;
  late bool _isAvailable;
  late bool _isEmergency;
  late List<String> _includes;
  bool _saving = false;

  static const _petTypes = [
    'All Pets',
    'Dogs',
    'Cats',
    'Dogs & Cats',
    'Birds',
    'Fish',
    'Rabbits',
    'Small Animals',
    'Reptiles',
    'Exotic Pets',
  ];

  static const _priceUnits = [
    'per session',
    'per night',
    'per walk',
    'per month',
    'per day',
    'per hour',
    'per visit',
    'one-time',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = e?.name ?? '';
    _category = e?.category ?? PetServiceCategories.all.first;
    _description = e?.description ?? '';
    _price = e?.price ?? 0;
    _priceUnit = e?.priceUnit ?? _priceUnits.first;
    _petType = e?.petType ?? _petTypes.first;
    _duration = e?.durationMinutes ?? 30;
    _isAvailable = e?.isAvailable ?? true;
    _isEmergency = e?.isEmergency ?? false;
    _includes = e != null ? List<String>.from(e.includes) : [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existing != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.add_circle,
                  color: const Color(0xFFA855F7),
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Service' : 'Add Pet Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Name
                    TextFormField(
                      initialValue: _name,
                      decoration: InputDecoration(
                        labelText: 'Service Name *',
                        hintText: 'e.g., Full Body Grooming',
                        prefixIcon: const Icon(Icons.pets),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onSaved: (v) => _name = v!.trim(),
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: PetServiceCategories.all
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    PetServiceCategories.getIcon(c),
                                    size: 18,
                                    color: PetServiceCategories.getColor(c),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 16),

                    // Pet type
                    DropdownButtonFormField<String>(
                      initialValue: _petType,
                      decoration: InputDecoration(
                        labelText: 'Pet Type *',
                        prefixIcon: const Icon(Icons.pets),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _petTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _petType = v!),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      initialValue: _description,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What does this service include?',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                      onSaved: (v) => _description = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Price & unit row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: _price > 0
                                ? _price.toStringAsFixed(0)
                                : '',
                            decoration: InputDecoration(
                              labelText: 'Price (\u{20B9}) *',
                              prefixIcon: const Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                            onSaved: (v) =>
                                _price = double.tryParse(v ?? '0') ?? 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _priceUnit,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _priceUnits
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      u,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _priceUnit = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Duration
                    DropdownButtonFormField<int>(
                      initialValue: _duration,
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [15, 30, 45, 60, 90, 120, 180, 240, 480, 1440]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m < 60
                                    ? '$m min'
                                    : m < 1440
                                    ? '${m ~/ 60} hr${m >= 120 ? "s" : ""}'
                                    : '24 hrs (Full Day)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _duration = v!),
                    ),
                    const SizedBox(height: 16),

                    // Toggles
                    SwitchListTile(
                      title: const Text('Available'),
                      subtitle: const Text('Show this service as available'),
                      value: _isAvailable,
                      activeTrackColor: const Color(0xFFA855F7),
                      onChanged: (v) => setState(() => _isAvailable = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Emergency / 24x7 Service'),
                      subtitle: const Text(
                        'Available round the clock for emergencies',
                      ),
                      value: _isEmergency,
                      activeTrackColor: Colors.red,
                      onChanged: (v) => setState(() => _isEmergency = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // Includes
                    Text(
                      'What\'s Included',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._includes.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: entry.value,
                                decoration: InputDecoration(
                                  hintText: 'e.g., Shampoo bath',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (v) => _includes[entry.key] = v,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() => _includes.removeAt(entry.key));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _includes.add(''));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFA855F7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Service' : 'Add Service',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get isEditing => widget.existing != null;

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);

    try {
      final filteredIncludes = _includes
          .where((i) => i.trim().isNotEmpty)
          .toList();

      final data = {
        'name': _name,
        'category': _category,
        'description': _description,
        'price': _price,
        'priceUnit': _priceUnit,
        'petType': _petType,
        'durationMinutes': _duration,
        'isAvailable': _isAvailable,
        'isEmergency': _isEmergency,
        'includes': filteredIncludes,
        'createdAt': widget.existing != null
            ? Timestamp.fromDate(widget.existing!.createdAt)
            : FieldValue.serverTimestamp(),
      };

      final col = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('pet_services');

      if (widget.existing != null) {
        await col.doc(widget.existing!.id).update(data);
      } else {
        await col.add(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────── Helper Widgets ───────────────────

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFA855F7)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
