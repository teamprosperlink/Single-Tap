import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';
import '../../../widgets/business/business_widgets.dart';

/// Healthcare department/service categories (Apollo/Practo/Zocdoc style)
class HealthcareServiceCategories {
  static const List<String> all = [
    'General Consultation',
    'Specialist Consultation',
    'Dental',
    'Ophthalmology',
    'Lab & Diagnostics',
    'Radiology & Imaging',
    'Physiotherapy',
    'Vaccination & Preventive',
    'Health Checkup Packages',
    'Surgical Procedures',
    'Emergency Care',
    'Teleconsultation',
    'Home Healthcare',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'general consultation':
        return Icons.person;
      case 'specialist consultation':
        return Icons.medical_services;
      case 'dental':
        return Icons.medical_information;
      case 'ophthalmology':
        return Icons.visibility;
      case 'lab & diagnostics':
        return Icons.science;
      case 'radiology & imaging':
        return Icons.biotech;
      case 'physiotherapy':
        return Icons.accessibility_new;
      case 'vaccination & preventive':
        return Icons.vaccines;
      case 'health checkup packages':
        return Icons.fact_check;
      case 'surgical procedures':
        return Icons.local_hospital;
      case 'emergency care':
        return Icons.emergency;
      case 'teleconsultation':
        return Icons.video_call;
      case 'home healthcare':
        return Icons.home;
      default:
        return Icons.medical_services;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'general consultation':
        return const Color(0xFF2196F3);
      case 'specialist consultation':
        return const Color(0xFF1565C0);
      case 'dental':
        return const Color(0xFF00BCD4);
      case 'ophthalmology':
        return const Color(0xFF9C27B0);
      case 'lab & diagnostics':
        return const Color(0xFF4CAF50);
      case 'radiology & imaging':
        return const Color(0xFF673AB7);
      case 'physiotherapy':
        return const Color(0xFF009688);
      case 'vaccination & preventive':
        return const Color(0xFFFF9800);
      case 'health checkup packages':
        return const Color(0xFF3F51B5);
      case 'surgical procedures':
        return const Color(0xFFF44336);
      case 'emergency care':
        return const Color(0xFFE91E63);
      case 'teleconsultation':
        return const Color(0xFF00796B);
      case 'home healthcare':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF607D8B);
    }
  }
}

/// Healthcare service model
class HealthcareService {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double? discountedPrice;
  final int? duration; // in minutes
  final String? image;
  final bool isAvailable;
  final bool requiresAppointment;
  final List<String>? includedTests; // For packages
  final String? preparationNotes; // What patient needs to do before
  final int sortOrder;
  final DateTime createdAt;

