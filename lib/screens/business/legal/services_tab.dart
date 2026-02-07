import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase_provider.dart';

// ─────────────────────────────────────────────
// Legal Service Categories
// ─────────────────────────────────────────────
class LegalServiceCategories {
  static const List<Map<String, dynamic>> categories = [
    {'name': 'Civil Litigation', 'icon': Icons.balance, 'color': Color(0xFF78716C)},
    {'name': 'Criminal Defense', 'icon': Icons.shield, 'color': Color(0xFFEF4444)},
    {'name': 'Family & Matrimonial', 'icon': Icons.family_restroom, 'color': Color(0xFFEC4899)},
    {'name': 'Property & Real Estate', 'icon': Icons.apartment, 'color': Color(0xFF8B5CF6)},
    {'name': 'Corporate & Commercial', 'icon': Icons.business_center, 'color': Color(0xFF3B82F6)},
    {'name': 'Tax Law', 'icon': Icons.receipt_long, 'color': Color(0xFFF59E0B)},
    {'name': 'Intellectual Property', 'icon': Icons.lightbulb, 'color': Color(0xFF10B981)},
    {'name': 'Labour & Employment', 'icon': Icons.work, 'color': Color(0xFF6366F1)},
    {'name': 'Immigration & Visa', 'icon': Icons.flight, 'color': Color(0xFF06B6D4)},
    {'name': 'Arbitration & Mediation', 'icon': Icons.handshake, 'color': Color(0xFF14B8A6)},
    {'name': 'Consumer Protection', 'icon': Icons.verified_user, 'color': Color(0xFFF97316)},
    {'name': 'Cyber & Data Privacy', 'icon': Icons.security, 'color': Color(0xFF64748B)},
    {'name': 'Document Drafting', 'icon': Icons.description, 'color': Color(0xFF84CC16)},
    {'name': 'Startup & Compliance', 'icon': Icons.rocket_launch, 'color': Color(0xFFE11D48)},
  ];

