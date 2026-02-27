import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled;

  static BookingStatus fromString(String? value) {
    switch (value) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
}

class BookingModel {
  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String businessOwnerId;
  final String businessName;
  final String? serviceId;
  final String? serviceName;
  final double? servicePrice;
  final BookingStatus status;
  final DateTime bookingDate;
  final String? bookingTime;
  final int? duration; // minutes
  final String? notes;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.businessOwnerId,
    required this.businessName,
    this.serviceId,
    this.serviceName,
    this.servicePrice,
    this.status = BookingStatus.pending,
    required this.bookingDate,
    this.bookingTime,
    this.duration,
    this.notes,
    this.cancelReason,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel.fromMap(data, doc.id);
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      businessOwnerId: map['businessOwnerId'] ?? '',
      businessName: map['businessName'] ?? '',
      serviceId: map['serviceId'],
      serviceName: map['serviceName'],
      servicePrice: (map['servicePrice'] as num?)?.toDouble(),
      status: BookingStatus.fromString(map['status']),
      bookingDate: map['bookingDate'] != null
          ? (map['bookingDate'] as Timestamp).toDate()
          : DateTime.now(),
      bookingTime: map['bookingTime'],
      duration: map['duration'] as int?,
      notes: map['notes'],
      cancelReason: map['cancelReason'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'businessOwnerId': businessOwnerId,
      'businessName': businessName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'status': status.name,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'bookingTime': bookingTime,
      'duration': duration,
      'notes': notes,
      'cancelReason': cancelReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  BookingModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? businessOwnerId,
    String? businessName,
    String? serviceId,
    String? serviceName,
    double? servicePrice,
    BookingStatus? status,
    DateTime? bookingDate,
    String? bookingTime,
    int? duration,
    String? notes,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      businessName: businessName ?? this.businessName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      servicePrice: servicePrice ?? this.servicePrice,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      duration: duration ?? this.duration,
      notes: notes ?? this.notes,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[bookingDate.month - 1]} ${bookingDate.day}, ${bookingDate.year}';
  }

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formattedDate;
  }
}