  HealthcareService({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.discountedPrice,
    this.duration,
    this.image,
    this.isAvailable = true,
    this.requiresAppointment = true,
    this.includedTests,
    this.preparationNotes,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HealthcareService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthcareService(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      price: (data['price'] ?? 0).toDouble(),
      discountedPrice: data['discountedPrice']?.toDouble(),
      duration: data['duration'],
      image: data['image'],
      isAvailable: data['isAvailable'] ?? true,
      requiresAppointment: data['requiresAppointment'] ?? true,
      includedTests: data['includedTests'] != null
          ? List<String>.from(data['includedTests'])
          : null,
      preparationNotes: data['preparationNotes'],
      sortOrder: data['sortOrder'] ?? 0,
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
      'discountedPrice': discountedPrice,
      'duration': duration,
      'image': image,
      'isAvailable': isAvailable,
      'requiresAppointment': requiresAppointment,
      'includedTests': includedTests,
      'preparationNotes': preparationNotes,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';

  String? get formattedDiscountedPrice =>
      discountedPrice != null ? '₹${discountedPrice!.toStringAsFixed(0)}' : null;

  bool get hasDiscount => discountedPrice != null && discountedPrice! < price;

  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((price - discountedPrice!) / price) * 100).round();
  }

  String? get formattedDuration {
    if (duration == null) return null;
    if (duration! >= 60) {
      final hours = duration! ~/ 60;
      final mins = duration! % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${duration}m';
  }
}

/// Services tab for Healthcare businesses
class HealthcareServicesTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const HealthcareServicesTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<HealthcareServicesTab> createState() => _HealthcareServicesTabState();
}

class _HealthcareServicesTabState extends State<HealthcareServicesTab> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', ...HealthcareServiceCategories.all];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Departments & Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => _showSearchSheet(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildCategoryFilter(isDarkMode),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseProvider.firestore
            .collection('businesses')
            .doc(widget.business.id)
            .collection('services')
            .orderBy('sortOrder')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            );
          }

          final allServices = snapshot.data?.docs
                  .map((doc) => HealthcareService.fromFirestore(doc))
                  .toList() ??
              [];

          final services = _selectedCategory == 'All'
              ? allServices
              : allServices
                  .where((s) => s.category == _selectedCategory)
                  .toList();

          if (allServices.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          if (services.isEmpty) {
            return _buildNoResultsState(isDarkMode);
          }

          // Group services by category
          final groupedServices = <String, List<HealthcareService>>{};
          for (final service in services) {
            groupedServices.putIfAbsent(service.category, () => []);
            groupedServices[service.category]!.add(service);
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFF2196F3),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedServices.length,
              itemBuilder: (context, index) {
                final category = groupedServices.keys.elementAt(index);
                final categoryServices = groupedServices[category]!;

                return _buildCategorySection(
                  category,
                  categoryServices,
                  isDarkMode,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddServiceSheet(),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Department Service'),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedCategory = category);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2196F3)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category != 'All') ...[
                      Icon(
                        HealthcareServiceCategories.getIcon(category),
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<HealthcareService> services,
    bool isDarkMode,
  ) {
    final categoryColor = HealthcareServiceCategories.getColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HealthcareServiceCategories.getIcon(category),
                  size: 18,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${services.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...services.map(
          (service) => _HealthcareServiceCard(
            service: service,
            isDarkMode: isDarkMode,
            onTap: () => _showServiceDetails(service),
            onEdit: () => _showEditServiceSheet(service),
            onDelete: () => _confirmDelete(service),
            onToggleAvailability: () => _toggleAvailability(service),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Services Listed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your departments, consultations, diagnostics, and health packages for patients to discover',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddServiceSheet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Service'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No services in $_selectedCategory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedCategory = 'All'),
            child: const Text('View All Departments'),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet() {
    // Implement search functionality
  }

  void _showAddServiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HealthcareServiceFormSheet(
        businessId: widget.business.id,
        onSave: (service) async {
          await FirebaseProvider.firestore
              .collection('businesses')
              .doc(widget.business.id)
              .collection('services')
              .add(service.toFirestore());
          widget.onRefresh();
        },
      ),
    );
  }

  void _showEditServiceSheet(HealthcareService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HealthcareServiceFormSheet(
        businessId: widget.business.id,
        existingService: service,
        onSave: (updatedService) async {
          await FirebaseProvider.firestore
              .collection('businesses')
              .doc(widget.business.id)
              .collection('services')
              .doc(service.id)
              .update(updatedService.toFirestore());
          widget.onRefresh();
        },
      ),
    );
  }

  void _showServiceDetails(HealthcareService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HealthcareServiceDetailsSheet(service: service),
    );
  }

  void _confirmDelete(HealthcareService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Remove Service?'),
        content: Text(
          'Are you sure you want to remove "${service.name}" from your services? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await FirebaseProvider.firestore
                  .collection('businesses')
                  .doc(widget.business.id)
                  .collection('services')
                  .doc(service.id)
                  .delete();
              widget.onRefresh();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Service removed')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(HealthcareService service) async {
    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('services')
        .doc(service.id)
        .update({'isAvailable': !service.isAvailable});

    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.isAvailable
                ? 'Service marked as unavailable for patients'
                : 'Service is now available for patients',
          ),
        ),
      );
    }
  }
}

