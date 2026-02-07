import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';
import 'services_tab.dart';

/// Appointment status
enum AppointmentStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  noShow;

  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.inProgress:
        return 'In Progress';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'No Show';
    }
  }

  Color get color {
    switch (this) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.blue;
      case AppointmentStatus.inProgress:
        return Colors.purple;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.noShow:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case AppointmentStatus.pending:
        return Icons.pending_outlined;
      case AppointmentStatus.confirmed:
        return Icons.check_circle_outline;
      case AppointmentStatus.inProgress:
        return Icons.play_circle_outline;
      case AppointmentStatus.completed:
        return Icons.task_alt;
      case AppointmentStatus.cancelled:
        return Icons.cancel_outlined;
      case AppointmentStatus.noShow:
        return Icons.person_off_outlined;
    }
  }

  static AppointmentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'in_progress':
      case 'inprogress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'no_show':
      case 'noshow':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.pending;
    }
  }
}

/// Salon appointment model
class SalonAppointment {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerPhoto;
  final String serviceId;
  final String serviceName;
  final String serviceCategory;
  final double servicePrice;
  final int serviceDuration;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? notes;
  final String? staffId;
  final String? staffName;
  final DateTime createdAt;

  SalonAppointment({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerPhoto,
    required this.serviceId,
    required this.serviceName,
    required this.serviceCategory,
    required this.servicePrice,
    required this.serviceDuration,
    required this.dateTime,
    required this.status,
    this.notes,
    this.staffId,
    this.staffName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SalonAppointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalonAppointment(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Customer',
      customerPhone: data['customerPhone'],
      customerPhoto: data['customerPhoto'],
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? 'Service',
      serviceCategory: data['serviceCategory'] ?? 'Other',
      servicePrice: (data['servicePrice'] ?? 0).toDouble(),
      serviceDuration: data['serviceDuration'] ?? 30,
      dateTime: data['dateTime'] != null
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      status: AppointmentStatus.fromString(data['status']),
      notes: data['notes'],
      staffId: data['staffId'],
      staffName: data['staffName'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerPhoto': customerPhoto,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceCategory': serviceCategory,
      'servicePrice': servicePrice,
      'serviceDuration': serviceDuration,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status.name,
      'notes': notes,
      'staffId': staffId,
      'staffName': staffName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  DateTime get endTime => dateTime.add(Duration(minutes: serviceDuration));

  String get formattedTime => DateFormat('h:mm a').format(dateTime);

  String get formattedDate => DateFormat('EEE, MMM d').format(dateTime);

  String get formattedPrice => '₹${servicePrice.toStringAsFixed(0)}';

  String get formattedDuration {
    if (serviceDuration >= 60) {
      final hours = serviceDuration ~/ 60;
      final mins = serviceDuration % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${serviceDuration}m';
  }

  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool get isPast => dateTime.isBefore(DateTime.now());
}

/// Bookings tab for Beauty & Wellness
class BeautyAppointmentsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const BeautyAppointmentsTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<BeautyAppointmentsTab> createState() => _BeautyAppointmentsTabState();
}

class _BeautyAppointmentsTabState extends State<BeautyAppointmentsTab> {
  String _selectedFilter = 'Today';
  DateTime _selectedDate = DateTime.now();
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
          'Bookings',
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
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
            );
          }

          final appointments = snapshot.data?.docs
                  .map((doc) => SalonAppointment.fromFirestore(doc))
                  .toList() ??
              [];

          if (appointments.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          // Group by date
          final groupedAppointments = <String, List<SalonAppointment>>{};
          for (final appointment in appointments) {
            final dateKey = DateFormat('yyyy-MM-dd').format(appointment.dateTime);
            groupedAppointments.putIfAbsent(dateKey, () => []);
            groupedAppointments[dateKey]!.add(appointment);
          }

          // Sort appointments by time within each day
          for (final key in groupedAppointments.keys) {
            groupedAppointments[key]!
                .sort((a, b) => a.dateTime.compareTo(b.dateTime));
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFFE91E63),
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
                      ? const Color(0xFFE91E63)
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
    List<SalonAppointment> appointments,
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
                      ? const Color(0xFFE91E63).withValues(alpha: 0.1)
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
                          ? const Color(0xFFE91E63)
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isToday ? 'Today' : DateFormat('EEE, MMM d').format(date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? const Color(0xFFE91E63)
                            : (isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${appointments.length} booking${appointments.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        ...appointments.map(
          (appointment) => _AppointmentCard(
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
        message = 'No bookings scheduled for today';
        icon = Icons.event_available;
        break;
      case 'Upcoming':
        message = 'No upcoming bookings';
        icon = Icons.event_note;
        break;
      case 'Past':
        message = 'No past bookings';
        icon = Icons.history;
        break;
      default:
        message = 'No bookings found';
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
                color: const Color(0xFFE91E63).withValues(alpha: 0.1),
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
              'Bookings will appear here when clients book your treatments',
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
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFFE91E63),
                ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedFilter = 'All';
      });
    }
  }

  void _showAppointmentDetails(SalonAppointment appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppointmentDetailsSheet(
        appointment: appointment,
        onStatusChange: (status) =>
            _updateAppointmentStatus(appointment, status),
      ),
    );
  }

  void _updateAppointmentStatus(
    SalonAppointment appointment,
    AppointmentStatus status,
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
          content: Text('Booking ${status.displayName.toLowerCase()}'),
          backgroundColor: status.color,
        ),
      );
    }
  }
}

