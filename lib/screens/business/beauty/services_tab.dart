import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';
import '../../../widgets/business/business_widgets.dart';
import '../../../widgets/business/enhanced_empty_state.dart';

/// Beauty/Salon treatment categories (industry-standard)
class SalonServiceCategories {
  static const List<String> all = [
    'Hair',
    'Skin & Facials',
    'Nails',
    'Brows & Lashes',
    'Makeup',
    'Body Treatments',
    'Hair Removal',
    'Bridal',
    'Barbering',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hair':
        return Icons.content_cut;
      case 'skin & facials':
        return Icons.face_retouching_natural;
      case 'nails':
        return Icons.pan_tool;
      case 'brows & lashes':
        return Icons.visibility;
      case 'makeup':
        return Icons.brush;
      case 'body treatments':
        return Icons.spa;
      case 'hair removal':
        return Icons.auto_fix_high;
      case 'bridal':
        return Icons.diamond;
      case 'barbering':
        return Icons.face;
      default:
        return Icons.spa_outlined;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'hair':
        return const Color(0xFFE91E63);
      case 'skin & facials':
        return const Color(0xFF9C27B0);
      case 'nails':
        return const Color(0xFFFF5722);
      case 'brows & lashes':
        return const Color(0xFF7C4DFF);
      case 'makeup':
        return const Color(0xFFD81B60);
      case 'body treatments':
        return const Color(0xFF26A69A);
      case 'hair removal':
        return const Color(0xFF795548);
      case 'bridal':
        return const Color(0xFFFFB300);
      case 'barbering':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// Salon service model
class SalonService {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String category;
  final double price;
  final int duration; // in minutes
  final String? image;
  final bool isAvailable;
  final bool isPopular;
  final int sortOrder;
  final DateTime createdAt;

  SalonService({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    required this.duration,
    this.image,
    this.isAvailable = true,
    this.isPopular = false,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SalonService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalonService(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      price: (data['price'] ?? 0).toDouble(),
      duration: data['duration'] ?? 30,
      image: data['image'],
      isAvailable: data['isAvailable'] ?? true,
      isPopular: data['isPopular'] ?? false,
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
      'duration': duration,
      'image': image,
      'isAvailable': isAvailable,
      'isPopular': isPopular,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';

  String get formattedDuration {
    if (duration >= 60) {
      final hours = duration ~/ 60;
      final mins = duration % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${duration}m';
  }
}

/// Treatment menu tab for Beauty & Wellness businesses
class BeautyServicesTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const BeautyServicesTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<BeautyServicesTab> createState() => _BeautyServicesTabState();
}

class _BeautyServicesTabState extends State<BeautyServicesTab> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', ...SalonServiceCategories.all];

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
          'Treatment Menu',
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
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
            );
          }

          final allServices = snapshot.data?.docs
                  .map((doc) => SalonService.fromFirestore(doc))
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
          final groupedServices = <String, List<SalonService>>{};
          for (final service in services) {
            groupedServices.putIfAbsent(service.category, () => []);
            groupedServices[service.category]!.add(service);
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFFE91E63),
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
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Treatment'),
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
                      ? const Color(0xFFE91E63)
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
                        SalonServiceCategories.getIcon(category),
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
    List<SalonService> services,
    bool isDarkMode,
  ) {
    final categoryColor = SalonServiceCategories.getColor(category);

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
                  SalonServiceCategories.getIcon(category),
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
          (service) => _ServiceCard(
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
    return EnhancedEmptyState(
      icon: Icons.spa_outlined,
      title: 'No Treatments Yet',
      message: 'Build your treatment menu to start accepting bookings from clients',
      actionLabel: 'Add Treatment',
      onAction: () => _showAddServiceSheet(),
      color: const Color(0xFFE91E63),
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
            'No treatments in $_selectedCategory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedCategory = 'All'),
            child: const Text('View All Treatments'),
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
      builder: (context) => _ServiceFormSheet(
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

  void _showEditServiceSheet(SalonService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceFormSheet(
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

  void _showServiceDetails(SalonService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceDetailsSheet(service: service),
    );
  }

  void _confirmDelete(SalonService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Treatment?'),
        content: Text(
          'Are you sure you want to delete "${service.name}"? This action cannot be undone.',
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
                  const SnackBar(content: Text('Treatment deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(SalonService service) async {
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
                ? 'Treatment marked as unavailable'
                : 'Treatment marked as available',
          ),
        ),
      );
    }
  }
}

/// Service card widget
class _ServiceCard extends StatelessWidget {
  final SalonService service;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _ServiceCard({
    required this.service,
    required this.isDarkMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = SalonServiceCategories.getColor(service.category);

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
                // Service icon/image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: service.image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            service.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              SalonServiceCategories.getIcon(service.category),
                              size: 28,
                              color: categoryColor,
                            ),
                          ),
                        )
                      : Icon(
                          SalonServiceCategories.getIcon(service.category),
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
                          if (service.isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.amber),
                                  SizedBox(width: 4),
                                  Text(
                                    'Bestseller',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
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
                          Text(
                            service.formattedPrice,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.white10 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  service.formattedDuration,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          service.isAvailable
                              ? StatusBadge.available(showIcon: true)
                              : StatusBadge.inactive(showIcon: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: Colors.blue,
                  onTap: onEdit,
                ),
                _buildActionChip(
                  icon: service.isAvailable
                      ? Icons.visibility_off
                      : Icons.visibility,
                  label: service.isAvailable ? 'Hide' : 'Show',
                  color: Colors.orange,
                  onTap: onToggleAvailability,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

/// Treatment form sheet for add/edit
class _ServiceFormSheet extends StatefulWidget {
  final String businessId;
  final SalonService? existingService;
  final Function(SalonService) onSave;

  const _ServiceFormSheet({
    required this.businessId,
    this.existingService,
    required this.onSave,
  });

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = SalonServiceCategories.all.first;
  int _duration = 30;
  bool _isAvailable = true;
  bool _isPopular = false;
  bool _isSaving = false;

  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120, 150, 180];

  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      _nameController.text = widget.existingService!.name;
      _descriptionController.text = widget.existingService!.description ?? '';
      _priceController.text = widget.existingService!.price.toStringAsFixed(0);
      _selectedCategory = widget.existingService!.category;
      _duration = widget.existingService!.duration;
      _isAvailable = widget.existingService!.isAvailable;
      _isPopular = widget.existingService!.isPopular;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  isEditing ? 'Edit Treatment' : 'Add New Treatment',
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
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Selection
                    Text(
                      'Treatment Category',
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
                      children: SalonServiceCategories.all.map((category) {
                        final isSelected = _selectedCategory == category;
                        final color = SalonServiceCategories.getColor(category);
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                SalonServiceCategories.getIcon(category),
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

                    // Treatment Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Treatment Name',
                        hintText: 'e.g., Balayage, Hydrafacial, Gel Manicure',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter treatment name';
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
                        hintText: 'Describe what this treatment includes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        hintText: '0',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Duration
                    Text(
                      'Duration',
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
                      children: _durationOptions.map((duration) {
                        final isSelected = _duration == duration;
                        String label;
                        if (duration >= 60) {
                          final hours = duration ~/ 60;
                          final mins = duration % 60;
                          label = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
                        } else {
                          label = '${duration}m';
                        }
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _duration = duration);
                            }
                          },
                          selectedColor: const Color(0xFFE91E63),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
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
                      subtitle: Text(
                        _isAvailable
                            ? 'Clients can book this treatment'
                            : 'Treatment is hidden from clients',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      value: _isAvailable,
                      onChanged: (value) => setState(() => _isAvailable = value),
                      activeTrackColor:
                          const Color(0xFFE91E63).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFFE91E63),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(
                        'Mark as Bestseller',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _isPopular
                            ? 'Shows a "Bestseller" badge on this treatment'
                            : 'No badge shown',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      value: _isPopular,
                      onChanged: (value) => setState(() => _isPopular = value),
                      activeTrackColor: Colors.amber.withValues(alpha: 0.5),
                      activeThumbColor: Colors.amber,
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
                    backgroundColor: const Color(0xFFE91E63),
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
                          isEditing ? 'Save Changes' : 'Add Treatment',
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

    final service = SalonService(
      id: widget.existingService?.id ?? '',
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      price: price,
      duration: _duration,
      isAvailable: _isAvailable,
      isPopular: _isPopular,
      sortOrder: widget.existingService?.sortOrder ?? 0,
      createdAt: widget.existingService?.createdAt ?? DateTime.now(),
    );

    widget.onSave(service);
    Navigator.pop(context);
  }
}

/// Service details sheet
class _ServiceDetailsSheet extends StatelessWidget {
  final SalonService service;

  const _ServiceDetailsSheet({required this.service});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = SalonServiceCategories.getColor(service.category);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
                  // Service image/icon
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: service.image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                service.image!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              SalonServiceCategories.getIcon(service.category),
                              size: 60,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SalonServiceCategories.getIcon(service.category),
                            size: 16,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            service.category,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ],
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
                  const SizedBox(height: 8),

                  // Price and duration
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          service.formattedPrice,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode ? Colors.white10 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                service.formattedDuration,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
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
                      if (service.isPopular) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text(
                                'Bestseller',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber,
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
