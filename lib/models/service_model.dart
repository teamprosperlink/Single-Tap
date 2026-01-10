import 'package:cloud_firestore/cloud_firestore.dart';

/// Pricing type for services
enum PricingType {
  fixed,
  hourly,
  negotiable,
  startingFrom;

  String get displayName {
    switch (this) {
      case PricingType.fixed:
        return 'Fixed Price';
      case PricingType.hourly:
        return 'Per Hour';
      case PricingType.negotiable:
        return 'Negotiable';
      case PricingType.startingFrom:
        return 'Starting From';
    }
  }

  String get shortName {
    switch (this) {
      case PricingType.fixed:
        return 'Fixed';
      case PricingType.hourly:
        return '/hr';
      case PricingType.negotiable:
        return 'Negotiable';
      case PricingType.startingFrom:
        return 'From';
    }
  }

  static PricingType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'hourly':
        return PricingType.hourly;
      case 'negotiable':
        return PricingType.negotiable;
      case 'startingfrom':
      case 'starting_from':
        return PricingType.startingFrom;
      default:
        return PricingType.fixed;
    }
  }
}

/// Service model for professional accounts
class ServiceModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final double? price;
  final PricingType pricingType;
  final String currency;
  final String? deliveryTime;
  final List<String> images;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int views;
  final int inquiries;

  ServiceModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.price,
    this.pricingType = PricingType.fixed,
    this.currency = 'USD',
    this.deliveryTime,
    this.images = const [],
    this.tags = const [],
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.views = 0,
    this.inquiries = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create from Firestore document
  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel.fromMap(data, doc.id);
  }

  /// Create from map with ID
  factory ServiceModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Other',
      price: map['price']?.toDouble(),
      pricingType: PricingType.fromString(map['pricingType']),
      currency: map['currency'] ?? 'USD',
      deliveryTime: map['deliveryTime'],
      images: List<String>.from(map['images'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      views: map['views'] ?? 0,
      inquiries: map['inquiries'] ?? 0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'pricingType': pricingType.name,
      'currency': currency,
      'deliveryTime': deliveryTime,
      'images': images,
      'tags': tags,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'views': views,
      'inquiries': inquiries,
    };
  }

  /// Get formatted price string
  String get formattedPrice {
    if (price == null || pricingType == PricingType.negotiable) {
      return 'Negotiable';
    }

    final priceStr = price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2);
    final currencySymbol = _getCurrencySymbol(currency);

    switch (pricingType) {
      case PricingType.fixed:
        return '$currencySymbol$priceStr';
      case PricingType.hourly:
        return '$currencySymbol$priceStr/hr';
      case PricingType.startingFrom:
        return 'From $currencySymbol$priceStr';
      case PricingType.negotiable:
        return 'Negotiable';
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'JPY':
        return '¥';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      default:
        return '$currency ';
    }
  }

  /// Create a copy with updated fields
  ServiceModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? category,
    double? price,
    PricingType? pricingType,
    String? currency,
    String? deliveryTime,
    List<String>? images,
    List<String>? tags,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? views,
    int? inquiries,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      pricingType: pricingType ?? this.pricingType,
      currency: currency ?? this.currency,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      images: images ?? this.images,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      views: views ?? this.views,
      inquiries: inquiries ?? this.inquiries,
    );
  }
}

/// Service categories
class ServiceCategories {
  static const List<String> all = [
    'Design & Creative',
    'Web Development',
    'Mobile Development',
    'Writing & Content',
    'Marketing & SEO',
    'Video & Animation',
    'Music & Audio',
    'Business & Finance',
    'Legal & Consulting',
    'Engineering & Architecture',
    'Education & Tutoring',
    'Health & Wellness',
    'Photography',
    'Data & Analytics',
    'AI & Machine Learning',
    'Home Services',
    'Events & Entertainment',
    'Other',
  ];

  static const Map<String, String> icons = {
    'Design & Creative': '',
    'Web Development': '',
    'Mobile Development': '',
    'Writing & Content': '',
    'Marketing & SEO': '',
    'Video & Animation': '',
    'Music & Audio': '',
    'Business & Finance': '',
    'Legal & Consulting': '',
    'Engineering & Architecture': '',
    'Education & Tutoring': '',
    'Health & Wellness': '',
    'Photography': '',
    'Data & Analytics': '',
    'AI & Machine Learning': '',
    'Home Services': '',
    'Events & Entertainment': '',
    'Other': '',
  };

  static String getIcon(String category) {
    return icons[category] ?? '';
  }
}

/// Currencies supported
class SupportedCurrencies {
  static const List<Map<String, String>> all = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': '﷼'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
    {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
  ];

  static String getSymbol(String code) {
    final currency = all.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'symbol': code},
    );
    return currency['symbol'] ?? code;
  }
}
