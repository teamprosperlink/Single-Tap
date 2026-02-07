import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';
import 'courses_tab.dart';

/// Enrollment status
enum EnrollmentStatus {
  pending,
  confirmed,
  active,
  completed,
  cancelled,
  refunded;

  String get displayName {
    switch (this) {
      case EnrollmentStatus.pending:
        return 'Pending';
      case EnrollmentStatus.confirmed:
        return 'Confirmed';
      case EnrollmentStatus.active:
        return 'Active';
      case EnrollmentStatus.completed:
        return 'Completed';
      case EnrollmentStatus.cancelled:
        return 'Cancelled';
      case EnrollmentStatus.refunded:
        return 'Refunded';
    }
  }

  Color get color {
    switch (this) {
      case EnrollmentStatus.pending:
        return Colors.orange;
      case EnrollmentStatus.confirmed:
        return Colors.blue;
      case EnrollmentStatus.active:
        return Colors.green;
      case EnrollmentStatus.completed:
        return Colors.purple;
      case EnrollmentStatus.cancelled:
        return Colors.red;
      case EnrollmentStatus.refunded:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case EnrollmentStatus.pending:
        return Icons.hourglass_empty;
      case EnrollmentStatus.confirmed:
        return Icons.check_circle_outline;
      case EnrollmentStatus.active:
        return Icons.play_circle_filled;
      case EnrollmentStatus.completed:
        return Icons.school;
      case EnrollmentStatus.cancelled:
        return Icons.cancel;
      case EnrollmentStatus.refunded:
        return Icons.money_off;
    }
  }

  static EnrollmentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'confirmed':
        return EnrollmentStatus.confirmed;
      case 'active':
        return EnrollmentStatus.active;
      case 'completed':
        return EnrollmentStatus.completed;
      case 'cancelled':
        return EnrollmentStatus.cancelled;
      case 'refunded':
        return EnrollmentStatus.refunded;
      default:
        return EnrollmentStatus.pending;
    }
  }
}

/// Payment status
enum PaymentStatus {
  pending,
  paid,
  partial,
  refunded;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.partial:
        return Colors.blue;
      case PaymentStatus.refunded:
        return Colors.grey;
    }
  }

  static PaymentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }
}

/// Enrollment model
class EnrollmentModel {
  final String id;
  final String businessId;
  final String courseId;
  final String courseName;
  final String courseCategory;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? studentPhone;
  final String? studentPhoto;
  final EnrollmentStatus status;
  final PaymentStatus paymentStatus;
  final double amountPaid;
  final double totalAmount;
  final int sessionsAttended;
  final int totalSessions;
  final double? progressPercent;
  final String? notes;
  final DateTime enrolledAt;
  final DateTime? startDate;
  final DateTime? completedAt;

  EnrollmentModel({
    required this.id,
    required this.businessId,
    required this.courseId,
    required this.courseName,
    required this.courseCategory,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.studentPhone,
    this.studentPhoto,
    this.status = EnrollmentStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.amountPaid = 0,
    required this.totalAmount,
    this.sessionsAttended = 0,
    this.totalSessions = 0,
    this.progressPercent,
    this.notes,
    DateTime? enrolledAt,
    this.startDate,
    this.completedAt,
  }) : enrolledAt = enrolledAt ?? DateTime.now();

