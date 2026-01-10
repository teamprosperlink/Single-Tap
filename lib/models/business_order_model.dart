import 'package:cloud_firestore/cloud_firestore.dart';

/// Order status enum
enum OrderStatus {
  newOrder,     // Just received
  pending,      // Waiting for business to accept
  accepted,     // Confirmed by business
  inProgress,   // Work started
  completed,    // Delivered/finished
  cancelled,    // Cancelled by either party
  reviewed,     // Customer left feedback
}

/// Business order model for tracking customer orders
class BusinessOrder {
  final String id;
  final String orderId; // Display ID: ORD-2025-XXXXX
  final String businessId;
  final String businessName;

  // Customer info
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerPhoto;
  final String? customerAddress;

  // Order details
  final String? serviceId;
  final String serviceName;
  final String? serviceDescription;
  final String? serviceImage;
  final int quantity;
  final double price;
  final double? discount;
  final double totalAmount;
  final String currency;

  // Status and tracking
  final OrderStatus status;
  final String? notes;
  final String? customerNotes;
  final String? cancellationReason;
  final String? cancelledBy; // 'customer' or 'business'

  // Scheduling
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final DateTime? completedDate;

  // Payment
  final String? paymentMethod;
  final String? paymentStatus; // pending, paid, refunded
  final String? transactionId;

