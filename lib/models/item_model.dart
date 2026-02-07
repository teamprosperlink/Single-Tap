import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/currency_utils.dart';

/// Item types - determines UI behavior and fields shown
enum ItemType {
  product,    // Retail, Grocery
  service,    // Healthcare, Beauty, Home Services, etc.
  room,       // Hospitality
  menu,       // Food & Beverage
  course,     // Education
  property,   // Real Estate
  package,    // Travel, Events
  vehicle,    // Automotive, Transportation
}

extension ItemTypeExtension on ItemType {
  String get displayName {
    switch (this) {
      case ItemType.product: return 'Product';
      case ItemType.service: return 'Service';
      case ItemType.room: return 'Room';
      case ItemType.menu: return 'Menu Item';
      case ItemType.course: return 'Course';
      case ItemType.property: return 'Property';
      case ItemType.package: return 'Package';
      case ItemType.vehicle: return 'Vehicle';
    }
  }

  static ItemType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'product': return ItemType.product;
      case 'service': return ItemType.service;
      case 'room': return ItemType.room;
      case 'menu': return ItemType.menu;
      case 'course': return ItemType.course;
      case 'property': return ItemType.property;
      case 'package': return ItemType.package;
      case 'vehicle': return ItemType.vehicle;
      default: return ItemType.product;
    }
  }
}

/// Pricing type for items
enum PriceType {
  fixed,
  hourly,
  daily,
  weekly,
  monthly,
  negotiable,
  free,
  startingFrom;

  String get displayName {
    switch (this) {
      case PriceType.fixed: return 'Fixed';
      case PriceType.hourly: return '/hr';
      case PriceType.daily: return '/day';
      case PriceType.weekly: return '/week';
      case PriceType.monthly: return '/month';
      case PriceType.negotiable: return 'Negotiable';
      case PriceType.free: return 'Free';
      case PriceType.startingFrom: return 'From';
    }
  }

  static PriceType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'hourly': return PriceType.hourly;
      case 'daily': return PriceType.daily;
      case 'weekly': return PriceType.weekly;
      case 'monthly': return PriceType.monthly;
      case 'negotiable': return PriceType.negotiable;
      case 'free': return PriceType.free;
      case 'startingfrom':
      case 'starting_from': return PriceType.startingFrom;
      default: return PriceType.fixed;
    }
  }
}

/// Unified Item Model - Works for ALL business categories
/// Replaces: ProductModel, ServiceModel, RoomModel, MenuItemModel, etc.
class ItemModel {
  final String id;
  final String businessId;

  // Type determines UI behavior
  final ItemType type;

  // Common fields (ALL types)
  final String name;
  final String description;
  final String category;        // User's custom category

  // Pricing
  final double price;
  final double? originalPrice;  // For discount display
  final String currency;
  final PriceType priceType;

  // Media
  final String? image;          // Primary image
  final List<String> images;    // Additional images (max 5)

  // Status
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;

  // Inventory (Products only)
  final int stock;              // -1 = unlimited
  final int lowStockAt;

  // Duration (Services, Courses) - in minutes
  final int duration;

  // Capacity (Rooms, Courses, Events)
  final int capacity;

  // Flexible attributes (category-specific data)
  final Map<String, dynamic> attributes;

