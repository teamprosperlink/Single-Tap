import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';
import '../../../widgets/business/enhanced_empty_state.dart';

/// Fitness class categories (based on ClassPass, Cult.fit, Mindbody)
class FitnessClassCategories {
  static const List<String> all = [
    'Yoga',
    'Pilates',
    'HIIT',
    'Strength Training',
    'Cardio',
    'Cycling / Spinning',
    'Dance & Zumba',
    'Boxing & Kickboxing',
    'Swimming & Aqua',
    'CrossFit',
    'Martial Arts',
    'Functional Training',
    'Stretching & Mobility',
    'Personal Training',
    'Group Fitness',
    'Bootcamp',
    'Meditation & Breathwork',
    'Sports Specific',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'yoga':
        return Icons.self_improvement;
      case 'pilates':
        return Icons.accessibility_new;
      case 'hiit':
        return Icons.local_fire_department;
      case 'strength training':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.favorite;
      case 'cycling / spinning':
        return Icons.directions_bike;
      case 'dance & zumba':
        return Icons.music_note;
      case 'boxing & kickboxing':
        return Icons.sports_mma;
      case 'swimming & aqua':
        return Icons.pool;
      case 'crossfit':
        return Icons.sports_gymnastics;
      case 'martial arts':
        return Icons.sports_kabaddi;
      case 'functional training':
        return Icons.sports_handball;
      case 'stretching & mobility':
        return Icons.airline_seat_flat;
      case 'personal training':
        return Icons.person;
      case 'group fitness':
        return Icons.groups;
      case 'bootcamp':
        return Icons.military_tech;
      case 'meditation & breathwork':
        return Icons.spa;
      case 'sports specific':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'yoga':
        return const Color(0xFF9C27B0);
      case 'pilates':
        return const Color(0xFFE91E63);
      case 'hiit':
        return const Color(0xFFFF5722);
      case 'strength training':
        return const Color(0xFF795548);
      case 'cardio':
        return const Color(0xFFF44336);
      case 'cycling / spinning':
        return const Color(0xFF4CAF50);
      case 'dance & zumba':
        return const Color(0xFFFF9800);
      case 'boxing & kickboxing':
        return const Color(0xFF212121);
      case 'swimming & aqua':
        return const Color(0xFF2196F3);
      case 'crossfit':
        return const Color(0xFF607D8B);
      case 'martial arts':
        return const Color(0xFF673AB7);
      case 'functional training':
        return const Color(0xFF455A64);
      case 'stretching & mobility':
        return const Color(0xFF00BCD4);
      case 'personal training':
        return const Color(0xFF3F51B5);
      case 'group fitness':
        return const Color(0xFF009688);
      case 'bootcamp':
        return const Color(0xFF827717);
      case 'meditation & breathwork':
        return const Color(0xFF7E57C2);
      case 'sports specific':
        return const Color(0xFF0097A7);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// Class difficulty level
enum ClassDifficulty {
  beginner,
  intermediate,
  advanced,
  allLevels;

  String get displayName {
    switch (this) {
      case ClassDifficulty.beginner:
        return 'Beginner';
      case ClassDifficulty.intermediate:
        return 'Intermediate';
      case ClassDifficulty.advanced:
        return 'Advanced';
      case ClassDifficulty.allLevels:
        return 'All Levels';
    }
  }

  Color get color {
    switch (this) {
      case ClassDifficulty.beginner:
        return Colors.green;
      case ClassDifficulty.intermediate:
        return Colors.orange;
      case ClassDifficulty.advanced:
        return Colors.red;
      case ClassDifficulty.allLevels:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case ClassDifficulty.beginner:
        return Icons.signal_cellular_alt_1_bar;
      case ClassDifficulty.intermediate:
        return Icons.signal_cellular_alt_2_bar;
      case ClassDifficulty.advanced:
        return Icons.signal_cellular_alt;
      case ClassDifficulty.allLevels:
        return Icons.signal_cellular_alt;
    }
  }

  static ClassDifficulty fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'intermediate':
        return ClassDifficulty.intermediate;
      case 'advanced':
        return ClassDifficulty.advanced;
      case 'all_levels':
      case 'alllevels':
        return ClassDifficulty.allLevels;
      default:
        return ClassDifficulty.beginner;
    }
  }
}

