import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/firebase_provider.dart';
import '../../../widgets/business/enhanced_empty_state.dart';

// ─────────────────────────────────────────────
// Professional Service Categories
// ─────────────────────────────────────────────
class ProfessionalServiceCategories {
  static const List<Map<String, dynamic>> categories = [
    {'name': 'Business Strategy', 'icon': Icons.trending_up, 'color': Color(0xFF3B82F6)},
    {'name': 'Marketing & Branding', 'icon': Icons.campaign, 'color': Color(0xFFF97316)},
    {'name': 'Digital Marketing', 'icon': Icons.ads_click, 'color': Color(0xFFEF4444)},
    {'name': 'HR & Recruitment', 'icon': Icons.people, 'color': Color(0xFF8B5CF6)},
    {'name': 'Finance & Accounting', 'icon': Icons.account_balance, 'color': Color(0xFF10B981)},
    {'name': 'Tax & Compliance', 'icon': Icons.receipt_long, 'color': Color(0xFFF59E0B)},
    {'name': 'Audit & Assurance', 'icon': Icons.fact_check, 'color': Color(0xFF06B6D4)},
    {'name': 'Architecture & Design', 'icon': Icons.architecture, 'color': Color(0xFFEC4899)},
    {'name': 'Event Management', 'icon': Icons.celebration, 'color': Color(0xFFA855F7)},
    {'name': 'Training & L&D', 'icon': Icons.school, 'color': Color(0xFF14B8A6)},
    {'name': 'Operations & SCM', 'icon': Icons.settings, 'color': Color(0xFF64748B)},
    {'name': 'Public Relations', 'icon': Icons.record_voice_over, 'color': Color(0xFFE11D48)},
    {'name': 'Research & Analytics', 'icon': Icons.analytics, 'color': Color(0xFF6366F1)},
    {'name': 'ESG & Sustainability', 'icon': Icons.eco, 'color': Color(0xFF22C55E)},
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
// Professional Service Model
// ─────────────────────────────────────────────
class ProfessionalServiceModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final double priceFrom;
  final String pricingModel; // hourly, project, retainer, milestone, success_fee, packaged
  final String deliveryTimeline;
  final List<String> deliverables;
  final List<String> industries;
  final bool isAvailable;
  final DateTime createdAt;

  ProfessionalServiceModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceFrom,
    this.pricingModel = 'project',
    this.deliveryTimeline = '',
    this.deliverables = const [],
    this.industries = const [],
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProfessionalServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProfessionalServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      priceFrom: (data['priceFrom'] ?? 0).toDouble(),
      pricingModel: data['pricingModel'] ?? 'project',
      deliveryTimeline: data['deliveryTimeline'] ?? '',
      deliverables: List<String>.from(data['deliverables'] ?? []),
      industries: List<String>.from(data['industries'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'priceFrom': priceFrom,
      'pricingModel': pricingModel,
      'deliveryTimeline': deliveryTimeline,
      'deliverables': deliverables,
      'industries': industries,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ─────────────────────────────────────────────
// Professional Services Tab Widget
// ─────────────────────────────────────────────
class ProfessionalServicesTab extends StatefulWidget {
  final String businessId;

  const ProfessionalServicesTab({super.key, required this.businessId});

  @override
  State<ProfessionalServicesTab> createState() => _ProfessionalServicesTabState();
}

class _ProfessionalServicesTabState extends State<ProfessionalServicesTab> {
  String _selectedCategory = 'All';
  static const _themeColor = Color(0xFF6B7280);

  CollectionReference get _servicesCol => FirebaseProvider.firestore
      .collection('businesses')
      .doc(widget.businessId)
      .collection('professional_services');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('All', Icons.apps, _themeColor, isDark),
              ...ProfessionalServiceCategories.categories.map((cat) =>
                  _buildFilterChip(
                    cat['name'] as String,
                    cat['icon'] as IconData,
                    cat['color'] as Color,
                    isDark,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                  .map((doc) => ProfessionalServiceModel.fromFirestore(doc))
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
            Text(label,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12,
                )),
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
    return EnhancedEmptyState(
      icon: Icons.work,
      title: 'No Services Added Yet',
      message: 'Add your professional services to start receiving client inquiries',
      actionLabel: 'Add Service',
      onAction: () => _showAddServiceSheet(context),
      color: _themeColor,
    );
  }

  Widget _buildServiceCard(ProfessionalServiceModel service, bool isDark) {
    final catData = ProfessionalServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? _themeColor;
    final catIcon = catData?['icon'] as IconData? ?? Icons.work;

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
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(service.category, style: TextStyle(fontSize: 13,
                        color: catColor, fontWeight: FontWeight.w500)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('From \u20B9${_formatPrice(service.priceFrom)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  Text(_formatPricingModel(service.pricingModel),
                      style: TextStyle(fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600])),
                ]),
              ]),
              if (service.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(service.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[700])),
              ],
              if (service.industries.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 4,
                    children: service.industries.take(4).map((ind) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ind, style: TextStyle(fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                    )).toList()),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (service.deliveryTimeline.isNotEmpty)
                  _buildTag(Icons.schedule, service.deliveryTimeline, isDark),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: service.isAvailable
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(service.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: service.isAvailable ? Colors.green : Colors.red)),
                ),
              ]),
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
        color: tagColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: tagColor),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _formatPrice(double price) {
    if (price >= 100000) return '${(price / 100000).toStringAsFixed(1)}L';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toInt().toString();
  }

  String _formatPricingModel(String model) {
    switch (model) {
      case 'hourly': return 'Per Hour';
      case 'retainer': return 'Monthly Retainer';
      case 'milestone': return 'Milestone-Based';
      case 'success_fee': return 'Success Fee';
      case 'packaged': return 'Packaged';
      default: return 'Per Project';
    }
  }

  void _showServiceDetails(ProfessionalServiceModel service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catData = ProfessionalServiceCategories.getCategory(service.category);
    final catColor = catData?['color'] as Color? ?? _themeColor;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(service.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(service.category, style: TextStyle(fontSize: 15, color: catColor, fontWeight: FontWeight.w500)),
            const Divider(height: 24),
            Row(children: [
              _detailItem(Icons.currency_rupee, 'From \u20B9${_formatPrice(service.priceFrom)}',
                  _formatPricingModel(service.pricingModel), isDark),
              if (service.deliveryTimeline.isNotEmpty) ...[
                const SizedBox(width: 24),
                _detailItem(Icons.schedule, service.deliveryTimeline, 'Timeline', isDark),
              ],
            ]),
            const SizedBox(height: 16),
            if (service.description.isNotEmpty) ...[
              Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              Text(service.description, style: TextStyle(fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5)),
              const SizedBox(height: 16),
            ],
            if (service.industries.isNotEmpty) ...[
              Text('Industries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                  children: service.industries.map((ind) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(ind, style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                  )).toList()),
              const SizedBox(height: 16),
            ],
            if (service.deliverables.isNotEmpty) ...[
              Text('Deliverables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              ...service.deliverables.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 18, color: catColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: TextStyle(fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[800]))),
                ]),
              )),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showEditServiceSheet(context, service); },
                icon: const Icon(Icons.edit, size: 18), label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _deleteService(service.id); },
                icon: const Icon(Icons.delete, size: 18), label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String value, String label, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
      ]),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])),
    ]);
  }

  void _showAddServiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfessionalServiceFormSheet(
        businessId: widget.businessId, onSaved: () => Navigator.pop(ctx)),
    );
  }

  void _showEditServiceSheet(BuildContext context, ProfessionalServiceModel service) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfessionalServiceFormSheet(
        businessId: widget.businessId, existingService: service,
        onSaved: () => Navigator.pop(ctx)),
    );
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text('Are you sure you want to delete this service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _servicesCol.doc(serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service deleted')));
      }
    }
  }
}

