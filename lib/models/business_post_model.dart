import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/currency_utils.dart';

/// Types of business posts
enum PostType {
  update,      // General announcements
  product,     // Product listings
  service,     // Service offerings
  promotion,   // Discount/special offers
  portfolio,   // Work samples/gallery
  location,    // Location updates
  hours,       // Operating hours updates
}

/// Business post model for sharing updates, products, services, etc.
class BusinessPost {
  final String id;
  final String businessId;
  final String businessName;
  final String? businessLogo;
  final PostType type;
  final String? title;
  final String description;
  final List<String> images;
  final List<String> videos;
  final double? price;
  final double? originalPrice; // For showing discounts
  final String? currency;
  final String? pricingType; // Fixed, Hourly, Per Unit, Starting From, Negotiable
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? promoCode;
  final int? discountPercent;
  final bool isActive;
  final bool isPinned;
  final int views;
  final int likes;
  final int shares;
  final int comments;
  final List<String> tags;
  final String? category;
  final String? externalLink;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessPost({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.businessLogo,
    required this.type,
    this.title,
    required this.description,
    this.images = const [],
    this.videos = const [],
    this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.pricingType,
    this.validFrom,
    this.validUntil,
    this.promoCode,
    this.discountPercent,
    this.isActive = true,
    this.isPinned = false,
    this.views = 0,
    this.likes = 0,
    this.shares = 0,
    this.comments = 0,
    this.tags = const [],
    this.category,
    this.externalLink,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory BusinessPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessPost.fromMap(data, doc.id);
  }

  factory BusinessPost.fromMap(Map<String, dynamic> map, String id) {
    return BusinessPost(
      id: id,
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessLogo: map['businessLogo'],
      type: _parsePostType(map['type']),
      title: map['title'],
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      videos: List<String>.from(map['videos'] ?? []),
      price: map['price']?.toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      pricingType: map['pricingType'],
      validFrom: map['validFrom'] != null
          ? (map['validFrom'] as Timestamp).toDate()
          : null,
      validUntil: map['validUntil'] != null
          ? (map['validUntil'] as Timestamp).toDate()
          : null,
      promoCode: map['promoCode'],
      discountPercent: map['discountPercent'],
      isActive: map['isActive'] ?? true,
      isPinned: map['isPinned'] ?? false,
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      shares: map['shares'] ?? 0,
      comments: map['comments'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'],
      externalLink: map['externalLink'],
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
      'businessName': businessName,
      'businessLogo': businessLogo,
      'type': type.name,
      'title': title,
      'description': description,
      'images': images,
      'videos': videos,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'pricingType': pricingType,
      'validFrom': validFrom != null ? Timestamp.fromDate(validFrom!) : null,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'promoCode': promoCode,
      'discountPercent': discountPercent,
      'isActive': isActive,
      'isPinned': isPinned,
      'views': views,
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'tags': tags,
      'category': category,
      'externalLink': externalLink,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BusinessPost copyWith({
    String? id,
    String? businessId,
    String? businessName,
    String? businessLogo,
    PostType? type,
    String? title,
    String? description,
    List<String>? images,
    List<String>? videos,
    double? price,
    double? originalPrice,
    String? currency,
    String? pricingType,
    DateTime? validFrom,
    DateTime? validUntil,
    String? promoCode,
    int? discountPercent,
    bool? isActive,
    bool? isPinned,
    int? views,
    int? likes,
    int? shares,
    int? comments,
    List<String>? tags,
    String? category,
    String? externalLink,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessPost(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessLogo: businessLogo ?? this.businessLogo,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      currency: currency ?? this.currency,
      pricingType: pricingType ?? this.pricingType,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      promoCode: promoCode ?? this.promoCode,
      discountPercent: discountPercent ?? this.discountPercent,
      isActive: isActive ?? this.isActive,
      isPinned: isPinned ?? this.isPinned,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      comments: comments ?? this.comments,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      externalLink: externalLink ?? this.externalLink,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static PostType _parsePostType(String? type) {
    switch (type) {
      case 'update':
        return PostType.update;
      case 'product':
        return PostType.product;
      case 'service':
        return PostType.service;
      case 'promotion':
        return PostType.promotion;
      case 'portfolio':
        return PostType.portfolio;
      case 'location':
        return PostType.location;
      case 'hours':
        return PostType.hours;
      default:
        return PostType.update;
    }
  }

  /// Get the icon for this post type
  String get typeIcon {
    switch (type) {
      case PostType.update:
        return '\u{1F4E2}'; // Megaphone
      case PostType.product:
        return '\u{1F6CD}'; // Shopping bags
      case PostType.service:
        return '\u{1F527}'; // Wrench
      case PostType.promotion:
        return '\u{1F381}'; // Gift
      case PostType.portfolio:
        return '\u{1F4F8}'; // Camera
      case PostType.location:
        return '\u{1F4CD}'; // Pin
      case PostType.hours:
        return '\u{23F0}'; // Alarm clock
    }
  }

  /// Get the display name for this post type
  String get typeName {
    switch (type) {
      case PostType.update:
        return 'Update';
      case PostType.product:
        return 'Product';
      case PostType.service:
        return 'Service';
      case PostType.promotion:
        return 'Promotion';
      case PostType.portfolio:
        return 'Portfolio';
      case PostType.location:
        return 'Location';
      case PostType.hours:
        return 'Hours Update';
    }
  }

  /// Check if the promotion is currently valid
  bool get isPromotionValid {
    if (type != PostType.promotion) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return isActive;
  }

  /// Get formatted price string
  String get formattedPrice {
    if (price == null) return 'Contact for price';
    return CurrencyUtils.format(price!, currency ?? 'INR');
  }

  /// Get formatted original price (for showing discount)
  String get formattedOriginalPrice {
    if (originalPrice == null) return '';
    return CurrencyUtils.format(originalPrice!, currency ?? 'INR');
  }

  /// Check if there's a discount
  bool get hasDiscount => originalPrice != null && price != null && originalPrice! > price!;

  /// Calculate discount percentage
  int get calculatedDiscountPercent {
    if (!hasDiscount) return discountPercent ?? 0;
    return CurrencyUtils.calculateDiscountPercent(price!, originalPrice) ?? 0;
  }

  /// Check if post has media
  bool get hasMedia => images.isNotEmpty || videos.isNotEmpty;

  /// Get total media count
  int get mediaCount => images.length + videos.length;
}

/// Available pricing types for products/services
class PricingTypes {
  static const String fixed = 'Fixed';
  static const String hourly = 'Hourly';
  static const String perUnit = 'Per Unit';
  static const String startingFrom = 'Starting From';
  static const String negotiable = 'Negotiable';
  static const String free = 'Free';

  static const List<String> all = [
    fixed,
    hourly,
    perUnit,
    startingFrom,
    negotiable,
    free,
  ];
}