/// Appointment card widget
class _AppointmentCard extends StatelessWidget {
  final SalonAppointment appointment;
  final bool isDarkMode;
  final VoidCallback onTap;
  final Function(AppointmentStatus) onStatusChange;

  const _AppointmentCard({
    required this.appointment,
    required this.isDarkMode,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        SalonServiceCategories.getColor(appointment.serviceCategory);
    final statusColor = appointment.status.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: statusColor,
              width: 4,
            ),
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
                    child: Column(
                      children: [
                        Text(
                          appointment.formattedTime,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        Text(
                          appointment.formattedDuration,
                          style: TextStyle(
                            fontSize: 11,
                            color: categoryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Customer & Service info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: categoryColor.withValues(alpha: 0.2),
                              backgroundImage: appointment.customerPhoto != null
                                  ? NetworkImage(appointment.customerPhoto!)
                                  : null,
                              child: appointment.customerPhoto == null
                                  ? Text(
                                      appointment.customerName[0].toUpperCase(),
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
                              child: Text(
                                appointment.customerName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              SalonServiceCategories.getIcon(
                                  appointment.serviceCategory),
                              size: 14,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
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
                  // Quick actions based on status
                  if (appointment.status == AppointmentStatus.pending) ...[
                    _ActionButton(
                      icon: Icons.check,
                      color: Colors.green,
                      onTap: () => onStatusChange(AppointmentStatus.confirmed),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.close,
                      color: Colors.red,
                      onTap: () => onStatusChange(AppointmentStatus.cancelled),
                    ),
                  ] else if (appointment.status ==
                      AppointmentStatus.confirmed) ...[
                    _ActionButton(
                      icon: Icons.play_arrow,
                      color: Colors.purple,
                      onTap: () => onStatusChange(AppointmentStatus.inProgress),
                    ),
                  ] else if (appointment.status ==
                      AppointmentStatus.inProgress) ...[
                    _ActionButton(
                      icon: Icons.task_alt,
                      color: Colors.green,
                      onTap: () => onStatusChange(AppointmentStatus.completed),
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

/// Appointment details sheet
class _AppointmentDetailsSheet extends StatelessWidget {
  final SalonAppointment appointment;
  final Function(AppointmentStatus) onStatusChange;

  const _AppointmentDetailsSheet({
    required this.appointment,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor =
        SalonServiceCategories.getColor(appointment.serviceCategory);
    final statusColor = appointment.status.color;

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
                  // Header with status
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
                              'Booking ID: ${appointment.id.substring(0, 8)}',
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
                    title: 'Date & Time',
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
                          '${appointment.formattedTime} - ${DateFormat('h:mm a').format(appointment.endTime)}',
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

                  // Client
                  _DetailSection(
                    title: 'Client',
                    icon: Icons.person,
                    color: categoryColor,
                    isDarkMode: isDarkMode,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: categoryColor.withValues(alpha: 0.2),
                          backgroundImage: appointment.customerPhoto != null
                              ? NetworkImage(appointment.customerPhoto!)
                              : null,
                          child: appointment.customerPhoto == null
                              ? Text(
                                  appointment.customerName[0].toUpperCase(),
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
                                appointment.customerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (appointment.customerPhone != null)
                                Text(
                                  appointment.customerPhone!,
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
                        if (appointment.customerPhone != null)
                          IconButton(
                            icon: Icon(Icons.phone, color: categoryColor),
                            onPressed: () {
                              // Call customer
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Treatment
                  _DetailSection(
                    title: 'Treatment',
                    icon: SalonServiceCategories.getIcon(
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
                                  color:
                                      isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    appointment.serviceCategory,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const Text(' • '),
                                  Text(
                                    appointment.formattedDuration,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
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

                  if (appointment.notes != null) ...[
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Notes',
                      icon: Icons.note,
                      color: categoryColor,
                      isDarkMode: isDarkMode,
                      child: Text(
                        appointment.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Status actions
                  if (appointment.status != AppointmentStatus.completed &&
                      appointment.status != AppointmentStatus.cancelled)
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
          children: [
            if (appointment.status == AppointmentStatus.pending) ...[
              _StatusButton(
                status: AppointmentStatus.confirmed,
                onTap: () {
                  onStatusChange(AppointmentStatus.confirmed);
                  Navigator.pop(context);
                },
              ),
              _StatusButton(
                status: AppointmentStatus.cancelled,
                onTap: () {
                  onStatusChange(AppointmentStatus.cancelled);
                  Navigator.pop(context);
                },
              ),
            ] else if (appointment.status == AppointmentStatus.confirmed) ...[
              _StatusButton(
                status: AppointmentStatus.inProgress,
                onTap: () {
                  onStatusChange(AppointmentStatus.inProgress);
                  Navigator.pop(context);
                },
              ),
              _StatusButton(
                status: AppointmentStatus.noShow,
                onTap: () {
                  onStatusChange(AppointmentStatus.noShow);
                  Navigator.pop(context);
                },
              ),
              _StatusButton(
                status: AppointmentStatus.cancelled,
                onTap: () {
                  onStatusChange(AppointmentStatus.cancelled);
                  Navigator.pop(context);
                },
              ),
            ] else if (appointment.status == AppointmentStatus.inProgress) ...[
              _StatusButton(
                status: AppointmentStatus.completed,
                onTap: () {
                  onStatusChange(AppointmentStatus.completed);
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ],
    );
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
  final AppointmentStatus status;
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
