import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/business_model.dart';
import '../../../widgets/business/enhanced_empty_state.dart';

/// Education course categories (aligned with Coursera, Udemy, Unacademy)
class CourseCategories {
  static const List<String> all = [
    'Technology',
    'Data Science & AI',
    'Business',
    'Digital Marketing',
    'Creative & Design',
    'Language',
    'Competitive Exams',
    'Academic',
    'Music & Arts',
    'Professional Certification',
    'Skill Development',
    'Finance & Accounting',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return Icons.computer;
      case 'data science & ai':
        return Icons.analytics;
      case 'business':
        return Icons.business_center;
      case 'digital marketing':
        return Icons.campaign;
      case 'creative & design':
      case 'creative':
        return Icons.palette;
      case 'language':
        return Icons.translate;
      case 'competitive exams':
        return Icons.assignment;
      case 'academic':
        return Icons.school;
      case 'music & arts':
        return Icons.music_note;
      case 'professional certification':
        return Icons.workspace_premium;
      case 'skill development':
        return Icons.psychology;
      case 'finance & accounting':
        return Icons.account_balance;
      default:
        return Icons.menu_book;
    }
  }

  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return const Color(0xFF2196F3);
      case 'data science & ai':
        return const Color(0xFF6C63FF);
      case 'business':
        return const Color(0xFF795548);
      case 'digital marketing':
        return const Color(0xFF00BCD4);
      case 'creative & design':
      case 'creative':
        return const Color(0xFFFF5722);
      case 'language':
        return const Color(0xFF009688);
      case 'competitive exams':
        return const Color(0xFFFF9800);
      case 'academic':
        return const Color(0xFF3F51B5);
      case 'music & arts':
        return const Color(0xFFE91E63);
      case 'professional certification':
        return const Color(0xFF607D8B);
      case 'skill development':
        return const Color(0xFF9C27B0);
      case 'finance & accounting':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF673AB7);
    }
  }
}

/// Course level
enum CourseLevel {
  beginner,
  intermediate,
  advanced,
  allLevels;

  String get displayName {
    switch (this) {
      case CourseLevel.beginner:
        return 'Beginner';
      case CourseLevel.intermediate:
        return 'Intermediate';
      case CourseLevel.advanced:
        return 'Advanced';
      case CourseLevel.allLevels:
        return 'All Levels';
    }
  }

  Color get color {
    switch (this) {
      case CourseLevel.beginner:
        return Colors.green;
      case CourseLevel.intermediate:
        return Colors.orange;
      case CourseLevel.advanced:
        return Colors.red;
      case CourseLevel.allLevels:
        return Colors.blue;
    }
  }

  static CourseLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'intermediate':
        return CourseLevel.intermediate;
      case 'advanced':
        return CourseLevel.advanced;
      case 'all_levels':
      case 'alllevels':
        return CourseLevel.allLevels;
      default:
        return CourseLevel.beginner;
    }
  }
}

/// Course mode
enum CourseMode {
  online,
  offline,
  hybrid;

  String get displayName {
    switch (this) {
      case CourseMode.online:
        return 'Online';
      case CourseMode.offline:
        return 'In-Person';
      case CourseMode.hybrid:
        return 'Hybrid';
    }
  }

  IconData get icon {
    switch (this) {
      case CourseMode.online:
        return Icons.laptop;
      case CourseMode.offline:
        return Icons.location_on;
      case CourseMode.hybrid:
        return Icons.swap_horiz;
    }
  }

  static CourseMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'offline':
        return CourseMode.offline;
      case 'hybrid':
        return CourseMode.hybrid;
      default:
        return CourseMode.online;
    }
  }
}

