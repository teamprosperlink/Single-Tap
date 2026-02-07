import 'package:cloud_firestore/cloud_firestore.dart';
import 'base/priceable_mixin.dart';
import 'base/base_category_model.dart';
import 'base/base_order_item.dart';

/// Menu category model for food & beverage businesses
class MenuCategoryModel extends BaseCategoryModel with CategoryFirestoreMixin {
  @override
  final String id;
  @override
  final String businessId;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? image;
  @override
  final int sortOrder;
  @override
  final bool isActive;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  MenuCategoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.image,
    this.sortOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MenuCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuCategoryModel.fromMap(data, doc.id);
  }

  factory MenuCategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return MenuCategoryModel(
      id: id,
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      image: map['image'],
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return baseCategoryToMap();
  }

  @override
  MenuCategoryModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? image,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuCategoryModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Menu item model for food & beverage businesses
class MenuItemModel with Priceable {
  final String id;
  final String categoryId;
  final String businessId;
  final String name;
  final String? description;
  @override
  final double price;
  @override
  final double? originalPrice; // For discounts
  @override
  final String currency;
  final String? image;
  final FoodType foodType;
  final SpiceLevel? spiceLevel;
  final bool isAvailable;
  final bool isFeatured;
  final bool isBestSeller;
  final List<String> tags;
  final List<String> allergens;
  final int? calories;
  final int? preparationTime; // in minutes
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItemModel({
    required this.id,
    required this.categoryId,
    required this.businessId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.image,
    this.foodType = FoodType.nonVeg,
    this.spiceLevel,
    this.isAvailable = true,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.tags = const [],
    this.allergens = const [],
    this.calories,
    this.preparationTime,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Backward compatibility getters
  String? get imageUrl => image;
  String get category => categoryId;
  int get orderCount => 0; // Default order count (can be tracked separately)

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItemModel.fromMap(data, doc.id);
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map, String id) {
    return MenuItemModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      image: map['image'],
      foodType: FoodType.fromString(map['foodType']) ?? FoodType.nonVeg,
      spiceLevel: SpiceLevel.fromString(map['spiceLevel']),
      isAvailable: map['isAvailable'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      isBestSeller: map['isBestSeller'] ?? false,
      tags: List<String>.from(map['tags'] ?? []),
      allergens: List<String>.from(map['allergens'] ?? []),
      calories: map['calories'],
      preparationTime: map['preparationTime'],
      sortOrder: map['sortOrder'] ?? 0,
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
      'categoryId': categoryId,
      'businessId': businessId,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'image': image,
      'foodType': foodType.value,
      'spiceLevel': spiceLevel?.value,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isBestSeller': isBestSeller,
      'tags': tags,
      'allergens': allergens,
      'calories': calories,
      'preparationTime': preparationTime,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? categoryId,
    String? businessId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? currency,
    String? image,
    FoodType? foodType,
    SpiceLevel? spiceLevel,
    bool? isAvailable,
    bool? isFeatured,
    bool? isBestSeller,
    List<String>? tags,
    List<String>? allergens,
    int? calories,
    int? preparationTime,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      currency: currency ?? this.currency,
      image: image ?? this.image,
      foodType: foodType ?? this.foodType,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      tags: tags ?? this.tags,
      allergens: allergens ?? this.allergens,
      calories: calories ?? this.calories,
      preparationTime: preparationTime ?? this.preparationTime,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Pricing methods (formattedPrice, formattedOriginalPrice, discountPercent, hasDiscount)
  // are provided by the Priceable mixin
}

/// Food type (veg/non-veg)
enum FoodType {
  veg('Vegetarian', 'veg', '🟢'),
  nonVeg('Non-Vegetarian', 'non_veg', '🔴'),
  egg('Egg', 'egg', '🟡'),
  vegan('Vegan', 'vegan', '🟢');

  final String displayName;
  final String value;
  final String icon;

  const FoodType(this.displayName, this.value, this.icon);

  static FoodType? fromString(String? value) {
    if (value == null) return null;
    for (final type in FoodType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Spice level
enum SpiceLevel {
  mild('Mild', 'mild'),
  medium('Medium', 'medium'),
  hot('Hot', 'hot'),
  extraHot('Extra Hot', 'extra_hot');

  final String displayName;
  final String value;

  const SpiceLevel(this.displayName, this.value);

  static SpiceLevel? fromString(String? value) {
    if (value == null) return null;
    for (final level in SpiceLevel.values) {
      if (level.value == value) return level;
    }
    return null;
  }
}

/// Common allergens
class FoodAllergens {
  static const List<String> all = [
    'Gluten',
    'Dairy',
    'Eggs',
    'Peanuts',
    'Tree Nuts',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
  ];
}

/// Common menu item tags
class MenuTags {
  static const List<String> all = [
    'Spicy',
    'Popular',
    "Chef's Special",
    'New',
    'Recommended',
    'Healthy',
    'Low Calorie',
    'Gluten Free',
    'Sugar Free',
  ];
}

/// Default menu categories
class DefaultMenuCategories {
  static const List<String> restaurant = [
    'Starters',
    'Soups & Salads',
    'Main Course',
    'Rice & Biryani',
    'Breads',
    'Desserts',
    'Beverages',
  ];

  static const List<String> cafe = [
    'Coffee',
    'Tea',
    'Smoothies',
    'Snacks',
    'Sandwiches',
    'Desserts',
    'Specials',
  ];

  static const List<String> bakery = [
    'Cakes',
    'Pastries',
    'Cookies',
    'Breads',
    'Muffins',
    'Special Orders',
  ];

  static const List<String> bar = [
    'Cocktails',
    'Mocktails',
    'Beer',
    'Wine',
    'Whiskey',
    'Starters',
    'Mains',
  ];
}

/// Food order model
class FoodOrderModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerAddress;
  final List<FoodOrderItem> items;
  final double subtotal;
  final double tax;
  final double deliveryFee;
  final double total;
  final String currency;
  final OrderType orderType;
  final FoodOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  FoodOrderModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    this.tax = 0,
    this.deliveryFee = 0,
    required this.total,
    this.currency = 'INR',
    this.orderType = OrderType.dineIn,
    this.status = FoodOrderStatus.pending,
    this.notes,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FoodOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodOrderModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerAddress: data['customerAddress'],
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => FoodOrderItem.fromMap(item))
              .toList() ??
          [],
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      deliveryFee: (data['deliveryFee'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'INR',
      orderType: OrderType.fromString(data['orderType']) ?? OrderType.dineIn,
      status: FoodOrderStatus.fromString(data['status']) ?? FoodOrderStatus.pending,
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'deliveryFee': deliveryFee,
      'total': total,
      'currency': currency,
      'orderType': orderType.value,
      'status': status.value,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  /// Get total items count
  int get totalItems => items.fold(0, (total, item) => total + item.quantity);
}

/// Order item for food orders
class FoodOrderItem extends BaseOrderItem with OrderItemSerializationMixin {
  /// Menu item ID (maps to itemId in base class)
  final String menuItemId;
  @override
  final String name;
  @override
  final double price;
  @override
  final int quantity;
  final String? notes;

  /// Get itemId for base class compatibility
  @override
  String get itemId => menuItemId;

  /// Alias for subtotal
  double get total => subtotal;

  FoodOrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
  });

  factory FoodOrderItem.fromMap(Map<String, dynamic> map) {
    return FoodOrderItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      notes: map['notes'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final baseMap = baseOrderItemToMap();
    return {
      ...baseMap,
      'menuItemId': menuItemId,
      'notes': notes,
    };
  }

  @override
  FoodOrderItem copyWithQuantity(int newQuantity) {
    return FoodOrderItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: newQuantity,
      notes: notes,
    );
  }
}

/// Order type
enum OrderType {
  dineIn('Dine In', 'dine_in'),
  takeaway('Takeaway', 'takeaway'),
  delivery('Delivery', 'delivery');

  final String displayName;
  final String value;

  const OrderType(this.displayName, this.value);

  static OrderType? fromString(String? value) {
    if (value == null) return null;
    for (final type in OrderType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Food order status
enum FoodOrderStatus {
  pending('Pending', 'pending'),
  confirmed('Confirmed', 'confirmed'),
  preparing('Preparing', 'preparing'),
  ready('Ready', 'ready'),
  outForDelivery('Out for Delivery', 'out_for_delivery'),
  delivered('Delivered', 'delivered'),
  completed('Completed', 'completed'),
  cancelled('Cancelled', 'cancelled');

  final String displayName;
  final String value;

  const FoodOrderStatus(this.displayName, this.value);

  static FoodOrderStatus? fromString(String? value) {
    if (value == null) return null;
    for (final status in FoodOrderStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