/// Fitness class model
class FitnessClassModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String category;
  final ClassDifficulty difficulty;
  final int durationMins;
  final double pricePerClass;
  final double? dropInPrice;
  final int maxParticipants;
  final String? instructor;
  final String? instructorPhoto;
  final String? location; // Room/studio name
  final List<String>? equipment; // Required equipment
  final int caloriesBurned; // Estimated
  final String? image;
  final bool isActive;
  final bool isRecurring;
  final List<ClassSchedule>? schedule;
  final DateTime createdAt;

  FitnessClassModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.category,
    this.difficulty = ClassDifficulty.beginner,
    required this.durationMins,
    required this.pricePerClass,
    this.dropInPrice,
    this.maxParticipants = 20,
    this.instructor,
    this.instructorPhoto,
    this.location,
    this.equipment,
    this.caloriesBurned = 0,
    this.image,
    this.isActive = true,
    this.isRecurring = true,
    this.schedule,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FitnessClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FitnessClassModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      difficulty: ClassDifficulty.fromString(data['difficulty']),
      durationMins: data['durationMins'] ?? 60,
      pricePerClass: (data['pricePerClass'] ?? 0).toDouble(),
      dropInPrice: data['dropInPrice']?.toDouble(),
      maxParticipants: data['maxParticipants'] ?? 20,
      instructor: data['instructor'],
      instructorPhoto: data['instructorPhoto'],
      location: data['location'],
      equipment: data['equipment'] != null
          ? List<String>.from(data['equipment'])
          : null,
      caloriesBurned: data['caloriesBurned'] ?? 0,
      image: data['image'],
      isActive: data['isActive'] ?? true,
      isRecurring: data['isRecurring'] ?? true,
      schedule: data['schedule'] != null
          ? (data['schedule'] as List)
                .map((s) => ClassSchedule.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
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
      'difficulty': difficulty.name,
      'durationMins': durationMins,
      'pricePerClass': pricePerClass,
      'dropInPrice': dropInPrice,
      'maxParticipants': maxParticipants,
      'instructor': instructor,
      'instructorPhoto': instructorPhoto,
      'location': location,
      'equipment': equipment,
      'caloriesBurned': caloriesBurned,
      'image': image,
      'isActive': isActive,
      'isRecurring': isRecurring,
      'schedule': schedule?.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Class schedule entry
class ClassSchedule {
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final String startTime; // "09:00"
  final String? endTime;

  ClassSchedule({
    required this.dayOfWeek,
    required this.startTime,
    this.endTime,
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> map) {
    return ClassSchedule(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'dayOfWeek': dayOfWeek, 'startTime': startTime, 'endTime': endTime};
  }

  String get dayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(dayOfWeek - 1) % 7];
  }
}

/// Fitness classes tab
class FitnessClassesTab extends StatefulWidget {
  final BusinessModel business;

  const FitnessClassesTab({super.key, required this.business});

  @override
  State<FitnessClassesTab> createState() => _FitnessClassesTabState();
}

