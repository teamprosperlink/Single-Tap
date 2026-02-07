import 'package:cloud_firestore/cloud_firestore.dart';
import 'base/priceable_mixin.dart';
import 'base/base_category_model.dart';
import 'base/base_order_item.dart';

/// Product category model for retail businesses
class ProductCategoryModel extends BaseCategoryModel with CategoryFirestoreMixin {
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
  final int productCount;
  @override
  final int sortOrder;
  @override
  final bool isActive;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  ProductCategoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.image,
    this.productCount = 0,
    this.sortOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProductCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCategoryModel.fromMap(data, doc.id);
  }

  factory ProductCategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductCategoryModel(
      id: id,
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      image: map['image'],
      productCount: map['productCount'] ?? 0,
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
    final baseMap = baseCategoryToMap();
    baseMap['productCount'] = productCount;
    return baseMap;
  }

  @override
  ProductCategoryModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? image,
    int? productCount,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductCategoryModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      productCount: productCount ?? this.productCount,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Product model for retail businesses
class ProductModel with Priceable {
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
  final List<String> images;
  final int stock;
  final bool inStock;
  final bool trackInventory;
  final String? sku;
  final String? barcode;
  final Map<String, dynamic> attributes; // Color, Size, Material, etc.
  final List<ProductVariant>? variants;
  final double? weight; // in grams
  final String? unit; // pieces, kg, meters, etc.
  final bool isFeatured;
  final bool isActive;
  final List<String> tags;
  final int sortOrder;
  final int viewCount;
  final int soldCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.businessId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.images = const [],
    this.stock = 0,
    this.inStock = true,
    this.trackInventory = false,
    this.sku,
    this.barcode,
    this.attributes = const {},
    this.variants,
    this.weight,
    this.unit,
    this.isFeatured = false,
    this.isActive = true,
    this.tags = const [],
    this.sortOrder = 0,
    this.viewCount = 0,
    this.soldCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Backward compatibility getters
  String get category => categoryId;
  int get salesCount => soldCount;

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel.fromMap(data, doc.id);
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      images: List<String>.from(map['images'] ?? []),
      stock: map['stock'] ?? 0,
      inStock: map['inStock'] ?? true,
      trackInventory: map['trackInventory'] ?? false,
      sku: map['sku'],
      barcode: map['barcode'],
      attributes: Map<String, dynamic>.from(map['attributes'] ?? {}),
      variants: (map['variants'] as List<dynamic>?)
          ?.map((v) => ProductVariant.fromMap(v))
          .toList(),
      weight: map['weight']?.toDouble(),
      unit: map['unit'],
      isFeatured: map['isFeatured'] ?? false,
      isActive: map['isActive'] ?? true,
      tags: List<String>.from(map['tags'] ?? []),
      sortOrder: map['sortOrder'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      soldCount: map['soldCount'] ?? 0,
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
      'images': images,
      'stock': stock,
      'inStock': inStock,
      'trackInventory': trackInventory,
      'sku': sku,
      'barcode': barcode,
      'attributes': attributes,
      'variants': variants?.map((v) => v.toMap()).toList(),
      'weight': weight,
      'unit': unit,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'tags': tags,
      'sortOrder': sortOrder,
      'viewCount': viewCount,
      'soldCount': soldCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ProductModel copyWith({
    String? id,
    String? categoryId,
    String? businessId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? currency,
    List<String>? images,
    int? stock,
    bool? inStock,
    bool? trackInventory,
    String? sku,
    String? barcode,
    Map<String, dynamic>? attributes,
    List<ProductVariant>? variants,
    double? weight,
    String? unit,
    bool? isFeatured,
    bool? isActive,
    List<String>? tags,
    int? sortOrder,
    int? viewCount,
    int? soldCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      currency: currency ?? this.currency,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      inStock: inStock ?? this.inStock,
      trackInventory: trackInventory ?? this.trackInventory,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      attributes: attributes ?? this.attributes,
      variants: variants ?? this.variants,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      sortOrder: sortOrder ?? this.sortOrder,
      viewCount: viewCount ?? this.viewCount,
      soldCount: soldCount ?? this.soldCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Pricing methods (formattedPrice, formattedOriginalPrice, discountPercent, hasDiscount)
  // are provided by the Priceable mixin

  /// Get stock status text
  String get stockStatus {
    if (!trackInventory) return inStock ? 'In Stock' : 'Out of Stock';
    if (stock == 0) return 'Out of Stock';
    if (stock <= 5) return 'Only $stock left';
    return 'In Stock';
  }

  /// Check if has variants
  bool get hasVariants => variants != null && variants!.isNotEmpty;
}

/// Product variant (e.g., different sizes, colors)
class ProductVariant {
  final String id;
  final String name;
  final String? sku;
  final double? price; // Override base price
  final int stock;
  final bool inStock;
  final Map<String, String> options; // e.g., {"color": "Red", "size": "L"}

  ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    this.price,
    this.stock = 0,
    this.inStock = true,
    this.options = const {},
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'],
      price: map['price']?.toDouble(),
      stock: map['stock'] ?? 0,
      inStock: map['inStock'] ?? true,
      options: Map<String, String>.from(map['options'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'stock': stock,
      'inStock': inStock,
      'options': options,
    };
  }
}

/// Common product attributes
class ProductAttributes {
  static const List<String> clothing = [
    'Size',
    'Color',
    'Material',
    'Brand',
    'Gender',
  ];

  static const List<String> electronics = [
    'Brand',
    'Model',
    'Color',
    'Storage',
    'RAM',
    'Screen Size',
    'Warranty',
  ];

  static const List<String> furniture = [
    'Material',
    'Color',
    'Dimensions',
    'Weight',
    'Assembly Required',
  ];

  static const List<String> jewelry = [
    'Material',
    'Purity',
    'Weight',
    'Stone',
    'Design',
  ];
}

/// Product order model
class ProductOrderModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? shippingAddress;
  final List<ProductOrderItem> items;
  final double subtotal;
  final double tax;
  final double shippingFee;
  final double discount;
  final double total;
  final String currency;
  final ProductOrderStatus status;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? trackingNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  ProductOrderModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.shippingAddress,
    required this.items,
    required this.subtotal,
    this.tax = 0,
    this.shippingFee = 0,
    this.discount = 0,
    required this.total,
    this.currency = 'INR',
    this.status = ProductOrderStatus.pending,
    this.paymentMethod,
    this.paymentStatus,
    this.trackingNumber,
    this.notes,
    DateTime? createdAt,
    this.shippedAt,
    this.deliveredAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProductOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductOrderModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerEmail: data['customerEmail'],
      shippingAddress: data['shippingAddress'],
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => ProductOrderItem.fromMap(item))
              .toList() ??
          [],
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      shippingFee: (data['shippingFee'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'INR',
      status: ProductOrderStatus.fromString(data['status']) ??
          ProductOrderStatus.pending,
      paymentMethod: data['paymentMethod'],
      paymentStatus: data['paymentStatus'],
      trackingNumber: data['trackingNumber'],
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      shippedAt: data['shippedAt'] != null
          ? (data['shippedAt'] as Timestamp).toDate()
          : null,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'shippingAddress': shippingAddress,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'shippingFee': shippingFee,
      'discount': discount,
      'total': total,
      'currency': currency,
      'status': status.value,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'trackingNumber': trackingNumber,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'shippedAt': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    };
  }

  /// Get total items count
  int get totalItems => items.fold(0, (total, item) => total + item.quantity);
}

/// Order item for product orders
class ProductOrderItem extends BaseOrderItem with OrderItemSerializationMixin {
  /// Product ID (maps to itemId in base class)
  final String productId;
  final String? variantId;
  @override
  final String name;
  final String? image;
  @override
  final double price;
  @override
  final int quantity;
  final Map<String, String>? options;