  static Map<String, dynamic>? getCategory(String name) {
    try {
      return categories.firstWhere((c) => c['name'] == name);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────
// Legal Service Model
// ─────────────────────────────────────────────
class LegalServiceModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String feeType; // consultation, hourly, per_hearing, fixed, retainer, per_case
  final String consultationMode; // in_person, video, phone, email
  final List<String> courtsApplicable;
  final List<String> documentsIncluded;
  final bool isAvailable;
  final DateTime createdAt;

  LegalServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.feeType = 'consultation',
    this.consultationMode = 'in_person',
    this.courtsApplicable = const [],
    this.documentsIncluded = const [],
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory LegalServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LegalServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      feeType: data['feeType'] ?? 'consultation',
      consultationMode: data['consultationMode'] ?? 'in_person',
      courtsApplicable: List<String>.from(data['courtsApplicable'] ?? []),
      documentsIncluded: List<String>.from(data['documentsIncluded'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'feeType': feeType,
      'consultationMode': consultationMode,
      'courtsApplicable': courtsApplicable,
      'documentsIncluded': documentsIncluded,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ─────────────────────────────────────────────
// Legal Services Tab Widget
// ─────────────────────────────────────────────
class LegalServicesTab extends StatefulWidget {
  final String businessId;

  const LegalServicesTab({super.key, required this.businessId});

  @override
  State<LegalServicesTab> createState() => _LegalServicesTabState();
}

class _LegalServicesTabState extends State<LegalServicesTab> {
  String _selectedCategory = 'All';
  static const _themeColor = Color(0xFF78716C);

  CollectionReference get _servicesCol => FirebaseProvider.firestore
      .collection('businesses')
      .doc(widget.businessId)
      .collection('legal_services');

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
              _buildFilterChip('All', Icons.apps, _themeColor, isDark),
              ...LegalServiceCategories.categories.map((cat) => _buildFilterChip(
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
                  .map((doc) => LegalServiceModel.fromFirestore(doc))
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
          Icon(Icons.gavel,
              size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No legal services added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first legal service',
            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddServiceSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(LegalServiceModel service, bool isDark) {
    final catData = LegalServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? _themeColor;
    final catIcon = catData?['icon'] as IconData? ?? Icons.gavel;

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
                        '\u20B9${_formatPrice(service.price)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        _formatFeeType(service.feeType),
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
              if (service.courtsApplicable.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: service.courtsApplicable.take(4).map((court) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        court,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTag(Icons.videocam,
                      _formatConsultationMode(service.consultationMode), isDark),
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

  Widget _buildTag(IconData icon, String label, bool isDark) {
    final tagColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
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
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: tagColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 100000) return '${(price / 100000).toStringAsFixed(1)}L';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toInt().toString();
  }

  String _formatFeeType(String type) {
    switch (type) {
      case 'hourly':
        return 'Per Hour';
      case 'per_hearing':
        return 'Per Hearing';
      case 'fixed':
        return 'Fixed Fee';
      case 'retainer':
        return 'Monthly Retainer';
      case 'per_case':
        return 'Per Case';
      default:
        return 'Consultation';
    }
  }

  String _formatConsultationMode(String mode) {
    switch (mode) {
      case 'video':
        return 'Video Call';
      case 'phone':
        return 'Phone';
      case 'email':
        return 'Email / Chat';
      default:
        return 'In-Person';
    }
  }

  void _showServiceDetails(LegalServiceModel service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catData = LegalServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? _themeColor;

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
                style: TextStyle(
                    fontSize: 15,
                    color: catColor,
                    fontWeight: FontWeight.w500),
              ),
              const Divider(height: 24),

              // Fee & Mode
              Row(
                children: [
                  _detailItem(Icons.currency_rupee,
                      '\u20B9${_formatPrice(service.price)}',
                      _formatFeeType(service.feeType), isDark),
                  const SizedBox(width: 24),
                  _detailItem(Icons.videocam,
                      _formatConsultationMode(service.consultationMode),
                      'Mode', isDark),
                ],
              ),
              const SizedBox(height: 16),

              if (service.description.isNotEmpty) ...[
                Text('Description',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 6),
                Text(service.description,
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.5)),
                const SizedBox(height: 16),
              ],

              // Courts Applicable
              if (service.courtsApplicable.isNotEmpty) ...[
                Text('Courts / Tribunals',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: service.courtsApplicable
                      .map((court) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: catColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(court,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Documents Included
              if (service.documentsIncluded.isNotEmpty) ...[
                Text('Includes',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                ...service.documentsIncluded.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(Icons.check_circle, size: 18, color: catColor),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(item,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800]))),
                      ]),
                    )),
              ],

              const SizedBox(height: 16),
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
                              borderRadius: BorderRadius.circular(12))),
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

  Widget _detailItem(
      IconData icon, String value, String label, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon,
            size: 18,
            color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 6),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87)),
      ]),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600])),
    ]);
  }

  void _showAddServiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LegalServiceFormSheet(
        businessId: widget.businessId,
        onSaved: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showEditServiceSheet(BuildContext context, LegalServiceModel service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LegalServiceFormSheet(
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
        content:
            const Text('Are you sure you want to delete this legal service?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _servicesCol.doc(serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Service deleted')));
      }
    }
  }
}

// ─────────────────────────────────────────────
// Legal Service Form Sheet
// ─────────────────────────────────────────────
class _LegalServiceFormSheet extends StatefulWidget {
  final String businessId;
  final LegalServiceModel? existingService;
  final VoidCallback onSaved;

  const _LegalServiceFormSheet({
    required this.businessId,
    this.existingService,
    required this.onSaved,
  });

  @override
  State<_LegalServiceFormSheet> createState() => _LegalServiceFormSheetState();
}

