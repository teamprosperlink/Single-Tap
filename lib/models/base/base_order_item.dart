/// Base class for order item models (e.g., FoodOrderItem, ProductOrderItem).
abstract class BaseOrderItem {
  String get itemId;
  String get name;
  double get price;
  int get quantity;

  /// Subtotal for this order item.
  double get subtotal => price * quantity;

  Map<String, dynamic> toMap();

  /// Create a copy with a new quantity.
  BaseOrderItem copyWithQuantity(int newQuantity);

  /// Serializes the base order item fields to a map.
  Map<String, dynamic> baseOrderItemToMap() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

/// Mixin for order item serialization helpers.
mixin OrderItemSerializationMixin {}
