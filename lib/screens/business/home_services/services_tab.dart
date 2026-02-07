import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase_provider.dart';

// ─────────────────────────────────────────────
// Service Categories for Home Services
// ─────────────────────────────────────────────
class HomeServiceCategories {
  static const List<Map<String, dynamic>> categories = [
    {'name': 'Plumbing', 'icon': Icons.plumbing, 'color': Color(0xFF2196F3)},
    {'name': 'Electrical', 'icon': Icons.electrical_services, 'color': Color(0xFFFFA000)},
    {'name': 'Carpentry', 'icon': Icons.carpenter, 'color': Color(0xFF8D6E63)},
    {'name': 'Painting', 'icon': Icons.format_paint, 'color': Color(0xFF7E57C2)},
    {'name': 'AC / HVAC', 'icon': Icons.ac_unit, 'color': Color(0xFF00BCD4)},
    {'name': 'Pest Control', 'icon': Icons.pest_control, 'color': Color(0xFF4CAF50)},
    {'name': 'Deep Cleaning', 'icon': Icons.cleaning_services, 'color': Color(0xFF26C6DA)},
    {'name': 'Appliance Repair', 'icon': Icons.settings_suggest, 'color': Color(0xFFEF5350)},
    {'name': 'Waterproofing', 'icon': Icons.water_drop, 'color': Color(0xFF42A5F5)},
    {'name': 'RO / Purifier', 'icon': Icons.water, 'color': Color(0xFF29B6F6)},
    {'name': 'Inverter / UPS', 'icon': Icons.battery_charging_full, 'color': Color(0xFF66BB6A)},
    {'name': 'Geyser / Heater', 'icon': Icons.hot_tub, 'color': Color(0xFFFF7043)},
    {'name': 'Renovation', 'icon': Icons.construction, 'color': Color(0xFF78909C)},
    {'name': 'Security / CCTV', 'icon': Icons.security, 'color': Color(0xFF5C6BC0)},
    {'name': 'Landscaping', 'icon': Icons.yard, 'color': Color(0xFF81C784)},
    {'name': 'Handyman', 'icon': Icons.handyman, 'color': Color(0xFFFFB74D)},
  ];

