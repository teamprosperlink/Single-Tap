import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/currency_utils.dart';

/// Booking types - determines workflow and UI
enum BookingType {
  order,          // Product orders (Retail, Grocery)
  foodOrder,      // Food orders (Restaurant)
  appointment,    // Service appointments (Healthcare, Beauty, etc.)
  reservation,    // Table/seat reservations (Restaurant)
  roomBooking,    // Room bookings (Hospitality)
  enrollment,     // Course enrollments (Education)
  eventBooking,   // Event bookings (Entertainment, Wedding)
  projectRequest, // Project/quote requests (Construction)
  commission,     // Commission requests (Art & Creative)
}

extension BookingTypeExtension on BookingType {
  String get displayName {
    switch (this) {
      case BookingType.order: return 'Order';
      case BookingType.foodOrder: return 'Order';
      case BookingType.appointment: return 'Appointment';
      case BookingType.reservation: return 'Reservation';
      case BookingType.roomBooking: return 'Booking';
      case BookingType.enrollment: return 'Enrollment';
      case BookingType.eventBooking: return 'Booking';
      case BookingType.projectRequest: return 'Project';
      case BookingType.commission: return 'Commission';
    }
  }

  IconData get icon {
    switch (this) {
      case BookingType.order: return Icons.shopping_bag;
      case BookingType.foodOrder: return Icons.restaurant;
      case BookingType.appointment: return Icons.calendar_today;
      case BookingType.reservation: return Icons.table_restaurant;
      case BookingType.roomBooking: return Icons.hotel;
      case BookingType.enrollment: return Icons.school;
      case BookingType.eventBooking: return Icons.celebration;
      case BookingType.projectRequest: return Icons.construction;
      case BookingType.commission: return Icons.palette;
    }
  }

  static BookingType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'order': return BookingType.order;
      case 'foodorder':
      case 'food_order': return BookingType.foodOrder;
      case 'appointment': return BookingType.appointment;
      case 'reservation': return BookingType.reservation;
      case 'roombooking':
      case 'room_booking': return BookingType.roomBooking;
      case 'enrollment': return BookingType.enrollment;
      case 'eventbooking':
      case 'event_booking': return BookingType.eventBooking;
      case 'projectrequest':
      case 'project_request': return BookingType.projectRequest;
      case 'commission': return BookingType.commission;
      default: return BookingType.order;
    }
  }
}

/// Unified booking status for all types
enum BookingStatus {
  pending,        // New, awaiting confirmation
  confirmed,      // Confirmed by business
  inProgress,     // Being processed/prepared
  completed,      // Done
  cancelled,      // Cancelled by either party
  checkedIn,      // Guest has checked in (Hospitality)
  checkedOut,     // Guest has checked out (Hospitality)
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending: return 'Pending';
      case BookingStatus.confirmed: return 'Confirmed';
      case BookingStatus.inProgress: return 'In Progress';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
      case BookingStatus.checkedIn: return 'Checked In';
      case BookingStatus.checkedOut: return 'Checked Out';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending: return const Color(0xFFF59E0B);    // Amber
      case BookingStatus.confirmed: return const Color(0xFF3B82F6);  // Blue
      case BookingStatus.inProgress: return const Color(0xFF8B5CF6); // Purple
      case BookingStatus.completed: return const Color(0xFF22C55E);  // Green
      case BookingStatus.cancelled: return const Color(0xFFEF4444);  // Red
      case BookingStatus.checkedIn: return const Color(0xFF10B981);  // Emerald
      case BookingStatus.checkedOut: return const Color(0xFF6366F1); // Indigo
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatus.pending: return Icons.schedule;
      case BookingStatus.confirmed: return Icons.check_circle;
      case BookingStatus.inProgress: return Icons.sync;
      case BookingStatus.completed: return Icons.task_alt;
      case BookingStatus.cancelled: return Icons.cancel;
      case BookingStatus.checkedIn: return Icons.login;
      case BookingStatus.checkedOut: return Icons.logout;
    }
  }

  static BookingStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending': return BookingStatus.pending;
      case 'confirmed': return BookingStatus.confirmed;
      case 'inprogress':
      case 'in_progress': return BookingStatus.inProgress;
      case 'completed': return BookingStatus.completed;
      case 'cancelled': return BookingStatus.cancelled;
      case 'checkedin':
      case 'checked_in': return BookingStatus.checkedIn;
      case 'checkedout':
      case 'checked_out': return BookingStatus.checkedOut;
      default: return BookingStatus.pending;
    }
  }
}

