import 'package:cloud_firestore/cloud_firestore.dart';

/// Inquiry status enum
enum InquiryStatus {
  pending,
  responded,
  negotiating,
  accepted,
  declined,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case InquiryStatus.pending:
        return 'Pending';
      case InquiryStatus.responded:
        return 'Responded';
      case InquiryStatus.negotiating:
        return 'Negotiating';
      case InquiryStatus.accepted:
        return 'Accepted';
      case InquiryStatus.declined:
        return 'Declined';
      case InquiryStatus.completed:
        return 'Completed';
      case InquiryStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get color {
    switch (this) {
      case InquiryStatus.pending:
        return '#FFA500'; // Orange
      case InquiryStatus.responded:
        return '#2196F3'; // Blue
      case InquiryStatus.negotiating:
        return '#9C27B0'; // Purple
      case InquiryStatus.accepted:
        return '#4CAF50'; // Green
      case InquiryStatus.declined:
        return '#F44336'; // Red
      case InquiryStatus.completed:
        return '#00D67D'; // App green
      case InquiryStatus.cancelled:
        return '#9E9E9E'; // Grey
    }
  }

  static InquiryStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'responded':
        return InquiryStatus.responded;
      case 'negotiating':
        return InquiryStatus.negotiating;
      case 'accepted':
        return InquiryStatus.accepted;
      case 'declined':
        return InquiryStatus.declined;
      case 'completed':
        return InquiryStatus.completed;
      case 'cancelled':
        return InquiryStatus.cancelled;
      default:
        return InquiryStatus.pending;
    }
  }
}

/// Inquiry model for professional accounts
class InquiryModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientPhoto;
  final String? clientEmail;
  final String professionalId;
  final String professionalName;
  final String? serviceId;
  final String? serviceName;

  // Inquiry Details
  final String message;
  final String? projectDescription;
  final String? budget;
  final String? timeline;
  final List<String> attachments;

  // Status
  final InquiryStatus status;

  // Response from professional
  final String? response;
  final String? quotedPrice;
  final String? estimatedDelivery;

  // Conversation thread
  final List<InquiryMessage> messages;

  // Metadata
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final DateTime lastActivityAt;

  // Flags
  final bool isRead;
  final bool isArchived;

  InquiryModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhoto,
    this.clientEmail,
    required this.professionalId,
    required this.professionalName,
    this.serviceId,
    this.serviceName,
    required this.message,
    this.projectDescription,
    this.budget,
    this.timeline,
    this.attachments = const [],
    this.status = InquiryStatus.pending,
    this.response,
    this.quotedPrice,
    this.estimatedDelivery,
    this.messages = const [],
    DateTime? createdAt,
    this.respondedAt,
    this.completedAt,
    DateTime? lastActivityAt,
    this.isRead = false,
    this.isArchived = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActivityAt = lastActivityAt ?? createdAt ?? DateTime.now();

  /// Create from Firestore document
  factory InquiryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InquiryModel.fromMap(data, doc.id);
  }

  /// Create from map with ID
  factory InquiryModel.fromMap(Map<String, dynamic> map, String id) {
    return InquiryModel(
      id: id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? 'Unknown',
      clientPhoto: map['clientPhoto'],
      clientEmail: map['clientEmail'],
      professionalId: map['professionalId'] ?? '',
      professionalName: map['professionalName'] ?? '',
      serviceId: map['serviceId'],
      serviceName: map['serviceName'],
      message: map['message'] ?? '',
      projectDescription: map['projectDescription'],
      budget: map['budget'],
      timeline: map['timeline'],
      attachments: List<String>.from(map['attachments'] ?? []),
      status: InquiryStatus.fromString(map['status']),
      response: map['response'],
      quotedPrice: map['quotedPrice'],
      estimatedDelivery: map['estimatedDelivery'],
      messages: (map['messages'] as List?)
              ?.map((m) => InquiryMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      lastActivityAt: map['lastActivityAt'] != null
          ? (map['lastActivityAt'] as Timestamp).toDate()
          : null,
      isRead: map['isRead'] ?? false,
      isArchived: map['isArchived'] ?? false,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhoto': clientPhoto,
      'clientEmail': clientEmail,
      'professionalId': professionalId,
      'professionalName': professionalName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'message': message,
      'projectDescription': projectDescription,
      'budget': budget,
      'timeline': timeline,
      'attachments': attachments,
      'status': status.name,
      'response': response,
      'quotedPrice': quotedPrice,
      'estimatedDelivery': estimatedDelivery,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'isRead': isRead,
      'isArchived': isArchived,
    };
  }

  /// Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Check if inquiry needs response
  bool get needsResponse => status == InquiryStatus.pending && !isRead;

  /// Check if inquiry is active
  bool get isActive =>
      status != InquiryStatus.completed &&
      status != InquiryStatus.cancelled &&
      status != InquiryStatus.declined;

  /// Create a copy with updated fields
  InquiryModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientPhoto,
    String? clientEmail,
    String? professionalId,
    String? professionalName,
    String? serviceId,
    String? serviceName,
    String? message,
    String? projectDescription,
    String? budget,
    String? timeline,
    List<String>? attachments,
    InquiryStatus? status,
    String? response,
    String? quotedPrice,
    String? estimatedDelivery,
    List<InquiryMessage>? messages,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? completedAt,
    DateTime? lastActivityAt,
    bool? isRead,
    bool? isArchived,
  }) {
    return InquiryModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhoto: clientPhoto ?? this.clientPhoto,
      clientEmail: clientEmail ?? this.clientEmail,
      professionalId: professionalId ?? this.professionalId,
      professionalName: professionalName ?? this.professionalName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      message: message ?? this.message,
      projectDescription: projectDescription ?? this.projectDescription,
      budget: budget ?? this.budget,
      timeline: timeline ?? this.timeline,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      response: response ?? this.response,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      completedAt: completedAt ?? this.completedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

/// Individual message in inquiry thread
class InquiryMessage {
  final String senderId;
  final String senderName;
  final String message;
  final List<String> attachments;
  final DateTime timestamp;
  final bool isFromProfessional;

  InquiryMessage({
    required this.senderId,
    required this.senderName,
    required this.message,
    this.attachments = const [],
    DateTime? timestamp,
    required this.isFromProfessional,
  }) : timestamp = timestamp ?? DateTime.now();

  factory InquiryMessage.fromMap(Map<String, dynamic> map) {
    return InquiryMessage(
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isFromProfessional: map['isFromProfessional'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'attachments': attachments,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFromProfessional': isFromProfessional,
    };
  }
}

/// Budget range options
class BudgetOptions {
  static const List<String> ranges = [
    'Under \$100',
    '\$100 - \$500',
    '\$500 - \$1,000',
    '\$1,000 - \$5,000',
    '\$5,000 - \$10,000',
    '\$10,000+',
    'Custom Budget',
    'Negotiable',
  ];
}

/// Timeline options
class TimelineOptions {
  static const List<String> options = [
    'ASAP',
    'Within 1 week',
    'Within 2 weeks',
    'Within 1 month',
    '1-3 months',
    '3+ months',
    'Flexible',
    'Ongoing project',
  ];
}