  // Rating
  final double? rating;
  final String? review;
  final DateTime? reviewedAt;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessOrder({
    required this.id,
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerPhoto,
    this.customerAddress,
    this.serviceId,
    required this.serviceName,
    this.serviceDescription,
    this.serviceImage,
    this.quantity = 1,
    required this.price,
    this.discount,
    double? totalAmount,
    this.currency = 'INR',
    this.status = OrderStatus.newOrder,
    this.notes,
    this.customerNotes,
    this.cancellationReason,
    this.cancelledBy,
    this.scheduledDate,
    this.scheduledTime,
    this.completedDate,
    this.paymentMethod,
    this.paymentStatus,
    this.transactionId,
    this.rating,
    this.review,
    this.reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : totalAmount = totalAmount ?? (price * quantity) - (discount ?? 0),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory BusinessOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessOrder.fromMap(data, doc.id);
  }

  factory BusinessOrder.fromMap(Map<String, dynamic> map, String id) {
    return BusinessOrder(
      id: id,
      orderId: map['orderId'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      customerEmail: map['customerEmail'],
      customerPhoto: map['customerPhoto'],
      customerAddress: map['customerAddress'],
      serviceId: map['serviceId'],
      serviceName: map['serviceName'] ?? '',
      serviceDescription: map['serviceDescription'],
      serviceImage: map['serviceImage'],
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      discount: map['discount']?.toDouble(),
      totalAmount: map['totalAmount']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      status: _parseStatus(map['status']),
      notes: map['notes'],
      customerNotes: map['customerNotes'],
      cancellationReason: map['cancellationReason'],
      cancelledBy: map['cancelledBy'],
      scheduledDate: map['scheduledDate'] != null
          ? (map['scheduledDate'] as Timestamp).toDate()
          : null,
      scheduledTime: map['scheduledTime'],
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      paymentMethod: map['paymentMethod'],
      paymentStatus: map['paymentStatus'],
      transactionId: map['transactionId'],
      rating: map['rating']?.toDouble(),
      review: map['review'],
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
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
      'orderId': orderId,
      'businessId': businessId,
      'businessName': businessName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerPhoto': customerPhoto,
      'customerAddress': customerAddress,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceDescription': serviceDescription,
      'serviceImage': serviceImage,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status.name,
      'notes': notes,
      'customerNotes': customerNotes,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'scheduledTime': scheduledTime,
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionId': transactionId,
      'rating': rating,
      'review': review,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BusinessOrder copyWith({
    String? id,
    String? orderId,
    String? businessId,
    String? businessName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerPhoto,
    String? customerAddress,
    String? serviceId,
    String? serviceName,
    String? serviceDescription,
    String? serviceImage,
    int? quantity,
    double? price,
    double? discount,
    double? totalAmount,
    String? currency,
    OrderStatus? status,
    String? notes,
    String? customerNotes,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? scheduledDate,
    String? scheduledTime,
    DateTime? completedDate,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionId,
    double? rating,
    String? review,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhoto: customerPhoto ?? this.customerPhoto,
      customerAddress: customerAddress ?? this.customerAddress,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      serviceImage: serviceImage ?? this.serviceImage,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      customerNotes: customerNotes ?? this.customerNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completedDate: completedDate ?? this.completedDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionId: transactionId ?? this.transactionId,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
      case 'newOrder':
        return OrderStatus.newOrder;
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'inProgress':
        return OrderStatus.inProgress;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'reviewed':
        return OrderStatus.reviewed;
      default:
        return OrderStatus.newOrder;
    }
  }

  /// Get the display icon for this status
  String get statusIcon {
    switch (status) {
      case OrderStatus.newOrder:
        return '\u{1F4E5}'; // Inbox
      case OrderStatus.pending:
        return '\u{23F3}'; // Hourglass
      case OrderStatus.accepted:
        return '\u{2705}'; // Check mark
      case OrderStatus.inProgress:
        return '\u{1F504}'; // Refresh
      case OrderStatus.completed:
        return '\u{1F4E6}'; // Package
      case OrderStatus.cancelled:
        return '\u{274C}'; // Cross
      case OrderStatus.reviewed:
        return '\u{2B50}'; // Star
    }
  }

  /// Get the display name for this status
  String get statusName {
    switch (status) {
      case OrderStatus.newOrder:
        return 'New';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.reviewed:
        return 'Reviewed';
    }
  }

  /// Get status color (as hex string for flexibility)
  String get statusColorHex {
    switch (status) {
      case OrderStatus.newOrder:
        return '#2196F3'; // Blue
      case OrderStatus.pending:
        return '#FF9800'; // Orange
      case OrderStatus.accepted:
        return '#4CAF50'; // Green
      case OrderStatus.inProgress:
        return '#9C27B0'; // Purple
      case OrderStatus.completed:
        return '#4CAF50'; // Green
      case OrderStatus.cancelled:
        return '#F44336'; // Red
      case OrderStatus.reviewed:
        return '#FFD700'; // Gold
    }
  }

  /// Check if order can be accepted
  bool get canAccept => status == OrderStatus.newOrder || status == OrderStatus.pending;

  /// Check if order can be marked in progress
  bool get canStartProgress => status == OrderStatus.accepted;

  /// Check if order can be completed
  bool get canComplete => status == OrderStatus.inProgress;

  /// Check if order can be cancelled
  bool get canCancel => status != OrderStatus.completed &&
                        status != OrderStatus.cancelled &&
                        status != OrderStatus.reviewed;

  /// Check if order is active (not completed or cancelled)
  bool get isActive => status != OrderStatus.completed &&
                       status != OrderStatus.cancelled &&
                       status != OrderStatus.reviewed;

  /// Get formatted total amount
  String get formattedTotal {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${totalAmount.toStringAsFixed(0)}';
  }

  /// Get formatted price
  String get formattedPrice {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${price.toStringAsFixed(0)}';
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '\u{20B9}';
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u{20AC}';
      case 'GBP':
        return '\u{00A3}';
      default:
        return currency;
    }
  }

  /// Generate a new order ID
  static String generateOrderId() {
    final now = DateTime.now();
    final year = now.year;
    final random = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'ORD-$year-${random.toString().padLeft(5, '0')}';
  }
}

/// Order filter options
class OrderFilters {
  static const String all = 'All';
  static const String newOrders = 'New';
  static const String pending = 'Pending';
  static const String accepted = 'Accepted';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static const List<String> allFilters = [
    all,
    newOrders,
    pending,
    accepted,
    inProgress,
    completed,
    cancelled,
  ];

  static OrderStatus? getStatusFromFilter(String filter) {
    switch (filter) {
      case newOrders:
        return OrderStatus.newOrder;
      case pending:
        return OrderStatus.pending;
      case accepted:
        return OrderStatus.accepted;
      case inProgress:
        return OrderStatus.inProgress;
      case completed:
        return OrderStatus.completed;
      case cancelled:
        return OrderStatus.cancelled;
      default:
        return null;
    }
  }
}
