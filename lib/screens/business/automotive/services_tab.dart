import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';

/// Automotive service categories (aligned with GoMechanic, myTVS, Bosch Car Service)
class AutoServiceCategories {
  static const List<String> all = [
    'Periodic Service',
    'Oil Change & Lube',
    'Brake Service',
    'Tire & Wheel',
    'Engine Repair',
    'Transmission',
    'AC / Climate Control',
    'Electrical & Battery',
    'Suspension & Steering',
    'Denting & Painting',
    'Car Wash & Detailing',
    'Body Work / Collision',
    'Diagnostics & Inspection',
    'Exhaust System',
    'Clutch & Gearbox',
    'Windshield & Glass',
    'EV Service',
    'Towing & Roadside',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'periodic service':
        return Icons.build_circle;
      case 'oil change & lube':
        return Icons.opacity;
      case 'brake service':
        return Icons.do_not_step;
      case 'tire & wheel':
        return Icons.tire_repair;
      case 'engine repair':
        return Icons.engineering;
      case 'transmission':
        return Icons.settings;
      case 'ac / climate control':
        return Icons.ac_unit;
      case 'electrical & battery':
        return Icons.electrical_services;
      case 'suspension & steering':
        return Icons.airline_seat_legroom_normal;
      case 'denting & painting':
        return Icons.format_paint;
      case 'car wash & detailing':
        return Icons.auto_awesome;
      case 'body work / collision':
        return Icons.car_repair;
      case 'diagnostics & inspection':
        return Icons.search;
      case 'exhaust system':
        return Icons.air;
      case 'clutch & gearbox':
        return Icons.settings_applications;
      case 'windshield & glass':
        return Icons.window;
      case 'ev service':
        return Icons.electric_car;
      case 'towing & roadside':
        return Icons.local_shipping;
      default:
        return Icons.build;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'periodic service':
        return const Color(0xFF4CAF50);
      case 'oil change & lube':
        return const Color(0xFF795548);
      case 'brake service':
        return const Color(0xFFF44336);
      case 'tire & wheel':
        return const Color(0xFF212121);
      case 'engine repair':
        return const Color(0xFF607D8B);
      case 'transmission':
        return const Color(0xFF9E9E9E);
      case 'ac / climate control':
        return const Color(0xFF2196F3);
      case 'electrical & battery':
        return const Color(0xFFFF9800);
      case 'suspension & steering':
        return const Color(0xFF009688);
      case 'denting & painting':
        return const Color(0xFFE91E63);
      case 'car wash & detailing':
        return const Color(0xFF9C27B0);
      case 'body work / collision':
        return const Color(0xFFFF5722);
      case 'diagnostics & inspection':
        return const Color(0xFF3F51B5);
      case 'exhaust system':
        return const Color(0xFF757575);
      case 'clutch & gearbox':
        return const Color(0xFF455A64);
      case 'windshield & glass':
        return const Color(0xFF00BCD4);
      case 'ev service':
        return const Color(0xFF00E676);
      case 'towing & roadside':
        return const Color(0xFFFF6F00);
      default:
        return const Color(0xFF607D8B);
    }
  }
}