  // Search & Tags
  final List<String> tags;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  ItemModel({
    required this.id,
    required this.businessId,
    required this.type,
    required this.name,
    this.description = '',
    this.category = '',
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.priceType = PriceType.fixed,
    this.image,
    this.images = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.stock = -1,
    this.lowStockAt = 5,
    this.duration = 0,
    this.capacity = 0,
    this.attributes = const {},
    this.tags = const [],
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // === COMPUTED PROPERTIES ===

  /// Formatted price with currency
  String get formattedPrice {
    if (priceType == PriceType.free) return 'Free';
    if (priceType == PriceType.negotiable) return 'Negotiable';

    final formatted = CurrencyUtils.format(price, currency);

    switch (priceType) {
      case PriceType.hourly: return '$formatted/hr';
      case PriceType.daily: return '$formatted/day';
      case PriceType.weekly: return '$formatted/week';
      case PriceType.monthly: return '$formatted/month';
      case PriceType.startingFrom: return 'From $formatted';
      default: return formatted;
    }
  }

  /// Formatted original price (for strikethrough)
  String? get formattedOriginalPrice {
    if (originalPrice == null || originalPrice! <= price) return null;
    return CurrencyUtils.format(originalPrice!, currency);
  }

  /// Discount percentage
  int? get discountPercent {
    return CurrencyUtils.calculateDiscountPercent(price, originalPrice);
  }

  /// Has discount
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;

  /// Is in stock (for products)
  bool get inStock => stock == -1 || stock > 0;

  /// Is low stock
  bool get isLowStock => stock != -1 && stock > 0 && stock <= lowStockAt;

  /// Formatted duration
  String get formattedDuration {
    if (duration <= 0) return '';
    if (duration < 60) return '$duration min';
    final hours = duration ~/ 60;
    final mins = duration % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  // === ATTRIBUTE HELPERS ===

  /// Get attribute value with type safety
  T? getAttribute<T>(String key) {
    final value = attributes[key];
    if (value is T) return value;
    return null;
  }

  /// Common attribute getters

  // Room attributes
  String? get bedType => getAttribute<String>('bedType');
  List<String> get amenities => List<String>.from(attributes['amenities'] ?? []);
  int? get roomSize => getAttribute<int>('roomSize');
  String? get view => getAttribute<String>('view');

  // Product attributes
  List<Map<String, dynamic>> get variants =>
      List<Map<String, dynamic>>.from(attributes['variants'] ?? []);
  String? get weight => getAttribute<String>('weight');
  String? get material => getAttribute<String>('material');
  List<String> get colors => List<String>.from(attributes['colors'] ?? []);
  List<String> get sizes => List<String>.from(attributes['sizes'] ?? []);

  // Service attributes
  bool get staffRequired => getAttribute<bool>('staffRequired') ?? false;

  // Menu attributes
  String? get foodType => getAttribute<String>('foodType'); // veg/non-veg
  String? get spiceLevel => getAttribute<String>('spiceLevel');
  List<String> get allergens => List<String>.from(attributes['allergens'] ?? []);
  bool get isVeg => foodType?.toLowerCase() == 'veg';

  // Course attributes
  List<String> get syllabus => List<String>.from(attributes['syllabus'] ?? []);
  String? get level => getAttribute<String>('level'); // beginner/intermediate/advanced
  bool get hasCertificate => getAttribute<bool>('hasCertificate') ?? false;

  // Property attributes
  int? get bedrooms => getAttribute<int>('bedrooms');
  int? get bathrooms => getAttribute<int>('bathrooms');
  int? get sqft => getAttribute<int>('sqft');
  String? get propertyType => getAttribute<String>('propertyType'); // rent/sale
  bool? get furnished => getAttribute<bool>('furnished');

  // Package attributes
  List<String> get inclusions => List<String>.from(attributes['inclusions'] ?? []);
  List<String> get exclusions => List<String>.from(attributes['exclusions'] ?? []);
  List<Map<String, dynamic>> get itinerary =>
      List<Map<String, dynamic>>.from(attributes['itinerary'] ?? []);

  // === FIRESTORE ===

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel.fromMap(data, doc.id);
  }

  factory ItemModel.fromMap(Map<String, dynamic> map, String id) {
    return ItemModel(
      id: id,
      businessId: map['businessId'] ?? '',
      type: ItemTypeExtension.fromString(map['type']),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      priceType: PriceType.fromString(map['priceType']),
      image: map['image'],
      images: List<String>.from(map['images'] ?? []),
      isActive: map['isActive'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      sortOrder: map['sortOrder'] ?? 0,
      stock: map['stock'] ?? -1,
      lowStockAt: map['lowStockAt'] ?? 5,
      duration: map['duration'] ?? 0,
      capacity: map['capacity'] ?? 0,
      attributes: Map<String, dynamic>.from(map['attributes'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
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
      'businessId': businessId,
      'type': type.name,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'priceType': priceType.name,
      'image': image,
      'images': images,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'sortOrder': sortOrder,
      'stock': stock,
      'lowStockAt': lowStockAt,
      'duration': duration,
      'capacity': capacity,
      'attributes': attributes,
      'tags': tags,
      'searchTerms': _generateSearchTerms(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Generate search terms for this item
  List<String> _generateSearchTerms() {
    final terms = <String>{};

    // Add name words
    for (final word in name.toLowerCase().split(' ')) {
      if (word.length > 2) terms.add(word);
    }

    // Add category
    if (category.isNotEmpty) {
      terms.add(category.toLowerCase());
    }

    // Add tags
    for (final tag in tags) {
      terms.add(tag.toLowerCase());
    }

    return terms.toList();
  }

  ItemModel copyWith({
    String? id,
    String? businessId,
    ItemType? type,
    String? name,
    String? description,
    String? category,
    double? price,
    double? originalPrice,
    String? currency,
    PriceType? priceType,
    String? image,
    List<String>? images,
    bool? isActive,
    bool? isFeatured,
    int? sortOrder,
    int? stock,
    int? lowStockAt,
    int? duration,
    int? capacity,
    Map<String, dynamic>? attributes,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      currency: currency ?? this.currency,
      priceType: priceType ?? this.priceType,
      image: image ?? this.image,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
      stock: stock ?? this.stock,
      lowStockAt: lowStockAt ?? this.lowStockAt,
      duration: duration ?? this.duration,
      capacity: capacity ?? this.capacity,
      attributes: attributes ?? this.attributes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a minimal version for denormalization (featured items)
  Map<String, dynamic> toMinimal() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image': image,
      'type': type.name,
    };
  }
}

/// Item category for organizing items
class ItemCategory {
  final String id;
  final String businessId;
  final String name;
  final String? image;
  final int itemCount;
  final int sortOrder;
  final bool isActive;

  ItemCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.image,
    this.itemCount = 0,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ItemCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemCategory(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      image: data['image'],
      itemCount: data['itemCount'] ?? 0,
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'image': image,
      'itemCount': itemCount,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}