class _LegalServiceFormSheetState extends State<_LegalServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  String _category = 'Civil Litigation';
  String _feeType = 'consultation';
  String _consultationMode = 'in_person';
  bool _isAvailable = true;
  List<String> _courtsApplicable = [];
  List<String> _documentsIncluded = [];
  final TextEditingController _courtController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController =
        TextEditingController(text: s?.description ?? '');
    _priceController = TextEditingController(
        text: s != null ? s.price.toInt().toString() : '');
    if (s != null) {
      _category = s.category;
      _feeType = s.feeType;
      _consultationMode = s.consultationMode;
      _isAvailable = s.isAvailable;
      _courtsApplicable = List.from(s.courtsApplicable);
      _documentsIncluded = List.from(s.documentsIncluded);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _courtController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
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
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Text(_isEditing ? 'Edit Service' : 'Add Legal Service',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Service Name *',
                  hintText: 'e.g. Property Title Verification',
                  prefixIcon: const Icon(Icons.gavel),
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
                items: LegalServiceCategories.categories
                    .map((c) => DropdownMenuItem<String>(
                          value: c['name'] as String,
                          child: Row(children: [
                            Icon(c['icon'] as IconData,
                                size: 18, color: c['color'] as Color),
                            const SizedBox(width: 8),
                            Text(c['name'] as String),
                          ]),
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
                  hintText: 'Describe the legal service...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Price & Fee Type
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    decoration: InputDecoration(
                      labelText: 'Fee (\u20B9) *',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter fee' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _feeType,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'consultation',
                          child: Text('Consult')),
                      DropdownMenuItem(
                          value: 'hourly', child: Text('Hourly')),
                      DropdownMenuItem(
                          value: 'per_hearing',
                          child: Text('Hearing')),
                      DropdownMenuItem(
                          value: 'fixed', child: Text('Fixed')),
                      DropdownMenuItem(
                          value: 'retainer',
                          child: Text('Retainer')),
                      DropdownMenuItem(
                          value: 'per_case', child: Text('Per Case')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _feeType = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Consultation Mode
              DropdownButtonFormField<String>(
                initialValue: _consultationMode,
                decoration: InputDecoration(
                  labelText: 'Consultation Mode',
                  prefixIcon: const Icon(Icons.videocam),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'in_person', child: Text('In-Person')),
                  DropdownMenuItem(
                      value: 'video', child: Text('Video Call')),
                  DropdownMenuItem(
                      value: 'phone', child: Text('Phone')),
                  DropdownMenuItem(
                      value: 'email', child: Text('Email / Chat')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _consultationMode = v);
                },
              ),
              const SizedBox(height: 16),

              // Courts Applicable
              _buildChipInput(
                label: 'Courts / Tribunals',
                controller: _courtController,
                items: _courtsApplicable,
                hint: 'Add court...',
                onAdd: (text) =>
                    setState(() => _courtsApplicable.add(text)),
                onRemove: (i) =>
                    setState(() => _courtsApplicable.removeAt(i)),
              ),
              const SizedBox(height: 16),

              // Documents Included
              _buildChipInput(
                label: 'Includes / Documents',
                controller: _documentController,
                items: _documentsIncluded,
                hint: 'Add item...',
                onAdd: (text) =>
                    setState(() => _documentsIncluded.add(text)),
                onRemove: (i) =>
                    setState(() => _documentsIncluded.removeAt(i)),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Available'),
                subtitle: const Text('Visible to clients'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeTrackColor: const Color(0xFF78716C),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF78716C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isEditing ? 'Update Service' : 'Add Service',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipInput({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hint,
    required void Function(String) onAdd,
    required void Function(int) onRemove,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          )),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                onAdd(text);
                controller.clear();
              }
            },
            icon: const Icon(Icons.add_circle,
                color: Color(0xFF78716C)),
            iconSize: 32,
          ),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  items.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value,
                      style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => onRemove(entry.key),
                );
              }).toList()),
        ],
      ],
    );
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
        'feeType': _feeType,
        'consultationMode': _consultationMode,
        'courtsApplicable': _courtsApplicable,
        'documentsIncluded': _documentsIncluded,
        'isAvailable': _isAvailable,
        'createdAt': _isEditing
            ? Timestamp.fromDate(widget.existingService!.createdAt)
            : Timestamp.now(),
      };

      final col = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('legal_services');

      if (_isEditing) {
        await col.doc(widget.existingService!.id).update(data);
      } else {
        await col.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _isEditing ? 'Service updated' : 'Service added')),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