/// Payment status
enum PaymentStatus {
  pending,
  paid,
  partiallyPaid,
  refunded,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending: return 'Pending';
      case PaymentStatus.paid: return 'Paid';
      case PaymentStatus.partiallyPaid: return 'Partial';
      case PaymentStatus.refunded: return 'Refunded';
    }
  }

  static PaymentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'paid': return PaymentStatus.paid;
      case 'partiallypaid':
      case 'partially_paid': return PaymentStatus.partiallyPaid;
      case 'refunded': return PaymentStatus.refunded;
      default: return PaymentStatus.pending;
    }
  }
}

/// Item in a booking (denormalized)
class BookingItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String? image;
  final String? variant;      // Size, color, etc.
  final String? notes;

  BookingItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.image,
    this.variant,
    this.notes,
  });

  double get total => price * quantity;

  factory BookingItem.fromMap(Map<String, dynamic> map) {
    return BookingItem(
      itemId: map['itemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      image: map['image'],
      variant: map['variant'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image': image,
      'variant': variant,
      'notes': notes,
    };
  }
}

/// Unified Booking Model - Works for ALL transaction types
/// Replaces: ProductOrderModel, FoodOrderModel, AppointmentModel, RoomBookingModel, etc.
class BookingModel {
  final String id;
  final String businessId;

  // Type determines workflow
  final BookingType type;

  // Customer info (denormalized - no extra query needed)
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerPhoto;

  // Items (denormalized - no extra query needed)
  final List<BookingItem> items;

  // Schedule (for appointments, reservations, bookings)
  final DateTime? date;
  final String? startTime;      // '10:00'
  final String? endTime;        // '11:00'
  final DateTime? checkIn;      // For room bookings
  final DateTime? checkOut;     // For room bookings

  // Staff (for appointments)
  final String? staffId;
  final String? staffName;

  // Pricing (pre-calculated)
  final double subtotal;
  final double tax;
  final double discount;
  final double deliveryFee;
  final double total;
  final String currency;

  // Status
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;

  // Notes
  final String? customerNotes;
  final String? businessNotes;
  final String? cancellationReason;

  // Delivery (for orders)
  final String? deliveryAddress;
  final String? deliveryType;   // 'delivery' | 'pickup' | 'dine_in'

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  BookingModel({
    required this.id,
    required this.businessId,
    required this.type,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerPhoto,
    this.items = const [],
    this.date,
    this.startTime,
    this.endTime,
    this.checkIn,
    this.checkOut,
    this.staffId,
    this.staffName,
    this.subtotal = 0,
    this.tax = 0,
    this.discount = 0,
    this.deliveryFee = 0,
    double? total,
    this.currency = 'INR',
    this.status = BookingStatus.pending,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentMethod,
    this.customerNotes,
    this.businessNotes,
    this.cancellationReason,
    this.deliveryAddress,
    this.deliveryType,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
  })  : total = total ?? (subtotal + tax + deliveryFee - discount),
        createdAt = createdAt ?? DateTime.now();

  // === COMPUTED PROPERTIES ===

  /// Formatted total
  String get formattedTotal => CurrencyUtils.format(total, currency);

  /// Formatted subtotal
  String get formattedSubtotal => CurrencyUtils.format(subtotal, currency);

  /// Formatted tax
  String get formattedTax => CurrencyUtils.format(tax, currency);

  /// Formatted discount
  String get formattedDiscount => CurrencyUtils.format(discount, currency);

  /// Formatted delivery fee
  String get formattedDeliveryFee => CurrencyUtils.format(deliveryFee, currency);

  /// Total item count
  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  /// First item (for display)
  BookingItem? get firstItem => items.isNotEmpty ? items.first : null;

  /// Has multiple items
  bool get hasMultipleItems => items.length > 1 || itemCount > 1;

  /// Is active (not completed or cancelled)
  bool get isActive =>
      status != BookingStatus.completed && status != BookingStatus.cancelled;

  /// Can be cancelled
  bool get canCancel =>
      status == BookingStatus.pending || status == BookingStatus.confirmed;

  /// Can be confirmed
  bool get canConfirm => status == BookingStatus.pending;

  /// Can be completed
  bool get canComplete =>
      status == BookingStatus.confirmed || status == BookingStatus.inProgress;

  /// Formatted date
  String get formattedDate {
    if (date == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date!.day} ${months[date!.month - 1]} ${date!.year}';
  }

  /// Formatted time range
  String get formattedTimeRange {
    if (startTime == null) return '';
    if (endTime == null) return startTime!;
    return '$startTime - $endTime';
  }

  /// Formatted stay duration (for room bookings)
  String get formattedStayDuration {
    if (checkIn == null || checkOut == null) return '';
    final nights = checkOut!.difference(checkIn!).inDays;
    return nights == 1 ? '1 Night' : '$nights Nights';
  }

  /// Number of nights (for room bookings)
  int get nights {
    if (checkIn == null || checkOut == null) return 0;
    return checkOut!.difference(checkIn!).inDays;
  }

  /// Display ID (short version)
  String get displayId => '#${id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';

  // === FIRESTORE ===

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel.fromMap(data, doc.id);
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      businessId: map['businessId'] ?? '',
      type: BookingTypeExtension.fromString(map['type']),
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      customerEmail: map['customerEmail'],
      customerPhoto: map['customerPhoto'],
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => BookingItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      date: map['date'] != null
          ? (map['date'] as Timestamp).toDate()
          : null,
      startTime: map['startTime'],
      endTime: map['endTime'],
      checkIn: map['checkIn'] != null
          ? (map['checkIn'] as Timestamp).toDate()
          : null,
      checkOut: map['checkOut'] != null
          ? (map['checkOut'] as Timestamp).toDate()
          : null,
      staffId: map['staffId'],
      staffName: map['staffName'],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'INR',
      status: BookingStatusExtension.fromString(map['status']),
      paymentStatus: PaymentStatusExtension.fromString(map['paymentStatus']),
      paymentMethod: map['paymentMethod'],
      customerNotes: map['customerNotes'],
      businessNotes: map['businessNotes'],
      cancellationReason: map['cancellationReason'],
      deliveryAddress: map['deliveryAddress'],
      deliveryType: map['deliveryType'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'type': type.name,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerPhoto': customerPhoto,
      'items': items.map((i) => i.toMap()).toList(),
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'startTime': startTime,
      'endTime': endTime,
      'checkIn': checkIn != null ? Timestamp.fromDate(checkIn!) : null,
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'staffId': staffId,
      'staffName': staffName,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'total': total,
      'currency': currency,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'paymentMethod': paymentMethod,
      'customerNotes': customerNotes,
      'businessNotes': businessNotes,
      'cancellationReason': cancellationReason,
      'deliveryAddress': deliveryAddress,
      'deliveryType': deliveryType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  BookingModel copyWith({
    String? id,
    String? businessId,
    BookingType? type,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerPhoto,
    List<BookingItem>? items,
    DateTime? date,
    String? startTime,
    String? endTime,
    DateTime? checkIn,
    DateTime? checkOut,
    String? staffId,
    String? staffName,
    double? subtotal,
    double? tax,
    double? discount,
    double? deliveryFee,
    double? total,
    String? currency,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    String? customerNotes,
    String? businessNotes,
    String? cancellationReason,
    String? deliveryAddress,
    String? deliveryType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhoto: customerPhoto ?? this.customerPhoto,
      items: items ?? this.items,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerNotes: customerNotes ?? this.customerNotes,
      businessNotes: businessNotes ?? this.businessNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryType: deliveryType ?? this.deliveryType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Create minimal version for user's booking list
  Map<String, dynamic> toUserBooking(String businessName, String? businessLogo) {
    return {
      'businessId': businessId,
      'bookingId': id,
      'businessName': businessName,
      'businessLogo': businessLogo,
      'type': type.name,
      'status': status.name,
      'total': total,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'itemName': firstItem?.name,
      'itemImage': firstItem?.image,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Booking filters
class BookingFilters {
  static const List<String> statusFilters = [
    'All',
    'Pending',
    'Confirmed',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  static BookingStatus? getStatusFromFilter(String filter) {
    switch (filter) {
      case 'Pending': return BookingStatus.pending;
      case 'Confirmed': return BookingStatus.confirmed;
      case 'In Progress': return BookingStatus.inProgress;
      case 'Completed': return BookingStatus.completed;
      case 'Cancelled': return BookingStatus.cancelled;
      default: return null;
    }
  }
}
