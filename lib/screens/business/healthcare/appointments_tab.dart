import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';
import 'services_tab.dart';

/// Healthcare appointment status
enum PatientAppointmentStatus {
  pending,
  confirmed,
  checkedIn,
  inConsultation,
  completed,
  cancelled,
  noShow;

  String get displayName {
    switch (this) {
      case PatientAppointmentStatus.pending:
        return 'Pending';
      case PatientAppointmentStatus.confirmed:
        return 'Confirmed';
      case PatientAppointmentStatus.checkedIn:
        return 'Checked In';
      case PatientAppointmentStatus.inConsultation:
        return 'In Consultation';
      case PatientAppointmentStatus.completed:
        return 'Completed';
      case PatientAppointmentStatus.cancelled:
        return 'Cancelled';
      case PatientAppointmentStatus.noShow:
        return 'No Show';
    }
  }

  Color get color {
    switch (this) {
      case PatientAppointmentStatus.pending:
        return Colors.orange;
      case PatientAppointmentStatus.confirmed:
        return Colors.blue;
      case PatientAppointmentStatus.checkedIn:
        return Colors.teal;
      case PatientAppointmentStatus.inConsultation:
        return Colors.purple;
      case PatientAppointmentStatus.completed:
        return Colors.green;
      case PatientAppointmentStatus.cancelled:
        return Colors.red;
      case PatientAppointmentStatus.noShow:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case PatientAppointmentStatus.pending:
        return Icons.pending_outlined;
      case PatientAppointmentStatus.confirmed:
        return Icons.check_circle_outline;
      case PatientAppointmentStatus.checkedIn:
        return Icons.login;
      case PatientAppointmentStatus.inConsultation:
        return Icons.medical_services;
      case PatientAppointmentStatus.completed:
        return Icons.task_alt;
      case PatientAppointmentStatus.cancelled:
        return Icons.cancel_outlined;
      case PatientAppointmentStatus.noShow:
        return Icons.person_off_outlined;
    }
  }

  static PatientAppointmentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'confirmed':
        return PatientAppointmentStatus.confirmed;
      case 'checked_in':
      case 'checkedin':
        return PatientAppointmentStatus.checkedIn;
      case 'in_consultation':
      case 'inconsultation':
        return PatientAppointmentStatus.inConsultation;
      case 'completed':
        return PatientAppointmentStatus.completed;
      case 'cancelled':
        return PatientAppointmentStatus.cancelled;
      case 'no_show':
      case 'noshow':
        return PatientAppointmentStatus.noShow;
      default:
        return PatientAppointmentStatus.pending;
    }
  }
}

/// Patient appointment model
class PatientAppointment {
  final String id;
  final String businessId;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String? patientPhoto;
  final int? patientAge;
  final String? patientGender;
  final String serviceId;
  final String serviceName;
  final String serviceCategory;
  final double servicePrice;
  final DateTime dateTime;
  final PatientAppointmentStatus status;
  final String? symptoms;
  final String? doctorNotes;
  final String? prescription;
  final String? doctorId;
  final String? doctorName;
  final DateTime createdAt;