  /// Get itemId for base class compatibility
  @override
  String get itemId => productId;

  ProductOrderItem({
    required this.productId,
    this.variantId,
    required this.name,
    this.image,
    required this.price,
    required this.quantity,
    this.options,
  });

  factory ProductOrderItem.fromMap(Map<String, dynamic> map) {
    return ProductOrderItem(
      productId: map['productId'] ?? '',
      variantId: map['variantId'],
      name: map['name'] ?? '',
      image: map['image'],
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      options: map['options'] != null
          ? Map<String, String>.from(map['options'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final baseMap = baseOrderItemToMap();
    return {
      ...baseMap,
      'productId': productId,
      'variantId': variantId,
      'image': image,
      'options': options,
    };
  }

  @override
  ProductOrderItem copyWithQuantity(int newQuantity) {
    return ProductOrderItem(
      productId: productId,
      variantId: variantId,
      name: name,
      image: image,
      price: price,
      quantity: newQuantity,
      options: options,
    );
  }
}

/// Product order status
enum ProductOrderStatus {
  pending('Pending', 'pending'),
  confirmed('Confirmed', 'confirmed'),
  processing('Processing', 'processing'),
  packed('Packed', 'packed'),
  shipped('Shipped', 'shipped'),
  outForDelivery('Out for Delivery', 'out_for_delivery'),
  delivered('Delivered', 'delivered'),
  cancelled('Cancelled', 'cancelled'),
  returned('Returned', 'returned'),
  refunded('Refunded', 'refunded');

  final String displayName;
  final String value;

  const ProductOrderStatus(this.displayName, this.value);

  static ProductOrderStatus? fromString(String? value) {
    if (value == null) return null;
    for (final status in ProductOrderStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// Collection model for organizing products
class ProductCollectionModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? image;
  final List<String> productIds;
  final bool isFeatured;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  ProductCollectionModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.image,
    this.productIds = const [],
    this.isFeatured = false,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProductCollectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCollectionModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      image: data['image'],
      productIds: List<String>.from(data['productIds'] ?? []),
      isFeatured: data['isFeatured'] ?? false,
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'image': image,
      'productIds': productIds,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int get productCount => productIds.length;
}
