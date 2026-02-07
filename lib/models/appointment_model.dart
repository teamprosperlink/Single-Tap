import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/currency_utils.dart';

/// Appointment status enum
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

  String get colorHex {
    switch (this) {
      case AppointmentStatus.pending:
        return '#FF9800'; // Orange
      case AppointmentStatus.confirmed:
        return '#4CAF50'; // Green
      case AppointmentStatus.inProgress:
        return '#2196F3'; // Blue
      case AppointmentStatus.completed:
        return '#00D67D'; // Primary green
      case AppointmentStatus.cancelled:
        return '#F44336'; // Red
      case AppointmentStatus.noShow:
        return '#9E9E9E'; // Grey
    }
  }

  static AppointmentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'inprogress':
      case 'in_progress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'noshow':
      case 'no_show':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.pending;
    }
  }
}

/// Time slot model for available appointment slots
class TimeSlot {
  final String startTime; // Format: "HH:mm"
  final String endTime;   // Format: "HH:mm"
  final bool isAvailable;
  final String? appointmentId; // If booked, the appointment ID

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.appointmentId,
  });

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      appointmentId: map['appointmentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      'appointmentId': appointmentId,
    };
  }

  /// Get duration in minutes
  int get durationMinutes {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    if (start == null || end == null) return 0;
    return end - start;
  }

  int? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  /// Format time for display (e.g., "9:00 AM")
  String get formattedStartTime => _formatTimeForDisplay(startTime);
  String get formattedEndTime => _formatTimeForDisplay(endTime);

  String _formatTimeForDisplay(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts[1];
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '$displayHours:$minutes $period';
  }

  /// Get display string
  String get displayString => '$formattedStartTime - $formattedEndTime';

  TimeSlot copyWith({
    String? startTime,
    String? endTime,
    bool? isAvailable,
    String? appointmentId,
  }) {
    return TimeSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAvailable: isAvailable ?? this.isAvailable,
      appointmentId: appointmentId ?? this.appointmentId,
    );
  }
}

/// Appointment model for service-based businesses
class AppointmentModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerPhoto;
  final String? serviceId;
  final String serviceName;
  final String? staffId;
  final String? staffName;
  final DateTime appointmentDate;
  final String startTime; // Format: "HH:mm"
  final String endTime;   // Format: "HH:mm"
  final int duration; // Duration in minutes
  final AppointmentStatus status;
  final String? notes;
  final String? customerNotes;
  final double? price;
  final String currency;
  final String? cancellationReason;
  final String? cancelledBy; // 'customer' or 'business'
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerPhoto,
    this.serviceId,
    required this.serviceName,
    this.staffId,
    this.staffName,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.status = AppointmentStatus.pending,
    this.notes,
    this.customerNotes,
    this.price,
    this.currency = 'INR',
    this.cancellationReason,
    this.cancelledBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Backward compatibility getter
  DateTime get dateTime => appointmentDate;

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel.fromMap(data, doc.id);
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AppointmentModel(
      id: id,
      businessId: map['businessId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      customerEmail: map['customerEmail'],
      customerPhoto: map['customerPhoto'],
      serviceId: map['serviceId'],
      serviceName: map['serviceName'] ?? '',
      staffId: map['staffId'],
      staffName: map['staffName'],
      appointmentDate: map['appointmentDate'] != null
          ? (map['appointmentDate'] as Timestamp).toDate()
          : DateTime.now(),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      duration: map['duration'] ?? 30,
      status: AppointmentStatus.fromString(map['status']),
      notes: map['notes'],
      customerNotes: map['customerNotes'],
      price: map['price']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      cancellationReason: map['cancellationReason'],
      cancelledBy: map['cancelledBy'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerPhoto': customerPhoto,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'staffId': staffId,
      'staffName': staffName,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'status': status.name,
      'notes': notes,
      'customerNotes': customerNotes,
      'price': price,
      'currency': currency,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerPhoto,
    String? serviceId,
    String? serviceName,
    String? staffId,
    String? staffName,
    DateTime? appointmentDate,
    String? startTime,
    String? endTime,
    int? duration,
    AppointmentStatus? status,
    String? notes,
    String? customerNotes,
    double? price,
    String? currency,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhoto: customerPhoto ?? this.customerPhoto,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      customerNotes: customerNotes ?? this.customerNotes,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted time range
  String get formattedTimeRange {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts[1];
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '$displayHours:$minutes $period';
  }

  /// Get formatted date
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[appointmentDate.weekday - 1]}, ${months[appointmentDate.month - 1]} ${appointmentDate.day}';
  }

  /// Get formatted price
  String get formattedPrice {
    if (price == null) return 'Free';
    return CurrencyUtils.format(price!, currency);
  }

  /// Get formatted duration
  String get formattedDuration {
    if (duration < 60) {
      return '$duration min';
    } else if (duration % 60 == 0) {
      return '${duration ~/ 60} hr';
    } else {
      return '${duration ~/ 60} hr ${duration % 60} min';
    }
  }

  /// Check if appointment is upcoming
  bool get isUpcoming {
    final now = DateTime.now();
    final appointmentDateTime = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      int.parse(startTime.split(':')[0]),
      int.parse(startTime.split(':')[1]),
    );
    return appointmentDateTime.isAfter(now) &&
        status != AppointmentStatus.cancelled &&
        status != AppointmentStatus.completed;
  }

  /// Check if appointment is today
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  /// Check if appointment can be cancelled
  bool get canCancel {
    return status == AppointmentStatus.pending ||
        status == AppointmentStatus.confirmed;
  }

  /// Check if appointment can be confirmed
  bool get canConfirm {
    return status == AppointmentStatus.pending;
  }

  /// Check if appointment can be started
  bool get canStart {
    return status == AppointmentStatus.confirmed;
  }

  /// Check if appointment can be completed
  bool get canComplete {
    return status == AppointmentStatus.inProgress;
  }

  /// Check if appointment can be marked as no-show
  bool get canMarkNoShow {
    return status == AppointmentStatus.confirmed && !isUpcoming;
  }

  /// Generate appointment ID
  static String generateAppointmentId() {
    final now = DateTime.now();
    final year = now.year;
    final random = now.millisecondsSinceEpoch % 100000;
    return 'APT-$year-${random.toString().padLeft(5, '0')}';
  }
}

/// Appointment filter options
class AppointmentFilters {
  static const String all = 'All';
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String noShow = 'No Show';

  static const List<String> allFilters = [
    all,
    pending,
    confirmed,
    inProgress,
    completed,
    cancelled,
    noShow,
  ];

  static AppointmentStatus? getStatusFromFilter(String filter) {
    switch (filter) {
      case pending:
        return AppointmentStatus.pending;
      case confirmed:
        return AppointmentStatus.confirmed;
      case inProgress:
        return AppointmentStatus.inProgress;
      case completed:
        return AppointmentStatus.completed;
      case cancelled:
        return AppointmentStatus.cancelled;
      case noShow:
        return AppointmentStatus.noShow;
      default:
        return null;
    }
  }
}

/// Staff member model for appointment scheduling
class StaffMember {
  final String id;
  final String name;
  final String? photo;
  final List<String> serviceIds; // Services this staff can provide
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.name,
    this.photo,
    this.serviceIds = const [],
    this.isActive = true,
  });

  factory StaffMember.fromMap(Map<String, dynamic> map, String id) {
    return StaffMember(
      id: id,
      name: map['name'] ?? '',
      photo: map['photo'],
      serviceIds: List<String>.from(map['serviceIds'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photo': photo,
      'serviceIds': serviceIds,
      'isActive': isActive,
    };
  }
}