/// Course model
class CourseModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String category;
  final CourseLevel level;
  final CourseMode mode;
  final double price;
  final double? discountedPrice;
  final String? duration; // e.g., "3 months", "12 weeks"
  final int? totalSessions;
  final int? sessionDurationMins;
  final String? schedule; // e.g., "Mon, Wed, Fri 4-5 PM"
  final int? maxStudents;
  final int enrolledStudents;
  final String? instructor;
  final String? image;
  final List<String>? syllabus;
  final List<String>? prerequisites;
  final bool isActive;
  final bool acceptingEnrollments;
  final DateTime? startDate;
  final DateTime createdAt;

  CourseModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.category,
    this.level = CourseLevel.beginner,
    this.mode = CourseMode.offline,
    required this.price,
    this.discountedPrice,
    this.duration,
    this.totalSessions,
    this.sessionDurationMins,
    this.schedule,
    this.maxStudents,
    this.enrolledStudents = 0,
    this.instructor,
    this.image,
    this.syllabus,
    this.prerequisites,
    this.isActive = true,
    this.acceptingEnrollments = true,
    this.startDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      level: CourseLevel.fromString(data['level']),
      mode: CourseMode.fromString(data['mode']),
      price: (data['price'] ?? 0).toDouble(),
      discountedPrice: data['discountedPrice']?.toDouble(),
      duration: data['duration'],
      totalSessions: data['totalSessions'],
      sessionDurationMins: data['sessionDurationMins'],
      schedule: data['schedule'],
      maxStudents: data['maxStudents'],
      enrolledStudents: data['enrolledStudents'] ?? 0,
      instructor: data['instructor'],
      image: data['image'],
      syllabus: data['syllabus'] != null
          ? List<String>.from(data['syllabus'])
          : null,
      prerequisites: data['prerequisites'] != null
          ? List<String>.from(data['prerequisites'])
          : null,
      isActive: data['isActive'] ?? true,
      acceptingEnrollments: data['acceptingEnrollments'] ?? true,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
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
      'level': level.name,
      'mode': mode.name,
      'price': price,
      'discountedPrice': discountedPrice,
      'duration': duration,
      'totalSessions': totalSessions,
      'sessionDurationMins': sessionDurationMins,
      'schedule': schedule,
      'maxStudents': maxStudents,
      'enrolledStudents': enrolledStudents,
      'instructor': instructor,
      'image': image,
      'syllabus': syllabus,
      'prerequisites': prerequisites,
      'isActive': isActive,
      'acceptingEnrollments': acceptingEnrollments,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
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

  bool get isFull =>
      maxStudents != null && enrolledStudents >= maxStudents!;

  int get spotsLeft =>
      maxStudents != null ? maxStudents! - enrolledStudents : -1;
}

/// Courses tab for Education businesses
class EducationCoursesTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const EducationCoursesTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<EducationCoursesTab> createState() => _EducationCoursesTabState();
}