  PatientAppointment({
    required this.id,
    required this.businessId,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.patientPhoto,
    this.patientAge,
    this.patientGender,
    required this.serviceId,
    required this.serviceName,
    required this.serviceCategory,
    required this.servicePrice,
    required this.dateTime,
    required this.status,
    this.symptoms,
    this.doctorNotes,
    this.prescription,
    this.doctorId,
    this.doctorName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PatientAppointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientAppointment(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      patientId: data['patientId'] ?? data['customerId'] ?? '',
      patientName: data['patientName'] ?? data['customerName'] ?? 'Patient',
      patientPhone: data['patientPhone'] ?? data['customerPhone'],
      patientPhoto: data['patientPhoto'] ?? data['customerPhoto'],
      patientAge: data['patientAge'],
      patientGender: data['patientGender'],
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? 'Consultation',
      serviceCategory: data['serviceCategory'] ?? 'Consultation',
      servicePrice: (data['servicePrice'] ?? 0).toDouble(),
      dateTime: data['dateTime'] != null
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      status: PatientAppointmentStatus.fromString(data['status']),
      symptoms: data['symptoms'],
      doctorNotes: data['doctorNotes'],
      prescription: data['prescription'],
      doctorId: data['doctorId'],
      doctorName: data['doctorName'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientPhoto': patientPhoto,
      'patientAge': patientAge,
      'patientGender': patientGender,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceCategory': serviceCategory,
      'servicePrice': servicePrice,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status.name,
      'symptoms': symptoms,
      'doctorNotes': doctorNotes,
      'prescription': prescription,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get formattedTime => DateFormat('h:mm a').format(dateTime);
  String get formattedDate => DateFormat('EEE, MMM d').format(dateTime);
  String get formattedPrice => '₹${servicePrice.toStringAsFixed(0)}';

  String get patientInfo {
    final parts = <String>[];
    if (patientAge != null) parts.add('${patientAge}y');
    if (patientGender != null) parts.add(patientGender!);
    return parts.join(', ');
  }

  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }
}

/// Healthcare appointments tab
class HealthcareAppointmentsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const HealthcareAppointmentsTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<HealthcareAppointmentsTab> createState() =>
      _HealthcareAppointmentsTabState();
}

class _HealthcareAppointmentsTabState extends State<HealthcareAppointmentsTab> {
  String _selectedFilter = 'Today';
  final List<String> _filters = ['Today', 'Upcoming', 'Past', 'All'];

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
          'Patient Appointments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => _showDatePicker(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildFilterBar(isDarkMode),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAppointmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            );
          }

          final appointments = snapshot.data?.docs
                  .map((doc) => PatientAppointment.fromFirestore(doc))
                  .toList() ??
              [];

          if (appointments.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          // Group by date
          final groupedAppointments = <String, List<PatientAppointment>>{};
          for (final appointment in appointments) {
            final dateKey =
                DateFormat('yyyy-MM-dd').format(appointment.dateTime);
            groupedAppointments.putIfAbsent(dateKey, () => []);
            groupedAppointments[dateKey]!.add(appointment);
          }

          // Sort by time
          for (final key in groupedAppointments.keys) {
            groupedAppointments[key]!
                .sort((a, b) => a.dateTime.compareTo(b.dateTime));
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFF2196F3),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedAppointments.length,
              itemBuilder: (context, index) {
                final dateKey = groupedAppointments.keys.elementAt(index);
                final dateAppointments = groupedAppointments[dateKey]!;
                final date = DateTime.parse(dateKey);

                return _buildDateSection(date, dateAppointments, isDarkMode);
              },
            ),
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getAppointmentsStream() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('appointments');

    switch (_selectedFilter) {
      case 'Today':
        query = query
            .where('dateTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
            .where('dateTime', isLessThan: Timestamp.fromDate(endOfToday))
            .orderBy('dateTime');
        break;
      case 'Upcoming':
        query = query
            .where('dateTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('dateTime')
            .limit(50);
        break;
      case 'Past':
        query = query
            .where('dateTime', isLessThan: Timestamp.fromDate(now))
            .orderBy('dateTime', descending: true)
            .limit(50);
        break;
      default:
        query = query.orderBy('dateTime', descending: true).limit(100);
    }

    return query.snapshots();
  }

  Widget _buildFilterBar(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedFilter = filter);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2196F3)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSection(
    DateTime date,
    List<PatientAppointment> appointments,
    bool isDarkMode,
  ) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isToday
                          ? const Color(0xFF2196F3)
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isToday ? 'Today' : DateFormat('EEE, MMM d').format(date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? const Color(0xFF2196F3)
                            : (isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${appointments.length} patient${appointments.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        ...appointments.map(
          (appointment) => _PatientAppointmentCard(
            appointment: appointment,
            isDarkMode: isDarkMode,
            onTap: () => _showAppointmentDetails(appointment),
            onStatusChange: (status) =>
                _updateAppointmentStatus(appointment, status),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    String message;
    IconData icon;

    switch (_selectedFilter) {
      case 'Today':
        message = 'No appointments scheduled for today';
        icon = Icons.event_available;
        break;
      case 'Upcoming':
        message = 'No upcoming appointments';
        icon = Icons.event_note;
        break;
      case 'Past':
        message = 'No past appointments';
        icon = Icons.history;
        break;
      default:
        message = 'No appointments found';
        icon = Icons.calendar_today;
    }

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
                icon,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Patient appointments will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF2196F3),
                ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedFilter = 'All');
    }
  }

  void _showAppointmentDetails(PatientAppointment appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientAppointmentDetailsSheet(
        appointment: appointment,
        onStatusChange: (status) =>
            _updateAppointmentStatus(appointment, status),
      ),
    );
  }

  void _updateAppointmentStatus(
    PatientAppointment appointment,
    PatientAppointmentStatus status,
  ) async {
    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('appointments')
        .doc(appointment.id)
        .update({'status': status.name});

    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.displayName}'),
          backgroundColor: status.color,
        ),
      );
    }
  }
}

/// Patient appointment card
class _PatientAppointmentCard extends StatelessWidget {
  final PatientAppointment appointment;
  final bool isDarkMode;
  final VoidCallback onTap;
  final Function(PatientAppointmentStatus) onStatusChange;