  static Map<String, dynamic>? getCategory(String name) {
    try {
      return categories.firstWhere(
        (c) => c['name'] == name,
      );
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────
// Home Service Model
// ─────────────────────────────────────────────
class HomeServiceModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String priceUnit; // per visit, per hour, per sq ft, per month
  final int durationMinutes;
  final bool isAvailable;
  final bool isEmergency;
  final String urgency; // routine, same_day, emergency
  final String warrantyPeriod; // e.g. '30 days', '90 days', '1 year'
  final List<String> includes;
  final DateTime createdAt;

  HomeServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.priceUnit = 'per visit',
    this.durationMinutes = 60,
    this.isAvailable = true,
    this.isEmergency = false,
    this.urgency = 'routine',
    this.warrantyPeriod = '',
    this.includes = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HomeServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HomeServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      priceUnit: data['priceUnit'] ?? 'per visit',
      durationMinutes: data['durationMinutes'] ?? 60,
      isAvailable: data['isAvailable'] ?? true,
      isEmergency: data['isEmergency'] ?? false,
      urgency: data['urgency'] ?? 'routine',
      warrantyPeriod: data['warrantyPeriod'] ?? '',
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
      'durationMinutes': durationMinutes,
      'isAvailable': isAvailable,
      'isEmergency': isEmergency,
      'urgency': urgency,
      'warrantyPeriod': warrantyPeriod,
      'includes': includes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ─────────────────────────────────────────────
// Home Services Tab Widget
// ─────────────────────────────────────────────
class HomeServicesTab extends StatefulWidget {
  final String businessId;

  const HomeServicesTab({super.key, required this.businessId});

  @override
  State<HomeServicesTab> createState() => _HomeServicesTabState();
}

class _HomeServicesTabState extends State<HomeServicesTab> {
  String _selectedCategory = 'All';

  CollectionReference get _servicesCol => FirebaseProvider.firestore
      .collection('businesses')
      .doc(widget.businessId)
      .collection('home_services');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('All', Icons.apps, const Color(0xFF84CC16), isDark),
              ...HomeServiceCategories.categories.map((cat) => _buildFilterChip(
                    cat['name'] as String,
                    cat['icon'] as IconData,
                    cat['color'] as Color,
                    isDark,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Services list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _selectedCategory == 'All'
                ? _servicesCol.orderBy('createdAt', descending: true).snapshots()
                : _servicesCol
                    .where('category', isEqualTo: _selectedCategory)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(isDark);
              }

              final services = snapshot.data!.docs
                  .map((doc) => HomeServiceModel.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (context, index) =>
                    _buildServiceCard(services[index], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, bool isDark) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
        selectedColor: color,
        onSelected: (_) => setState(() => _selectedCategory = label),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_repair_service,
              size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No services added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first home service',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddServiceSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84CC16),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(HomeServiceModel service, bool isDark) {
    final catData = HomeServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? const Color(0xFF84CC16);
    final catIcon = catData?['icon'] as IconData? ?? Icons.home_repair_service;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      elevation: isDark ? 0 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showServiceDetails(service),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(catIcon, color: catColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          service.category,
                          style: TextStyle(
                            fontSize: 13,
                            color: catColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\u20B9${service.price.toInt()}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        service.priceUnit,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (service.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTag(
                    Icons.access_time,
                    _formatDuration(service.durationMinutes),
                    isDark,
                  ),
                  if (service.isEmergency) ...[
                    const SizedBox(width: 8),
                    _buildTag(
                      Icons.emergency,
                      '24/7',
                      isDark,
                      color: Colors.red,
                    ),
                  ],
                  if (service.warrantyPeriod.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildTag(
                      Icons.verified_user,
                      service.warrantyPeriod,
                      isDark,
                      color: Colors.green,
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: service.isAvailable
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: service.isAvailable ? Colors.green : Colors.red,
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

  Widget _buildTag(IconData icon, String label, bool isDark, {Color? color}) {
    final tagColor = color ?? (isDark ? Colors.grey[500]! : Colors.grey[600]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tagColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}hr';
    return '${hours}hr ${mins}min';
  }

  void _showServiceDetails(HomeServiceModel service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catData = HomeServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? const Color(0xFF84CC16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                service.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.category,
                style: TextStyle(fontSize: 15, color: catColor, fontWeight: FontWeight.w500),
              ),
              const Divider(height: 24),

              // Price & Duration
              Row(
                children: [
                  _detailItem(
                    Icons.currency_rupee,
                    '\u20B9${service.price.toInt()}',
                    service.priceUnit,
                    isDark,
                  ),
                  const SizedBox(width: 24),
                  _detailItem(
                    Icons.access_time,
                    _formatDuration(service.durationMinutes),
                    'Duration',
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Urgency & Emergency
              Row(
                children: [
                  _detailItem(
                    Icons.speed,
                    _formatUrgency(service.urgency),
                    'Service Type',
                    isDark,
                  ),
                  if (service.warrantyPeriod.isNotEmpty) ...[
                    const SizedBox(width: 24),
                    _detailItem(
                      Icons.verified_user,
                      service.warrantyPeriod,
                      'Warranty',
                      isDark,
                    ),
                  ],
                ],
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
                const SizedBox(height: 6),
                Text(
                  service.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // What's Included
              if (service.includes.isNotEmpty) ...[
                Text(
                  'What\'s Included',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...service.includes.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 18, color: catColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditServiceSheet(context, service);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteService(service.id);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

  Widget _detailItem(IconData icon, String value, String label, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatUrgency(String urgency) {
    switch (urgency) {
      case 'same_day':
        return 'Same-Day';
      case 'emergency':
        return 'Emergency 24/7';
      default:
        return 'Routine';
    }
  }

  void _showAddServiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HomeServiceFormSheet(
        businessId: widget.businessId,
        onSaved: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showEditServiceSheet(BuildContext context, HomeServiceModel service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HomeServiceFormSheet(
        businessId: widget.businessId,
        existingService: service,
        onSaved: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _servicesCol.doc(serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service deleted')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
// Service Form Sheet
// ─────────────────────────────────────────────
class _HomeServiceFormSheet extends StatefulWidget {
  final String businessId;
  final HomeServiceModel? existingService;
  final VoidCallback onSaved;

  const _HomeServiceFormSheet({
    required this.businessId,
    this.existingService,
    required this.onSaved,
  });

  @override
  State<_HomeServiceFormSheet> createState() => _HomeServiceFormSheetState();
}

class _HomeServiceFormSheetState extends State<_HomeServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _warrantyController;

  String _category = 'Plumbing';
  String _priceUnit = 'per visit';
  int _duration = 60;
  String _urgency = 'routine';
  bool _isAvailable = true;
  bool _isEmergency = false;
  List<String> _includes = [];
  final TextEditingController _includeItemController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _priceController = TextEditingController(
        text: s != null ? s.price.toInt().toString() : '');
    _warrantyController = TextEditingController(text: s?.warrantyPeriod ?? '');
    if (s != null) {
      _category = s.category;
      _priceUnit = s.priceUnit;
      _duration = s.durationMinutes;
      _urgency = s.urgency;
      _isAvailable = s.isAvailable;
      _isEmergency = s.isEmergency;
      _includes = List.from(s.includes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _warrantyController.dispose();
    _includeItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Text(
                _isEditing ? 'Edit Service' : 'Add Service',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Service Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Service Name *',
                  hintText: 'e.g. Full Home Plumbing Checkup',
                  prefixIcon: const Icon(Icons.home_repair_service),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter service name' : null,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: HomeServiceCategories.categories
                    .map((c) => DropdownMenuItem<String>(
                          value: c['name'] as String,
                          child: Row(
                            children: [
                              Icon(c['icon'] as IconData,
                                  size: 18,
                                  color: c['color'] as Color),
                              const SizedBox(width: 8),
                              Text(c['name'] as String),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the service in detail...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Price & Price Unit
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Price (\u20B9) *',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter price' : null,
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
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        'per visit',
                        'per hour',
                        'per sq ft',
                        'per month',
                        'per session',
                        'per job',
                      ]
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _priceUnit = v);
                      },
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: [15, 30, 45, 60, 90, 120, 180, 240, 480]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(_formatDuration(d)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _duration = v);
                },
              ),
              const SizedBox(height: 16),

              // Urgency
              DropdownButtonFormField<String>(
                initialValue: _urgency,
                decoration: InputDecoration(
                  labelText: 'Service Urgency',
                  prefixIcon: const Icon(Icons.speed),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'routine', child: Text('Routine')),
                  DropdownMenuItem(value: 'same_day', child: Text('Same-Day')),
                  DropdownMenuItem(
                      value: 'emergency', child: Text('Emergency 24/7')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _urgency = v);
                },
              ),
              const SizedBox(height: 16),

              // Warranty
              TextFormField(
                controller: _warrantyController,
                decoration: InputDecoration(
                  labelText: 'Warranty Period',
                  hintText: 'e.g. 30 days, 90 days, 1 year',
                  prefixIcon: const Icon(Icons.verified_user),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // What's Included
              Text(
                'What\'s Included',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _includeItemController,
                      decoration: InputDecoration(
                        hintText: 'Add an item...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      final text = _includeItemController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() => _includes.add(text));
                        _includeItemController.clear();
                      }
                    },
                    icon: const Icon(Icons.add_circle, color: Color(0xFF84CC16)),
                    iconSize: 32,
                  ),
                ],
              ),
              if (_includes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _includes.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _includes.removeAt(entry.key));
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Toggles
              SwitchListTile(
                title: const Text('Available'),
                subtitle: const Text('Visible to customers'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeTrackColor: const Color(0xFF84CC16),
              ),
              SwitchListTile(
                title: const Text('Emergency Service'),
                subtitle: const Text('Available 24/7 for emergencies'),
                value: _isEmergency,
                onChanged: (v) => setState(() => _isEmergency = v),
                activeTrackColor: Colors.red,
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84CC16),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? 'Update Service' : 'Add Service',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'priceUnit': _priceUnit,
        'durationMinutes': _duration,
        'urgency': _urgency,
        'warrantyPeriod': _warrantyController.text.trim(),
        'isAvailable': _isAvailable,
        'isEmergency': _isEmergency,
        'includes': _includes,
        'createdAt': _isEditing
            ? Timestamp.fromDate(widget.existingService!.createdAt)
            : Timestamp.now(),
      };

      final col = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('home_services');

      if (_isEditing) {
        await col.doc(widget.existingService!.id).update(data);
      } else {
        await col.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEditing ? 'Service updated' : 'Service added')),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
