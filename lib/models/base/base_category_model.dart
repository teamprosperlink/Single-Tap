import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class for business category models (e.g., MenuCategoryModel, ProductCategoryModel).
abstract class BaseCategoryModel {
  String get id;
  String get businessId;
  String get name;
  String? get description;
  String? get image;
  int get sortOrder;
  bool get isActive;
  DateTime get createdAt;
  DateTime? get updatedAt;

  Map<String, dynamic> toMap();

  BaseCategoryModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? image,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  });

  /// Serializes the base category fields to a map for Firestore.
  Map<String, dynamic> baseCategoryToMap() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'image': image,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// Mixin for Firestore serialization helpers on category models.
mixin CategoryFirestoreMixin {}