  factory EnrollmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EnrollmentModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      courseCategory: data['courseCategory'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'],
      studentPhone: data['studentPhone'],
      studentPhoto: data['studentPhoto'],
      status: EnrollmentStatus.fromString(data['status']),
      paymentStatus: PaymentStatus.fromString(data['paymentStatus']),
      amountPaid: (data['amountPaid'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      sessionsAttended: data['sessionsAttended'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      progressPercent: data['progressPercent']?.toDouble(),
      notes: data['notes'],
      enrolledAt: data['enrolledAt'] != null
          ? (data['enrolledAt'] as Timestamp).toDate()
          : DateTime.now(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'courseId': courseId,
      'courseName': courseName,
      'courseCategory': courseCategory,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'studentPhoto': studentPhoto,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'amountPaid': amountPaid,
      'totalAmount': totalAmount,
      'sessionsAttended': sessionsAttended,
      'totalSessions': totalSessions,
      'progressPercent': progressPercent,
      'notes': notes,
      'enrolledAt': Timestamp.fromDate(enrolledAt),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  EnrollmentModel copyWith({
    String? id,
    String? businessId,
    String? courseId,
    String? courseName,
    String? courseCategory,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? studentPhone,
    String? studentPhoto,
    EnrollmentStatus? status,
    PaymentStatus? paymentStatus,
    double? amountPaid,
    double? totalAmount,
    int? sessionsAttended,
    int? totalSessions,
    double? progressPercent,
    String? notes,
    DateTime? enrolledAt,
    DateTime? startDate,
    DateTime? completedAt,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      courseCategory: courseCategory ?? this.courseCategory,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      studentPhone: studentPhone ?? this.studentPhone,
      studentPhoto: studentPhoto ?? this.studentPhoto,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      totalAmount: totalAmount ?? this.totalAmount,
      sessionsAttended: sessionsAttended ?? this.sessionsAttended,
      totalSessions: totalSessions ?? this.totalSessions,
      progressPercent: progressPercent ?? this.progressPercent,
      notes: notes ?? this.notes,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      startDate: startDate ?? this.startDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Education enrollments tab
class EducationEnrollmentsTab extends StatefulWidget {
  final BusinessModel business;

  const EducationEnrollmentsTab({super.key, required this.business});

  @override
  State<EducationEnrollmentsTab> createState() => _EducationEnrollmentsTabState();
}

class _EducationEnrollmentsTabState extends State<EducationEnrollmentsTab> {
  String _selectedFilter = 'Active';
  String? _selectedCourse;

  final List<String> _filters = [
    'Active',
    'Pending',
    'Completed',
    'Cancelled',
    'All',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = filter);
                        },
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Course filter dropdown
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseProvider.firestore
                    .collection('businesses')
                    .doc(widget.business.id)
                    .collection('courses')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final courses = snapshot.data?.docs ?? [];
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedCourse,
                    decoration: InputDecoration(
                      labelText: 'Filter by Course',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Courses'),
                      ),
                      ...courses.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String?>(
                          value: doc.id,
                          child: Text(data['name'] ?? 'Unknown'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCourse = value);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // Enrollments list
        Expanded(
          child: _buildEnrollmentsList(),
        ),
      ],
    );
  }

  Widget _buildEnrollmentsList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('enrollments');

    // Apply status filter
    if (_selectedFilter == 'Active') {
      query = query.where('status', isEqualTo: 'active');
    } else if (_selectedFilter == 'Pending') {
      query = query.where('status', whereIn: ['pending', 'confirmed']);
    } else if (_selectedFilter == 'Completed') {
      query = query.where('status', isEqualTo: 'completed');
    } else if (_selectedFilter == 'Cancelled') {
      query = query.where('status', whereIn: ['cancelled', 'refunded']);
    }

    // Apply course filter
    if (_selectedCourse != null) {
      query = query.where('courseId', isEqualTo: _selectedCourse);
    }

    query = query.orderBy('enrolledAt', descending: true).limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final enrollments = snapshot.data!.docs
            .map((doc) => EnrollmentModel.fromFirestore(doc))
            .toList();

        if (enrollments.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: enrollments.length,
          itemBuilder: (context, index) {
            return _EnrollmentCard(
              enrollment: enrollments[index],
              onTap: () => _showEnrollmentDetails(enrollments[index]),
              onStatusChange: (status) =>
                  _updateEnrollmentStatus(enrollments[index], status),
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
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No enrollments found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Students will appear here when they enroll'
                : 'No ${_selectedFilter.toLowerCase()} enrollments',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEnrollmentStatus(
    EnrollmentModel enrollment,
    EnrollmentStatus newStatus,
  ) async {
    try {
      final updates = <String, dynamic>{'status': newStatus.name};

      if (newStatus == EnrollmentStatus.active && enrollment.startDate == null) {
        updates['startDate'] = Timestamp.now();
      } else if (newStatus == EnrollmentStatus.completed) {
        updates['completedAt'] = Timestamp.now();
        updates['progressPercent'] = 100.0;
      }

      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('enrollments')
          .doc(enrollment.id)
          .update(updates);

      // Update enrolled count on course if status changed to/from active
      if (newStatus == EnrollmentStatus.active &&
          enrollment.status != EnrollmentStatus.active) {
        await _updateCourseEnrollmentCount(enrollment.courseId, 1);
      } else if (enrollment.status == EnrollmentStatus.active &&
          newStatus != EnrollmentStatus.active) {
        await _updateCourseEnrollmentCount(enrollment.courseId, -1);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCourseEnrollmentCount(String courseId, int delta) async {
    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('courses')
        .doc(courseId)
        .update({
      'enrolledStudents': FieldValue.increment(delta),
    });
  }

  void _showEnrollmentDetails(EnrollmentModel enrollment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EnrollmentDetailsSheet(
        enrollment: enrollment,
        businessId: widget.business.id,
        onUpdate: () => setState(() {}),
      ),
    );
  }
}

/// Enrollment card widget
class _EnrollmentCard extends StatelessWidget {
  final EnrollmentModel enrollment;
  final VoidCallback onTap;
  final Function(EnrollmentStatus) onStatusChange;

  const _EnrollmentCard({
    required this.enrollment,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = CourseCategories.getColor(enrollment.courseCategory);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Student avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: categoryColor.withValues(alpha: 0.2),
                    backgroundImage: enrollment.studentPhoto != null
                        ? NetworkImage(enrollment.studentPhoto!)
                        : null,
                    child: enrollment.studentPhoto == null
                        ? Text(
                            enrollment.studentName.isNotEmpty
                                ? enrollment.studentName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Student info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enrollment.studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          enrollment.courseName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: enrollment.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          enrollment.status.icon,
                          size: 16,
                          color: enrollment.status.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          enrollment.status.displayName,
                          style: TextStyle(
                            color: enrollment.status.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Progress and payment row
              Row(
                children: [
                  // Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: enrollment.totalSessions > 0
                                      ? enrollment.sessionsAttended /
                                          enrollment.totalSessions
                                      : (enrollment.progressPercent ?? 0) / 100,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    categoryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              enrollment.totalSessions > 0
                                  ? '${enrollment.sessionsAttended}/${enrollment.totalSessions}'
                                  : '${(enrollment.progressPercent ?? 0).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Payment
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  enrollment.paymentStatus.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              enrollment.paymentStatus.displayName,
                              style: TextStyle(
                                color: enrollment.paymentStatus.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${enrollment.amountPaid.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/₹${enrollment.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Quick actions
              if (enrollment.status == EnrollmentStatus.pending ||
                  enrollment.status == EnrollmentStatus.confirmed) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (enrollment.status == EnrollmentStatus.pending) ...[
                      TextButton(
                        onPressed: () =>
                            onStatusChange(EnrollmentStatus.cancelled),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            onStatusChange(EnrollmentStatus.confirmed),
                        child: const Text('Confirm'),
                      ),
                    ] else if (enrollment.status == EnrollmentStatus.confirmed)
                      ElevatedButton.icon(
                        onPressed: () =>
                            onStatusChange(EnrollmentStatus.active),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start Course'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Enrollment details sheet
class _EnrollmentDetailsSheet extends StatefulWidget {
  final EnrollmentModel enrollment;
  final String businessId;
  final VoidCallback onUpdate;

  const _EnrollmentDetailsSheet({
    required this.enrollment,
    required this.businessId,
    required this.onUpdate,
  });

  @override
  State<_EnrollmentDetailsSheet> createState() =>
      _EnrollmentDetailsSheetState();
}

class _EnrollmentDetailsSheetState extends State<_EnrollmentDetailsSheet> {
  late EnrollmentModel _enrollment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _enrollment = widget.enrollment;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = CourseCategories.getColor(_enrollment.courseCategory);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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

                // Student header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: categoryColor.withValues(alpha: 0.2),
                      backgroundImage: _enrollment.studentPhoto != null
                          ? NetworkImage(_enrollment.studentPhoto!)
                          : null,
                      child: _enrollment.studentPhoto == null
                          ? Text(
                              _enrollment.studentName.isNotEmpty
                                  ? _enrollment.studentName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: categoryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _enrollment.studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_enrollment.studentEmail != null)
                            Text(
                              _enrollment.studentEmail!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          if (_enrollment.studentPhone != null)
                            Text(
                              _enrollment.studentPhone!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Course info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CourseCategories.getIcon(_enrollment.courseCategory),
                        color: categoryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _enrollment.courseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _enrollment.courseCategory,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Status section
                _buildSection(
                  'Status',
                  Column(
                    children: [
                      _buildStatusRow(
                        'Enrollment Status',
                        _enrollment.status.displayName,
                        _enrollment.status.color,
                        _enrollment.status.icon,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        'Payment Status',
                        _enrollment.paymentStatus.displayName,
                        _enrollment.paymentStatus.color,
                        Icons.payment,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progress section
                _buildSection(
                  'Progress',
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sessions Attended',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            '${_enrollment.sessionsAttended} / ${_enrollment.totalSessions}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _enrollment.totalSessions > 0
                              ? _enrollment.sessionsAttended /
                                  _enrollment.totalSessions
                              : (_enrollment.progressPercent ?? 0) / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(categoryColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _enrollment.sessionsAttended > 0
                                  ? () => _updateSessions(-1)
                                  : null,
                              icon: const Icon(Icons.remove),
                              label: const Text('Session'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _enrollment.sessionsAttended <
                                          _enrollment.totalSessions ||
                                      _enrollment.totalSessions == 0
                                  ? () => _updateSessions(1)
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Session'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Payment section
                _buildSection(
                  'Payment Details',
                  Column(
                    children: [
                      _buildInfoRow('Total Amount',
                          '₹${_enrollment.totalAmount.toStringAsFixed(2)}'),
                      _buildInfoRow('Amount Paid',
                          '₹${_enrollment.amountPaid.toStringAsFixed(2)}'),
                      _buildInfoRow(
                        'Balance Due',
                        '₹${(_enrollment.totalAmount - _enrollment.amountPaid).toStringAsFixed(2)}',
                        valueColor:
                            _enrollment.totalAmount > _enrollment.amountPaid
                                ? Colors.red
                                : Colors.green,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showRecordPaymentDialog,
                          icon: const Icon(Icons.payment),
                          label: const Text('Record Payment'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Dates section
                _buildSection(
                  'Dates',
                  Column(
                    children: [
                      _buildInfoRow('Enrolled', dateFormat.format(_enrollment.enrolledAt)),
                      if (_enrollment.startDate != null)
                        _buildInfoRow(
                            'Started', dateFormat.format(_enrollment.startDate!)),
                      if (_enrollment.completedAt != null)
                        _buildInfoRow('Completed',
                            dateFormat.format(_enrollment.completedAt!)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Notes section
                if (_enrollment.notes != null && _enrollment.notes!.isNotEmpty)
                  _buildSection(
                    'Notes',
                    Text(_enrollment.notes!),
                  ),

                const SizedBox(height: 24),

                // Status change buttons
                if (_enrollment.status != EnrollmentStatus.completed &&
                    _enrollment.status != EnrollmentStatus.cancelled &&
                    _enrollment.status != EnrollmentStatus.refunded) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Update Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getAvailableStatusTransitions()
                        .map((status) => ActionChip(
                              avatar: Icon(status.icon, size: 18),
                              label: Text(status.displayName),
                              onPressed: _isLoading
                                  ? null
                                  : () => _updateStatus(status),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color color, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Container(
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
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<EnrollmentStatus> _getAvailableStatusTransitions() {
    switch (_enrollment.status) {
      case EnrollmentStatus.pending:
        return [EnrollmentStatus.confirmed, EnrollmentStatus.cancelled];
      case EnrollmentStatus.confirmed:
        return [EnrollmentStatus.active, EnrollmentStatus.cancelled];
      case EnrollmentStatus.active:
        return [EnrollmentStatus.completed, EnrollmentStatus.cancelled];
      default:
        return [];
    }
  }

  Future<void> _updateStatus(EnrollmentStatus newStatus) async {
    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{'status': newStatus.name};

      if (newStatus == EnrollmentStatus.active && _enrollment.startDate == null) {
        updates['startDate'] = Timestamp.now();
      } else if (newStatus == EnrollmentStatus.completed) {
        updates['completedAt'] = Timestamp.now();
        updates['progressPercent'] = 100.0;
      }

      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('enrollments')
          .doc(_enrollment.id)
          .update(updates);

      setState(() {
        _enrollment = _enrollment.copyWith(
          status: newStatus,
          startDate: newStatus == EnrollmentStatus.active
              ? DateTime.now()
              : _enrollment.startDate,
          completedAt: newStatus == EnrollmentStatus.completed
              ? DateTime.now()
              : _enrollment.completedAt,
        );
      });

      widget.onUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  Future<void> _updateSessions(int delta) async {
    final newCount = _enrollment.sessionsAttended + delta;
    if (newCount < 0) return;

    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('enrollments')
          .doc(_enrollment.id)
          .update({'sessionsAttended': newCount});

      setState(() {
        _enrollment = _enrollment.copyWith(sessionsAttended: newCount);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRecordPaymentDialog() {
    final controller = TextEditingController();
    final remaining = _enrollment.totalAmount - _enrollment.amountPaid;
    controller.text = remaining.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance due: ₹${remaining.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) return;

              Navigator.pop(context);
              await _recordPayment(amount);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(double amount) async {
    try {
      final newPaid = _enrollment.amountPaid + amount;
      final newStatus = newPaid >= _enrollment.totalAmount
          ? PaymentStatus.paid
          : PaymentStatus.partial;

      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('enrollments')
          .doc(_enrollment.id)
          .update({
        'amountPaid': newPaid,
        'paymentStatus': newStatus.name,
      });

      setState(() {
        _enrollment = _enrollment.copyWith(
          amountPaid: newPaid,
          paymentStatus: newStatus,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