class _EducationCoursesTabState extends State<EducationCoursesTab> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', ...CourseCategories.all];

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
          'Courses',
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
            onPressed: () {},
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
            .collection('courses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3F51B5)),
            );
          }

          final allCourses = snapshot.data?.docs
                  .map((doc) => CourseModel.fromFirestore(doc))
                  .toList() ??
              [];

          final courses = _selectedCategory == 'All'
              ? allCourses
              : allCourses
                  .where((c) => c.category == _selectedCategory)
                  .toList();

          if (allCourses.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          if (courses.isEmpty) {
            return _buildNoResultsState(isDarkMode);
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFF3F51B5),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                return _CourseCard(
                  course: courses[index],
                  isDarkMode: isDarkMode,
                  onTap: () => _showCourseDetails(courses[index]),
                  onEdit: () => _showEditCourseSheet(courses[index]),
                  onDelete: () => _confirmDelete(courses[index]),
                  onToggle: () => _toggleCourseStatus(courses[index]),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCourseSheet(),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
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
                      ? const Color(0xFF3F51B5)
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
                        CourseCategories.getIcon(category),
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

  Widget _buildEmptyState(bool isDarkMode) {
    return EnhancedEmptyState(
      icon: Icons.school_outlined,
      title: 'No Courses Yet',
      message: 'Add courses or programs to start accepting student enrollments',
      actionLabel: 'Add Course',
      onAction: () => _showAddCourseSheet(),
      color: const Color(0xFF3F51B5),
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
            'No courses in $_selectedCategory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedCategory = 'All'),
            child: const Text('View All Courses'),
          ),
        ],
      ),
    );
  }

  void _showAddCourseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseFormSheet(
        businessId: widget.business.id,
        onSave: (course) async {
          await FirebaseProvider.firestore
              .collection('businesses')
              .doc(widget.business.id)
              .collection('courses')
              .add(course.toFirestore());
          widget.onRefresh();
        },
      ),
    );
  }

  void _showEditCourseSheet(CourseModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseFormSheet(
        businessId: widget.business.id,
        existingCourse: course,
        onSave: (updatedCourse) async {
          await FirebaseProvider.firestore
              .collection('businesses')
              .doc(widget.business.id)
              .collection('courses')
              .doc(course.id)
              .update(updatedCourse.toFirestore());
          widget.onRefresh();
        },
      ),
    );
  }

  void _showCourseDetails(CourseModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseDetailsSheet(course: course),
    );
  }

  void _confirmDelete(CourseModel course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to delete "${course.name}"? This will also remove all enrollment data.',
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
                  .collection('courses')
                  .doc(course.id)
                  .delete();
              widget.onRefresh();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Course deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleCourseStatus(CourseModel course) async {
    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('courses')
        .doc(course.id)
        .update({'isActive': !course.isActive});

    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            course.isActive ? 'Course deactivated' : 'Course activated',
          ),
        ),
      );
    }
  }
}

