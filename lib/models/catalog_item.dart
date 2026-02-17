import 'package:cloud_firestore/cloud_firestore.dart';

enum CatalogItemType {
  product,
  service;

  static CatalogItemType fromString(String? value) {
    if (value == 'service') return CatalogItemType.service;
    return CatalogItemType.product;
  }
}

class CatalogItem {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double? price;
  final String currency;
  final String? imageUrl;
  final CatalogItemType type;
  final bool isAvailable;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogItem({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.price,
    this.currency = 'INR',
    this.imageUrl,
    this.type = CatalogItemType.product,
    this.isAvailable = true,
    this.viewCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get formattedPrice {
    if (price == null) return 'Contact for price';
    final symbol = currency == 'USD'
        ? '\$'
        : currency == 'INR'
            ? '\u20B9'
            : currency;
    return '$symbol${price!.toStringAsFixed(price! == price!.roundToDouble() ? 0 : 2)}';
  }

  factory CatalogItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CatalogItem.fromMap(data, doc.id);
  }

  factory CatalogItem.fromMap(Map<String, dynamic> map, String id) {
    return CatalogItem(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      price: map['price']?.toDouble(),
      currency: map['currency'] ?? 'INR',
      imageUrl: map['imageUrl'],
      type: CatalogItemType.fromString(map['type']),
      isAvailable: map['isAvailable'] ?? true,
      viewCount: map['viewCount'] ?? 0,
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
      'userId': userId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'imageUrl': imageUrl,
      'type': type.name,
      'isAvailable': isAvailable,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CatalogItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? imageUrl,
    CatalogItemType? type,
    bool? isAvailable,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      isAvailable: isAvailable ?? this.isAvailable,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