class _FitnessClassesTabState extends State<FitnessClassesTab> {
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
            itemCount: FitnessClassCategories.all.length + 1,
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
                    selectedColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }

              final category = FitnessClassCategories.all[index - 1];
              final isSelected = _selectedCategory == category;
              final color = FitnessClassCategories.getColor(category);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    FitnessClassCategories.getIcon(category),
                    size: 18,
                    color: isSelected ? color : Colors.grey,
                  ),
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(
                      () => _selectedCategory = selected ? category : null,
                    );
                  },
                  selectedColor: color.withValues(alpha: 0.2),
                  checkmarkColor: color,
                ),
              );
            },
          ),
        ),

        // Classes list
        Expanded(child: _buildClassesList()),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showClassForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Class'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassesList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('fitness_classes')
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

        final classes = snapshot.data!.docs
            .map((doc) => FitnessClassModel.fromFirestore(doc))
            .toList();

        if (classes.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            return _ClassCard(
              fitnessClass: classes[index],
              onTap: () => _showClassDetails(classes[index]),
              onEdit: () => _showClassForm(fitnessClass: classes[index]),
              onDelete: () => _deleteClass(classes[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EnhancedEmptyState(
      icon: Icons.fitness_center,
      title: 'No Workout Classes Yet',
      message: 'Add classes to your workout schedule to start accepting bookings',
      actionLabel: 'Add Class',
      onAction: () => _showClassForm(),
      color: const Color(0xFFFF5722),
    );
  }

  void _showClassForm({FitnessClassModel? fitnessClass}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassFormSheet(
        businessId: widget.business.id,
        fitnessClass: fitnessClass,
        onSaved: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showClassDetails(FitnessClassModel fitnessClass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassDetailsSheet(
        fitnessClass: fitnessClass,
        businessId: widget.business.id,
        onEdit: () {
          Navigator.pop(context);
          _showClassForm(fitnessClass: fitnessClass);
        },
      ),
    );
  }

  Future<void> _deleteClass(FitnessClassModel fitnessClass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete "${fitnessClass.name}"?',
        ),
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
          .collection('fitness_classes')
          .doc(fitnessClass.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

/// Class card widget
class _ClassCard extends StatelessWidget {
  final FitnessClassModel fitnessClass;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.fitnessClass,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = FitnessClassCategories.getColor(
      fitnessClass.category,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header with category color
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          FitnessClassCategories.getIcon(fitnessClass.category),
                          color: categoryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fitnessClass.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  fitnessClass.category,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: fitnessClass.difficulty.color
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        fitnessClass.difficulty.icon,
                                        size: 12,
                                        color: fitnessClass.difficulty.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        fitnessClass.difficulty.displayName,
                                        style: TextStyle(
                                          color: fitnessClass.difficulty.color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
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
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
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
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Info row
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.schedule,
                        '${fitnessClass.durationMins} min',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.people,
                        'Max ${fitnessClass.maxParticipants}',
                      ),
                      if (fitnessClass.caloriesBurned > 0) ...[
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.local_fire_department,
                          '~${fitnessClass.caloriesBurned} cal',
                          color: Colors.orange,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Schedule preview
                  if (fitnessClass.schedule != null &&
                      fitnessClass.schedule!.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: fitnessClass.schedule!.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${s.dayName} ${s.startTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Instructor and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (fitnessClass.instructor != null)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: categoryColor.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage:
                                  fitnessClass.instructorPhoto != null
                                  ? NetworkImage(fitnessClass.instructorPhoto!)
                                  : null,
                              child: fitnessClass.instructorPhoto == null
                                  ? Icon(
                                      Icons.person,
                                      size: 16,
                                      color: categoryColor,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fitnessClass.instructor!,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                      Text(
                        '\$${fitnessClass.pricePerClass.toStringAsFixed(0)}/class',
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
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
}

/// Class form sheet
class _ClassFormSheet extends StatefulWidget {
  final String businessId;
  final FitnessClassModel? fitnessClass;
  final VoidCallback onSaved;

  const _ClassFormSheet({
    required this.businessId,
    this.fitnessClass,
    required this.onSaved,
  });

  @override
  State<_ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<_ClassFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _dropInPriceController;
  late TextEditingController _durationController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _instructorController;
  late TextEditingController _locationController;
  late TextEditingController _caloriesController;

  String _selectedCategory = FitnessClassCategories.all.first;
  ClassDifficulty _selectedDifficulty = ClassDifficulty.beginner;
  List<ClassSchedule> _schedule = [];

  @override
  void initState() {
    super.initState();
    final c = widget.fitnessClass;
    _nameController = TextEditingController(text: c?.name ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _priceController = TextEditingController(
      text: c?.pricePerClass.toStringAsFixed(2) ?? '',
    );
    _dropInPriceController = TextEditingController(
      text: c?.dropInPrice?.toStringAsFixed(2) ?? '',
    );
    _durationController = TextEditingController(
      text: c?.durationMins.toString() ?? '60',
    );
    _maxParticipantsController = TextEditingController(
      text: c?.maxParticipants.toString() ?? '20',
    );
    _instructorController = TextEditingController(text: c?.instructor ?? '');
    _locationController = TextEditingController(text: c?.location ?? '');
    _caloriesController = TextEditingController(
      text: c?.caloriesBurned.toString() ?? '',
    );

    if (c != null) {
      _selectedCategory = c.category;
      _selectedDifficulty = c.difficulty;
      _schedule = c.schedule ?? [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _dropInPriceController.dispose();
    _durationController.dispose();
    _maxParticipantsController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.fitnessClass != null;

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

                // Title
                Text(
                  isEditing ? 'Edit Class' : 'Add New Class',
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
                    labelText: 'Workout / Class Name *',
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
                  items: FitnessClassCategories.all.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            FitnessClassCategories.getIcon(category),
                            size: 20,
                            color: FitnessClassCategories.getColor(category),
                          ),
                          const SizedBox(width: 8),
                          Text(category),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Difficulty
                DropdownButtonFormField<ClassDifficulty>(
                  initialValue: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: ClassDifficulty.values.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Row(
                        children: [
                          Icon(level.icon, size: 20, color: level.color),
                          const SizedBox(width: 8),
                          Text(level.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDifficulty = value);
                    }
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
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Duration and Max Participants
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min) *',
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
                        controller: _maxParticipantsController,
                        decoration: const InputDecoration(
                          labelText: 'Max Participants',
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

                // Price and Drop-in
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price per Class *',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _dropInPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Drop-in Price',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Instructor
                TextFormField(
                  controller: _instructorController,
                  decoration: const InputDecoration(
                    labelText: 'Trainer / Instructor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Studio / Room',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.room),
                  ),
                ),
                const SizedBox(height: 16),

                // Calories
                TextFormField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'Est. Calories Burned',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_fire_department),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 24),

                // Schedule section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Weekly Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addScheduleEntry,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_schedule.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Text('No schedule set')),
                  )
                else
                  ..._schedule.asMap().entries.map((entry) {
                    final index = entry.key;
                    final schedule = entry.value;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: FitnessClassCategories.getColor(
                            _selectedCategory,
                          ).withValues(alpha: 0.2),
                          child: Text(
                            schedule.dayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: FitnessClassCategories.getColor(
                                _selectedCategory,
                              ),
                            ),
                          ),
                        ),
                        title: Text(schedule.startTime),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _schedule.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClass,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Class' : 'Create Class'),
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

  void _addScheduleEntry() async {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    int? selectedDay;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedDay,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items: days.asMap().entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key + 1,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedDay = value);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  selectedTime != null
                      ? selectedTime!.format(context)
                      : 'Select Time',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDay != null && selectedTime != null
                  ? () {
                      setState(() {
                        _schedule.add(
                          ClassSchedule(
                            dayOfWeek: selectedDay!,
                            startTime:
                                '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                          ),
                        );
                      });
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final classData = {
        'businessId': widget.businessId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'category': _selectedCategory,
        'difficulty': _selectedDifficulty.name,
        'durationMins': int.tryParse(_durationController.text) ?? 60,
        'pricePerClass': double.tryParse(_priceController.text) ?? 0,
        'dropInPrice': _dropInPriceController.text.isNotEmpty
            ? double.tryParse(_dropInPriceController.text)
            : null,
        'maxParticipants': int.tryParse(_maxParticipantsController.text) ?? 20,
        'instructor': _instructorController.text.trim().isNotEmpty
            ? _instructorController.text.trim()
            : null,
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        'caloriesBurned': int.tryParse(_caloriesController.text) ?? 0,
        'isActive': true,
        'isRecurring': true,
        'schedule': _schedule.map((s) => s.toMap()).toList(),
        'createdAt': widget.fitnessClass?.createdAt != null
            ? Timestamp.fromDate(widget.fitnessClass!.createdAt)
            : Timestamp.now(),
      };

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('fitness_classes');

      if (widget.fitnessClass != null) {
        await collection.doc(widget.fitnessClass!.id).update(classData);
      } else {
        await collection.add(classData);
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

/// Class details sheet
class _ClassDetailsSheet extends StatelessWidget {
  final FitnessClassModel fitnessClass;
  final String businessId;
  final VoidCallback onEdit;

  const _ClassDetailsSheet({
    required this.fitnessClass,
    required this.businessId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = FitnessClassCategories.getColor(
      fitnessClass.category,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
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
                        FitnessClassCategories.getIcon(fitnessClass.category),
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
                            fitnessClass.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                fitnessClass.category,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: fitnessClass.difficulty.color
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  fitnessClass.difficulty.displayName,
                                  style: TextStyle(
                                    color: fitnessClass.difficulty.color,
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
                    IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
                  ],
                ),

                const SizedBox(height: 24),

                // Stats grid
                Row(
                  children: [
                    _buildStatCard(
                      Icons.schedule,
                      '${fitnessClass.durationMins}',
                      'minutes',
                      categoryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      Icons.people,
                      '${fitnessClass.maxParticipants}',
                      'max spots',
                      categoryColor,
                    ),
                    if (fitnessClass.caloriesBurned > 0) ...[
                      const SizedBox(width: 12),
                      _buildStatCard(
                        Icons.local_fire_department,
                        '~${fitnessClass.caloriesBurned}',
                        'calories',
                        Colors.orange,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Description
                if (fitnessClass.description != null &&
                    fitnessClass.description!.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(fitnessClass.description!),
                  const SizedBox(height: 24),
                ],

                // Schedule
                if (fitnessClass.schedule != null &&
                    fitnessClass.schedule!.isNotEmpty) ...[
                  const Text(
                    'Weekly Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fitnessClass.schedule!.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: categoryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              s.dayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                            Text(
                              s.startTime,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Instructor
                if (fitnessClass.instructor != null) ...[
                  const Text(
                    'Instructor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: categoryColor.withValues(alpha: 0.2),
                        backgroundImage: fitnessClass.instructorPhoto != null
                            ? NetworkImage(fitnessClass.instructorPhoto!)
                            : null,
                        child: fitnessClass.instructorPhoto == null
                            ? Icon(Icons.person, color: categoryColor)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        fitnessClass.instructor!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Location
                if (fitnessClass.location != null) ...[
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.room, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(fitnessClass.location!),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Pricing
                const Text(
                  'Pricing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                            '\$${fitnessClass.pricePerClass.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                          const Text('per class'),
                        ],
                      ),
                      if (fitnessClass.dropInPrice != null) ...[
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        Column(
                          children: [
                            Text(
                              '\$${fitnessClass.dropInPrice!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                            const Text('drop-in'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