/// Course card widget
class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _CourseCard({
    required this.course,
    required this.isDarkMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = CourseCategories.getColor(course.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Header with image/icon
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  if (course.image != null)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        course.image!,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildIconPlaceholder(categoryColor),
                      ),
                    )
                  else
                    _buildIconPlaceholder(categoryColor),
                  // Level badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: course.level.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        course.level.displayName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Mode badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black54
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            course.mode.icon,
                            size: 12,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.mode.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Discount badge
                  if (course.hasDiscount)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${course.discountPercentage}% OFF',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CourseCategories.getIcon(course.category),
                              size: 12,
                              color: categoryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!course.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (course.instructor != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'by ${course.instructor}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Info row
                  Row(
                    children: [
                      if (course.duration != null) ...[
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.duration!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (course.totalSessions != null) ...[
                        Icon(
                          Icons.calendar_view_month,
                          size: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${course.totalSessions} sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price and enrollment
                  Row(
                    children: [
                      if (course.hasDiscount) ...[
                        Text(
                          course.formattedDiscountedPrice!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          course.formattedPrice,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                isDarkMode ? Colors.white38 : Colors.grey[400],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ] else
                        Text(
                          course.formattedPrice,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      const Spacer(),
                      if (course.maxStudents != null) ...[
                        Icon(
                          Icons.people,
                          size: 16,
                          color: course.isFull ? Colors.red : categoryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.isFull
                              ? 'Full'
                              : '${course.enrolledStudents}/${course.maxStudents}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: course.isFull ? Colors.red : categoryColor,
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: categoryColor),
                            const SizedBox(width: 4),
                            Text(
                              '${course.enrolledStudents} enrolled',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Actions
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
                        icon: course.isActive
                            ? Icons.visibility_off
                            : Icons.visibility,
                        label: course.isActive ? 'Deactivate' : 'Activate',
                        color: Colors.orange,
                        onTap: onToggle,
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
          ],
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(Color color) {
    return Center(
      child: Icon(
        CourseCategories.getIcon(course.category),
        size: 48,
        color: color,
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

/// Course form sheet
class _CourseFormSheet extends StatefulWidget {
  final String businessId;
  final CourseModel? existingCourse;
  final Function(CourseModel) onSave;

  const _CourseFormSheet({
    required this.businessId,
    this.existingCourse,
    required this.onSave,
  });

  @override
  State<_CourseFormSheet> createState() => _CourseFormSheetState();
}

class _CourseFormSheetState extends State<_CourseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _durationController = TextEditingController();
  final _sessionsController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  final _instructorController = TextEditingController();

  String _selectedCategory = CourseCategories.all.first;
  CourseLevel _selectedLevel = CourseLevel.beginner;
  CourseMode _selectedMode = CourseMode.offline;
  bool _isActive = true;
  bool _acceptingEnrollments = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCourse != null) {
      final c = widget.existingCourse!;
      _nameController.text = c.name;
      _descriptionController.text = c.description ?? '';
      _priceController.text = c.price.toStringAsFixed(0);
      if (c.discountedPrice != null) {
        _discountedPriceController.text = c.discountedPrice!.toStringAsFixed(0);
      }
      _durationController.text = c.duration ?? '';
      if (c.totalSessions != null) {
        _sessionsController.text = c.totalSessions.toString();
      }
      _scheduleController.text = c.schedule ?? '';
      if (c.maxStudents != null) {
        _maxStudentsController.text = c.maxStudents.toString();
      }
      _instructorController.text = c.instructor ?? '';
      _selectedCategory = c.category;
      _selectedLevel = c.level;
      _selectedMode = c.mode;
      _isActive = c.isActive;
      _acceptingEnrollments = c.acceptingEnrollments;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _durationController.dispose();
    _sessionsController.dispose();
    _scheduleController.dispose();
    _maxStudentsController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingCourse != null;

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
                  isEditing ? 'Edit Course' : 'Add New Course',
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
                    // Category
                    _buildSectionTitle('Category', isDarkMode),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CourseCategories.all.map((category) {
                        final isSelected = _selectedCategory == category;
                        final color = CourseCategories.getColor(category);
                        return ChoiceChip(
                          label: Text(category),
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
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Course name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Course / Program Name *',
                        hintText: 'e.g., Full-Stack Web Development, UPSC Prep',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course name';
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
                        labelText: 'Description',
                        hintText: 'What will students learn?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Instructor
                    TextFormField(
                      controller: _instructorController,
                      decoration: InputDecoration(
                        labelText: 'Instructor / Faculty Name',
                        hintText: 'e.g., Dr. Priya Sharma',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Level
                    _buildSectionTitle('Level', isDarkMode),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: CourseLevel.values.map((level) {
                        final isSelected = _selectedLevel == level;
                        return ChoiceChip(
                          label: Text(level.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedLevel = level);
                            }
                          },
                          selectedColor: level.color,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Mode
                    _buildSectionTitle('Delivery Mode', isDarkMode),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: CourseMode.values.map((mode) {
                        final isSelected = _selectedMode == mode;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mode.icon,
                                size: 14,
                                color: isSelected ? Colors.white : null,
                              ),
                              const SizedBox(width: 4),
                              Text(mode.displayName),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedMode = mode);
                            }
                          },
                          selectedColor: const Color(0xFF3F51B5),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Price
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
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
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Discounted',
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

                    // Duration & Sessions
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration',
                              hintText: 'e.g., 3 months',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sessionsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Total Sessions',
                              hintText: 'e.g., 24',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Schedule & Max Students
                    TextFormField(
                      controller: _scheduleController,
                      decoration: InputDecoration(
                        labelText: 'Schedule (Optional)',
                        hintText: 'e.g., Mon, Wed, Fri 4-5 PM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _maxStudentsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max Students (Optional)',
                        hintText: 'Leave empty for unlimited',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggles
                    SwitchListTile(
                      title: Text(
                        'Active',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeTrackColor: const Color(0xFF3F51B5),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(
                        'Accepting Enrollments',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      value: _acceptingEnrollments,
                      onChanged: (value) =>
                          setState(() => _acceptingEnrollments = value),
                      activeTrackColor: const Color(0xFF3F51B5),
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
                    backgroundColor: const Color(0xFF3F51B5),
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
                          isEditing ? 'Save Changes' : 'Add Course',
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

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white70 : Colors.grey[700],
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
    final totalSessions = _sessionsController.text.isNotEmpty
        ? int.parse(_sessionsController.text)
        : null;
    final maxStudents = _maxStudentsController.text.isNotEmpty
        ? int.parse(_maxStudentsController.text)
        : null;

    final course = CourseModel(
      id: widget.existingCourse?.id ?? '',
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      level: _selectedLevel,
      mode: _selectedMode,
      price: price,
      discountedPrice: discountedPrice,
      duration: _durationController.text.trim().isEmpty
          ? null
          : _durationController.text.trim(),
      totalSessions: totalSessions,
      schedule: _scheduleController.text.trim().isEmpty
          ? null
          : _scheduleController.text.trim(),
      maxStudents: maxStudents,
      enrolledStudents: widget.existingCourse?.enrolledStudents ?? 0,
      instructor: _instructorController.text.trim().isEmpty
          ? null
          : _instructorController.text.trim(),
      isActive: _isActive,
      acceptingEnrollments: _acceptingEnrollments,
      createdAt: widget.existingCourse?.createdAt ?? DateTime.now(),
    );

    widget.onSave(course);
    Navigator.pop(context);
  }
}

/// Course details sheet
class _CourseDetailsSheet extends StatelessWidget {
  final CourseModel course;

  const _CourseDetailsSheet({required this.course});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = CourseCategories.getColor(course.category);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                  // Header image
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: course.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              course.image!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            CourseCategories.getIcon(course.category),
                            size: 60,
                            color: categoryColor,
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        course.category,
                        categoryColor,
                        CourseCategories.getIcon(course.category),
                      ),
                      _buildBadge(
                        course.level.displayName,
                        course.level.color,
                        null,
                      ),
                      _buildBadge(
                        course.mode.displayName,
                        Colors.grey,
                        course.mode.icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Course name
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),

                  if (course.instructor != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'by ${course.instructor}',
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    children: [
                      if (course.hasDiscount) ...[
                        Text(
                          course.formattedDiscountedPrice!,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          course.formattedPrice,
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
                            '${course.discountPercentage}% OFF',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ] else
                        Text(
                          course.formattedPrice,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info grid
                  _buildInfoGrid(isDarkMode, categoryColor),

                  if (course.description != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'About this Course',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Enrollment status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: course.acceptingEnrollments && !course.isFull
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          course.acceptingEnrollments && !course.isFull
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: course.acceptingEnrollments && !course.isFull
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          course.isFull
                              ? 'Course is Full'
                              : (course.acceptingEnrollments
                                  ? 'Accepting Enrollments'
                                  : 'Enrollments Closed'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: course.acceptingEnrollments && !course.isFull
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(bool isDarkMode, Color categoryColor) {
    final items = <_InfoItem>[];

    if (course.duration != null) {
      items.add(_InfoItem(
        icon: Icons.access_time,
        label: 'Duration',
        value: course.duration!,
      ));
    }
    if (course.totalSessions != null) {
      items.add(_InfoItem(
        icon: Icons.calendar_view_month,
        label: 'Sessions',
        value: '${course.totalSessions}',
      ));
    }
    if (course.schedule != null) {
      items.add(_InfoItem(
        icon: Icons.schedule,
        label: 'Schedule',
        value: course.schedule!,
      ));
    }
    items.add(_InfoItem(
      icon: Icons.people,
      label: 'Enrolled',
      value: course.maxStudents != null
          ? '${course.enrolledStudents}/${course.maxStudents}'
          : '${course.enrolledStudents}',
    ));

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 18, color: categoryColor),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDarkMode ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                        Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem({required this.icon, required this.label, required this.value});
}
