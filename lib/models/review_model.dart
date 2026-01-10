import 'package:cloud_firestore/cloud_firestore.dart';

/// Review model for professional accounts
class ReviewModel {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerPhoto;
  final String professionalId;
  final String? serviceId;
  final String? serviceName;

  // Rating
  final double rating; // 1-5 stars
  final Map<String, double>? categoryRatings; // Communication, Quality, Value

  // Content
  final String reviewText;
  final List<String> images;

  // Response from professional
  final String? professionalResponse;
  final DateTime? responseDate;

  // Verification
  final bool isVerifiedPurchase;

  // Status
  final bool isVisible;
  final bool isFlagged;

  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerPhoto,
    required this.professionalId,
    this.serviceId,
    this.serviceName,
    required this.rating,
    this.categoryRatings,
    required this.reviewText,
    this.images = const [],
    this.professionalResponse,
    this.responseDate,
    this.isVerifiedPurchase = false,
    this.isVisible = true,
    this.isFlagged = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Firestore document
  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel.fromMap(data, doc.id);
  }

  /// Create from map with ID
  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? 'Anonymous',
      reviewerPhoto: map['reviewerPhoto'],
      professionalId: map['professionalId'] ?? '',
      serviceId: map['serviceId'],
      serviceName: map['serviceName'],
      rating: (map['rating'] ?? 5.0).toDouble(),
      categoryRatings: map['categoryRatings'] != null
          ? Map<String, double>.from(
              (map['categoryRatings'] as Map).map(
                (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : null,
      reviewText: map['reviewText'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      professionalResponse: map['professionalResponse'],
      responseDate: map['responseDate'] != null
          ? (map['responseDate'] as Timestamp).toDate()
          : null,
      isVerifiedPurchase: map['isVerifiedPurchase'] ?? false,
      isVisible: map['isVisible'] ?? true,
      isFlagged: map['isFlagged'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerPhoto': reviewerPhoto,
      'professionalId': professionalId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'rating': rating,
      'categoryRatings': categoryRatings,
      'reviewText': reviewText,
      'images': images,
      'professionalResponse': professionalResponse,
      'responseDate':
          responseDate != null ? Timestamp.fromDate(responseDate!) : null,
      'isVerifiedPurchase': isVerifiedPurchase,
      'isVisible': isVisible,
      'isFlagged': isFlagged,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else {
      return '${(diff.inDays / 365).floor()} years ago';
    }
  }

  /// Create a copy with updated fields
  ReviewModel copyWith({
    String? id,
    String? reviewerId,
    String? reviewerName,
    String? reviewerPhoto,
    String? professionalId,
    String? serviceId,
    String? serviceName,
    double? rating,
    Map<String, double>? categoryRatings,
    String? reviewText,
    List<String>? images,
    String? professionalResponse,
    DateTime? responseDate,
    bool? isVerifiedPurchase,
    bool? isVisible,
    bool? isFlagged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerPhoto: reviewerPhoto ?? this.reviewerPhoto,
      professionalId: professionalId ?? this.professionalId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      rating: rating ?? this.rating,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      reviewText: reviewText ?? this.reviewText,
      images: images ?? this.images,
      professionalResponse: professionalResponse ?? this.professionalResponse,
      responseDate: responseDate ?? this.responseDate,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      isVisible: isVisible ?? this.isVisible,
      isFlagged: isFlagged ?? this.isFlagged,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Rating summary for a professional
class RatingSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> distribution; // 5: 85, 4: 32, etc.

  RatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.distribution,
  });

  factory RatingSummary.empty() {
    return RatingSummary(
      averageRating: 0,
      totalReviews: 0,
      distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    );
  }

  factory RatingSummary.fromMap(Map<String, dynamic> map) {
    return RatingSummary(
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      distribution: Map<int, int>.from(
        (map['distribution'] as Map? ?? {}).map(
          (key, value) => MapEntry(int.parse(key.toString()), value as int),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'distribution': distribution.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  /// Get percentage for a rating
  double getPercentage(int rating) {
    if (totalReviews == 0) return 0;
    return ((distribution[rating] ?? 0) / totalReviews) * 100;
  }
}