/// Auto service model
class AutoServiceModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double? laborCost;
  final double? partsCost;
  final int estimatedMins;
  final bool isPriceEstimate; // Is this an estimate or fixed price?
  final bool includesParts;
  final List<String>? includedServices; // What's included
  final bool isPopular;
  final bool isActive;
  final DateTime createdAt;

  AutoServiceModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.laborCost,
    this.partsCost,
    this.estimatedMins = 60,
    this.isPriceEstimate = false,
    this.includesParts = true,
    this.includedServices,
    this.isPopular = false,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedDuration {
    if (estimatedMins < 60) {
      return '$estimatedMins min';
    } else if (estimatedMins % 60 == 0) {
      return '${estimatedMins ~/ 60} hr';
    } else {
      return '${estimatedMins ~/ 60}h ${estimatedMins % 60}m';
    }
  }

  factory AutoServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AutoServiceModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      price: (data['price'] ?? 0).toDouble(),
      laborCost: data['laborCost']?.toDouble(),
      partsCost: data['partsCost']?.toDouble(),
      estimatedMins: data['estimatedMins'] ?? 60,
      isPriceEstimate: data['isPriceEstimate'] ?? false,
      includesParts: data['includesParts'] ?? true,
      includedServices: data['includedServices'] != null
          ? List<String>.from(data['includedServices'])
          : null,
      isPopular: data['isPopular'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'laborCost': laborCost,
      'partsCost': partsCost,
      'estimatedMins': estimatedMins,
      'isPriceEstimate': isPriceEstimate,
      'includesParts': includesParts,
      'includedServices': includedServices,
      'isPopular': isPopular,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Automotive services tab
class AutomotiveServicesTab extends StatefulWidget {
  final BusinessModel business;

  const AutomotiveServicesTab({super.key, required this.business});

  @override
  State<AutomotiveServicesTab> createState() => _AutomotiveServicesTabState();
}

class _AutomotiveServicesTabState extends State<AutomotiveServicesTab> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category filter
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AutoServiceCategories.all.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategory == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
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

              final category = AutoServiceCategories.all[index - 1];
              final isSelected = _selectedCategory == category;
              final color = AutoServiceCategories.getColor(category);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    AutoServiceCategories.getIcon(category),
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

        // Services list
        Expanded(
          child: _buildServicesList(),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showServiceForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('auto_services')
        .where('isActive', isEqualTo: true);

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    query = query.orderBy('name').limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = snapshot.data!.docs
            .map((doc) => AutoServiceModel.fromFirestore(doc))
            .toList();

        if (services.isEmpty) {
          return _buildEmptyState();
        }

        // Group by category
        final grouped = <String, List<AutoServiceModel>>{};
        for (final service in services) {
          grouped.putIfAbsent(service.category, () => []).add(service);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final category = grouped.keys.elementAt(index);
            final categoryServices = grouped[category]!;
            final color = AutoServiceCategories.getColor(category);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      AutoServiceCategories.getIcon(category),
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...categoryServices.map((service) => _ServiceCard(
                      service: service,
                      onTap: () => _showServiceDetails(service),
                      onEdit: () => _showServiceForm(service: service),
                      onDelete: () => _deleteService(service),
                    )),
              ],
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
            Icons.build,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No services yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add auto services to offer',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showServiceForm({AutoServiceModel? service}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceFormSheet(
        businessId: widget.business.id,
        service: service,
        onSaved: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showServiceDetails(AutoServiceModel service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceDetailsSheet(
        service: service,
        onEdit: () {
          Navigator.pop(context);
          _showServiceForm(service: service);
        },
      ),
    );
  }

  Future<void> _deleteService(AutoServiceModel service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('auto_services')
          .doc(service.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

/// Service card widget
class _ServiceCard extends StatelessWidget {
  final AutoServiceModel service;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = AutoServiceCategories.getColor(service.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AutoServiceCategories.getIcon(service.category),
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (service.isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star,
                                    size: 12, color: Colors.amber),
                                SizedBox(width: 2),
                                Text(
                                  'Popular',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.formattedDuration,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        if (service.includesParts) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Parts included',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (service.isPriceEstimate)
                        Text(
                          'From ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        '\$${service.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    child: const Icon(Icons.more_vert, color: Colors.grey),
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Service form sheet
class _ServiceFormSheet extends StatefulWidget {
  final String businessId;
  final AutoServiceModel? service;
  final VoidCallback onSaved;

  const _ServiceFormSheet({
    required this.businessId,
    this.service,
    required this.onSaved,
  });

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _laborController;
  late TextEditingController _partsController;
  late TextEditingController _durationController;

  String _selectedCategory = AutoServiceCategories.all.first;
  bool _isPriceEstimate = false;
  bool _includesParts = true;
  bool _isPopular = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _priceController =
        TextEditingController(text: s?.price.toStringAsFixed(0) ?? '');
    _laborController =
        TextEditingController(text: s?.laborCost?.toStringAsFixed(0) ?? '');
    _partsController =
        TextEditingController(text: s?.partsCost?.toStringAsFixed(0) ?? '');
    _durationController =
        TextEditingController(text: s?.estimatedMins.toString() ?? '60');

    if (s != null) {
      _selectedCategory = s.category;
      _isPriceEstimate = s.isPriceEstimate;
      _includesParts = s.includesParts;
      _isPopular = s.isPopular;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _laborController.dispose();
    _partsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
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
                  isEditing ? 'Edit Service' : 'Add Service',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: AutoServiceCategories.all.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(
                            AutoServiceCategories.getIcon(cat),
                            size: 20,
                            color: AutoServiceCategories.getColor(cat),
                          ),
                          const SizedBox(width: 8),
                          Text(cat),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Price
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text('Estimate?', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: _isPriceEstimate,
                          onChanged: (v) =>
                              setState(() => _isPriceEstimate = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Labor and Parts cost
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _laborController,
                        decoration: const InputDecoration(
                          labelText: 'Labor Cost',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _partsController,
                        decoration: const InputDecoration(
                          labelText: 'Parts Cost',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Duration
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Duration (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),

                // Toggles
                SwitchListTile(
                  title: const Text('Parts Included'),
                  subtitle: const Text('Service includes necessary parts'),
                  value: _includesParts,
                  onChanged: (v) => setState(() => _includesParts = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Popular Service'),
                  subtitle: const Text('Highlight as popular'),
                  value: _isPopular,
                  onChanged: (v) => setState(() => _isPopular = v),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveService,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Service' : 'Add Service'),
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

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'businessId': widget.businessId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text) ?? 0,
        'laborCost': _laborController.text.isNotEmpty
            ? double.tryParse(_laborController.text)
            : null,
        'partsCost': _partsController.text.isNotEmpty
            ? double.tryParse(_partsController.text)
            : null,
        'estimatedMins': int.tryParse(_durationController.text) ?? 60,
        'isPriceEstimate': _isPriceEstimate,
        'includesParts': _includesParts,
        'isPopular': _isPopular,
        'isActive': true,
        'createdAt': widget.service?.createdAt != null
            ? Timestamp.fromDate(widget.service!.createdAt)
            : Timestamp.now(),
      };

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('auto_services');

      if (widget.service != null) {
        await collection.doc(widget.service!.id).update(data);
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

/// Service details sheet
class _ServiceDetailsSheet extends StatelessWidget {
  final AutoServiceModel service;
  final VoidCallback onEdit;

  const _ServiceDetailsSheet({
    required this.service,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = AutoServiceCategories.getColor(service.category);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AutoServiceCategories.getIcon(service.category),
                        color: categoryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            service.category,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Price card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            service.isPriceEstimate ? 'Starting at' : 'Price',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${service.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Column(
                        children: [
                          Text(
                            'Duration',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            service.formattedDuration,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Cost breakdown
                if (service.laborCost != null || service.partsCost != null) ...[
                  const Text(
                    'Cost Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (service.laborCost != null)
                    _buildInfoRow(
                        'Labor', '\$${service.laborCost!.toStringAsFixed(0)}'),
                  if (service.partsCost != null)
                    _buildInfoRow(
                        'Parts', '\$${service.partsCost!.toStringAsFixed(0)}'),
                  const Divider(),
                  _buildInfoRow(
                      'Total', '\$${service.price.toStringAsFixed(0)}',
                      isBold: true),
                  const SizedBox(height: 24),
                ],

                // Features
                Row(
                  children: [
                    if (service.includesParts)
                      _buildFeatureChip(
                        Icons.check_circle,
                        'Parts Included',
                        Colors.green,
                      ),
                    if (service.isPriceEstimate) ...[
                      const SizedBox(width: 8),
                      _buildFeatureChip(
                        Icons.info,
                        'Price Estimate',
                        Colors.orange,
                      ),
                    ],
                  ],
                ),

                if (service.description != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(service.description!),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