// ─────────────────────────────────────────────
// Professional Service Form Sheet
// ─────────────────────────────────────────────
class _ProfessionalServiceFormSheet extends StatefulWidget {
  final String businessId;
  final ProfessionalServiceModel? existingService;
  final VoidCallback onSaved;

  const _ProfessionalServiceFormSheet({
    required this.businessId, this.existingService, required this.onSaved,
  });

  @override
  State<_ProfessionalServiceFormSheet> createState() => _ProfessionalServiceFormSheetState();
}

class _ProfessionalServiceFormSheetState extends State<_ProfessionalServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _timelineController;

  String _category = 'Business Strategy';
  String _pricingModel = 'project';
  bool _isAvailable = true;
  List<String> _deliverables = [];
  List<String> _industries = [];
  final TextEditingController _deliverableController = TextEditingController();
  final TextEditingController _industryController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _priceController = TextEditingController(text: s != null ? s.priceFrom.toInt().toString() : '');
    _timelineController = TextEditingController(text: s?.deliveryTimeline ?? '');
    if (s != null) {
      _category = s.category;
      _pricingModel = s.pricingModel;
      _isAvailable = s.isAvailable;
      _deliverables = List.from(s.deliverables);
      _industries = List.from(s.industries);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _timelineController.dispose();
    _deliverableController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(_isEditing ? 'Edit Service' : 'Add Service',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Service Name *', hintText: 'e.g. Brand Strategy Workshop',
                prefixIcon: const Icon(Icons.work),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter service name' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: 'Category *', prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ProfessionalServiceCategories.categories
                  .map((c) => DropdownMenuItem<String>(
                        value: c['name'] as String,
                        child: Row(children: [
                          Icon(c['icon'] as IconData, size: 18, color: c['color'] as Color),
                          const SizedBox(width: 8),
                          Text(c['name'] as String),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _category = v); },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController, maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description', hintText: 'Describe the service...',
                prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 48), child: Icon(Icons.description)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(flex: 3, child: TextFormField(
                controller: _priceController, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Starting Price (\u20B9) *',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter price' : null,
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: DropdownButtonFormField<String>(
                initialValue: _pricingModel,
                decoration: InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                  DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                  DropdownMenuItem(value: 'retainer', child: Text('Retainer')),
                  DropdownMenuItem(value: 'milestone', child: Text('Milestone')),
                  DropdownMenuItem(value: 'success_fee', child: Text('Success Fee')),
                  DropdownMenuItem(value: 'packaged', child: Text('Packaged')),
                ],
                onChanged: (v) { if (v != null) setState(() => _pricingModel = v); },
              )),
            ]),
            const SizedBox(height: 16),

            TextFormField(
              controller: _timelineController,
              decoration: InputDecoration(
                labelText: 'Delivery Timeline', hintText: 'e.g. 4-6 weeks',
                prefixIcon: const Icon(Icons.schedule),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            _buildChipInput(label: 'Deliverables', controller: _deliverableController,
                items: _deliverables, hint: 'Add deliverable...',
                onAdd: (t) => setState(() => _deliverables.add(t)),
                onRemove: (i) => setState(() => _deliverables.removeAt(i))),
            const SizedBox(height: 16),

            _buildChipInput(label: 'Target Industries', controller: _industryController,
                items: _industries, hint: 'Add industry...',
                onAdd: (t) => setState(() => _industries.add(t)),
                onRemove: (i) => setState(() => _industries.removeAt(i))),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Available'), subtitle: const Text('Visible to clients'),
              value: _isAvailable, onChanged: (v) => setState(() => _isAvailable = v),
              activeTrackColor: const Color(0xFF6B7280),
            ),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Service' : 'Add Service',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildChipInput({
    required String label, required TextEditingController controller,
    required List<String> items, required String hint,
    required void Function(String) onAdd, required void Function(int) onRemove,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        )),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) { onAdd(text); controller.clear(); }
          },
          icon: const Icon(Icons.add_circle, color: Color(0xFF6B7280)), iconSize: 32,
        ),
      ]),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: items.asMap().entries.map((entry) {
          return Chip(label: Text(entry.value, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => onRemove(entry.key));
        }).toList()),
      ],
    ]);
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'priceFrom': double.tryParse(_priceController.text) ?? 0,
        'pricingModel': _pricingModel,
        'deliveryTimeline': _timelineController.text.trim(),
        'deliverables': _deliverables,
        'industries': _industries,
        'isAvailable': _isAvailable,
        'createdAt': _isEditing
            ? Timestamp.fromDate(widget.existingService!.createdAt)
            : Timestamp.now(),
      };

      final col = FirebaseProvider.firestore
          .collection('businesses').doc(widget.businessId)
          .collection('professional_services');

      if (_isEditing) {
        await col.doc(widget.existingService!.id).update(data);
      } else {
        await col.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Service updated' : 'Service added')));
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