/// Healthcare service card widget
class _HealthcareServiceCard extends StatelessWidget {
  final HealthcareService service;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _HealthcareServiceCard({
    required this.service,
    required this.isDarkMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = HealthcareServiceCategories.getColor(service.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HealthcareServiceCategories.getIcon(service.category),
                    size: 28,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 16),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (service.hasDiscount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${service.discountPercentage}% OFF',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (service.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          service.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (service.hasDiscount) ...[
                            Text(
                              service.formattedDiscountedPrice!,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              service.formattedPrice,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.grey[400],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ] else
                            Text(
                              service.formattedPrice,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          const Spacer(),
                          if (service.requiresAppointment)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 10,
                                    color: Colors.blue[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'By Appointment',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Included tests (for packages)
            if (service.includedTests != null &&
                service.includedTests!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: service.includedTests!.take(3).map((test) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      test,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (service.includedTests!.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${service.includedTests!.length - 3} more tests',
                    style: TextStyle(
                      fontSize: 11,
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                service.isAvailable
                    ? StatusBadge.available(showIcon: true)
                    : StatusBadge.inactive(showIcon: true),
                const Spacer(),
                _buildActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: Colors.blue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: service.isAvailable
                      ? Icons.visibility_off
                      : Icons.visibility,
                  label: service.isAvailable ? 'Hide' : 'Show',
                  color: Colors.orange,
                  onTap: onToggleAvailability,
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Healthcare service form sheet
class _HealthcareServiceFormSheet extends StatefulWidget {
  final String businessId;
  final HealthcareService? existingService;
  final Function(HealthcareService) onSave;

  const _HealthcareServiceFormSheet({
    required this.businessId,
    this.existingService,
    required this.onSave,
  });

  @override
  State<_HealthcareServiceFormSheet> createState() =>
      _HealthcareServiceFormSheetState();
}

class _HealthcareServiceFormSheetState
    extends State<_HealthcareServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _prepNotesController = TextEditingController();
  String _selectedCategory = HealthcareServiceCategories.all.first;
  bool _isAvailable = true;
  bool _requiresAppointment = true;
  final List<String> _includedTests = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      _nameController.text = widget.existingService!.name;
      _descriptionController.text = widget.existingService!.description ?? '';
      _priceController.text = widget.existingService!.price.toStringAsFixed(0);
      if (widget.existingService!.discountedPrice != null) {
        _discountedPriceController.text =
            widget.existingService!.discountedPrice!.toStringAsFixed(0);
      }
      _prepNotesController.text =
          widget.existingService!.preparationNotes ?? '';
      _selectedCategory = widget.existingService!.category;
      _isAvailable = widget.existingService!.isAvailable;
      _requiresAppointment = widget.existingService!.requiresAppointment;
      if (widget.existingService!.includedTests != null) {
        _includedTests.addAll(widget.existingService!.includedTests!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _prepNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingService != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  isEditing ? 'Edit Service' : 'Add Department Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Department Selection
                    Text(
                      'Department / Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          HealthcareServiceCategories.all.map((category) {
                        final isSelected = _selectedCategory == category;
                        final color =
                            HealthcareServiceCategories.getColor(category);
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                HealthcareServiceCategories.getIcon(category),
                                size: 14,
                                color: isSelected ? Colors.white : color,
                              ),
                              const SizedBox(width: 6),
                              Text(category),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                          selectedColor: color,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Service Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Service Name',
                        hintText: 'e.g., Cardiology Consultation, Full Body Checkup, MRI Scan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter service name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Describe what this service includes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Price',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _discountedPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Discounted Price',
                              prefixText: '₹ ',
                              hintText: 'Optional',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Patient Instructions
                    TextFormField(
                      controller: _prepNotesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Patient Instructions (Optional)',
                        hintText:
                            'e.g., 12-hour fasting, Bring previous reports, Wear loose clothing',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggles
                    SwitchListTile(
                      title: Text(
                        'Available',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      value: _isAvailable,
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                      activeTrackColor:
                          const Color(0xFF2196F3).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFF2196F3),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(
                        'Appointment Required',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _requiresAppointment
                            ? 'Patients must book an appointment'
                            : 'Walk-in patients accepted',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      value: _requiresAppointment,
                      onChanged: (value) =>
                          setState(() => _requiresAppointment = value),
                      activeTrackColor:
                          const Color(0xFF2196F3).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFF2196F3),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          // Save button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.white12 : Colors.grey[200]!,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
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
            ),
          ),
        ],
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final price = double.parse(_priceController.text);
    final discountedPrice = _discountedPriceController.text.isNotEmpty
        ? double.parse(_discountedPriceController.text)
        : null;

    final service = HealthcareService(
      id: widget.existingService?.id ?? '',
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      price: price,
      discountedPrice: discountedPrice,
      isAvailable: _isAvailable,
      requiresAppointment: _requiresAppointment,
      preparationNotes: _prepNotesController.text.trim().isEmpty
          ? null
          : _prepNotesController.text.trim(),
      includedTests: _includedTests.isNotEmpty ? _includedTests : null,
      sortOrder: widget.existingService?.sortOrder ?? 0,
      createdAt: widget.existingService?.createdAt ?? DateTime.now(),
    );

    widget.onSave(service);
    Navigator.pop(context);
  }
}

/// Healthcare service details sheet
class _HealthcareServiceDetailsSheet extends StatelessWidget {
  final HealthcareService service;

  const _HealthcareServiceDetailsSheet({required this.service});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor =
        HealthcareServiceCategories.getColor(service.category);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
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
                  // Service icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        HealthcareServiceCategories.getIcon(service.category),
                        size: 50,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service.category,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Service name
                  Center(
                    child: Text(
                      service.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (service.hasDiscount) ...[
                          Text(
                            service.formattedDiscountedPrice!,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            service.formattedPrice,
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  isDarkMode ? Colors.white38 : Colors.grey[400],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${service.discountPercentage}% OFF',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ] else
                          Text(
                            service.formattedPrice,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (service.description != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],

                  if (service.preparationNotes != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patient Instructions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  service.preparationNotes!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (service.includedTests != null &&
                      service.includedTests!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Included Tests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...service.includedTests!.map((test) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: categoryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                test,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 24),

                  // Status badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: service.isAvailable
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              service.isAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color:
                                  service.isAvailable ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              service.isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: service.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (service.requiresAppointment) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'By Appointment Only',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