  const _PatientAppointmentCard({
    required this.appointment,
    required this.isDarkMode,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        HealthcareServiceCategories.getColor(appointment.serviceCategory);
    final statusColor = appointment.status.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Time
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appointment.formattedTime,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Patient info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  categoryColor.withValues(alpha: 0.2),
                              backgroundImage:
                                  appointment.patientPhoto != null
                                      ? NetworkImage(appointment.patientPhoto!)
                                      : null,
                              child: appointment.patientPhoto == null
                                  ? Text(
                                      appointment.patientName[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: categoryColor,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appointment.patientName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (appointment.patientInfo.isNotEmpty)
                                    Text(
                                      appointment.patientInfo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white38
                                            : Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              HealthcareServiceCategories.getIcon(
                                  appointment.serviceCategory),
                              size: 14,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appointment.serviceName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              appointment.formattedPrice,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Symptoms preview
              if (appointment.symptoms != null &&
                  appointment.symptoms!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white10 : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.healing,
                        size: 14,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment.symptoms!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Status & Actions
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appointment.status.icon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appointment.status.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Quick actions
                  if (appointment.status ==
                      PatientAppointmentStatus.pending) ...[
                    _ActionButton(
                      icon: Icons.check,
                      color: Colors.green,
                      onTap: () =>
                          onStatusChange(PatientAppointmentStatus.confirmed),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.close,
                      color: Colors.red,
                      onTap: () =>
                          onStatusChange(PatientAppointmentStatus.cancelled),
                    ),
                  ] else if (appointment.status ==
                      PatientAppointmentStatus.confirmed) ...[
                    _ActionButton(
                      icon: Icons.login,
                      color: Colors.teal,
                      onTap: () =>
                          onStatusChange(PatientAppointmentStatus.checkedIn),
                    ),
                  ] else if (appointment.status ==
                      PatientAppointmentStatus.checkedIn) ...[
                    _ActionButton(
                      icon: Icons.medical_services,
                      color: Colors.purple,
                      onTap: () => onStatusChange(
                          PatientAppointmentStatus.inConsultation),
                    ),
                  ] else if (appointment.status ==
                      PatientAppointmentStatus.inConsultation) ...[
                    _ActionButton(
                      icon: Icons.task_alt,
                      color: Colors.green,
                      onTap: () =>
                          onStatusChange(PatientAppointmentStatus.completed),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// Patient appointment details sheet
class _PatientAppointmentDetailsSheet extends StatelessWidget {
  final PatientAppointment appointment;
  final Function(PatientAppointmentStatus) onStatusChange;

  const _PatientAppointmentDetailsSheet({
    required this.appointment,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor =
        HealthcareServiceCategories.getColor(appointment.serviceCategory);
    final statusColor = appointment.status.color;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          appointment.status.icon,
                          size: 28,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.status.displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'ID: ${appointment.id.substring(0, 8)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date & Time
                  _DetailSection(
                    title: 'Appointment',
                    icon: Icons.access_time,
                    color: categoryColor,
                    isDarkMode: isDarkMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.formattedDate,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'at ${appointment.formattedTime}',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Patient
                  _DetailSection(
                    title: 'Patient',
                    icon: Icons.person,
                    color: categoryColor,
                    isDarkMode: isDarkMode,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: categoryColor.withValues(alpha: 0.2),
                          backgroundImage: appointment.patientPhoto != null
                              ? NetworkImage(appointment.patientPhoto!)
                              : null,
                          child: appointment.patientPhoto == null
                              ? Text(
                                  appointment.patientName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: categoryColor,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (appointment.patientInfo.isNotEmpty)
                                Text(
                                  appointment.patientInfo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey[600],
                                  ),
                                ),
                              if (appointment.patientPhone != null)
                                Text(
                                  appointment.patientPhone!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (appointment.patientPhone != null)
                          IconButton(
                            icon: Icon(Icons.phone, color: categoryColor),
                            onPressed: () {},
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Service
                  _DetailSection(
                    title: 'Service',
                    icon: HealthcareServiceCategories.getIcon(
                        appointment.serviceCategory),
                    color: categoryColor,
                    isDarkMode: isDarkMode,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.serviceName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                appointment.serviceCategory,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          appointment.formattedPrice,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (appointment.symptoms != null) ...[
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Symptoms / Reason',
                      icon: Icons.healing,
                      color: categoryColor,
                      isDarkMode: isDarkMode,
                      child: Text(
                        appointment.symptoms!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Status actions
                  if (appointment.status != PatientAppointmentStatus.completed &&
                      appointment.status != PatientAppointmentStatus.cancelled)
                    _buildStatusActions(context, isDarkMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getAvailableStatuses().map((status) {
            return _StatusButton(
              status: status,
              onTap: () {
                onStatusChange(status);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PatientAppointmentStatus> _getAvailableStatuses() {
    switch (appointment.status) {
      case PatientAppointmentStatus.pending:
        return [
          PatientAppointmentStatus.confirmed,
          PatientAppointmentStatus.cancelled,
        ];
      case PatientAppointmentStatus.confirmed:
        return [
          PatientAppointmentStatus.checkedIn,
          PatientAppointmentStatus.noShow,
          PatientAppointmentStatus.cancelled,
        ];
      case PatientAppointmentStatus.checkedIn:
        return [
          PatientAppointmentStatus.inConsultation,
        ];
      case PatientAppointmentStatus.inConsultation:
        return [
          PatientAppointmentStatus.completed,
        ];
      default:
        return [];
    }
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final PatientAppointmentStatus status;
  final VoidCallback onTap;

  const _StatusButton({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: status.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 18, color: status.color),
            const SizedBox(width: 8),
            Text(
              status.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: status.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
