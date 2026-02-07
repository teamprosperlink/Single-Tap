import '../../utils/currency_utils.dart';

/// Mixin that provides pricing functionality to models with price fields.
///
/// Classes using this mixin must implement [price], [originalPrice], and [currency].
mixin Priceable {
  double get price;
  double? get originalPrice;
  String get currency;

  /// Format a price value with the given currency symbol.
  static String formatPrice(double amount, String currency) {
    return CurrencyUtils.format(amount, currency);
  }

  /// Get formatted price string (e.g., "\u20B9999.00").
  String get formattedPrice => CurrencyUtils.format(price, currency);

  /// Get formatted original price for strikethrough display.
  /// Returns null if no discount exists.
  String? get formattedOriginalPrice {
    if (originalPrice == null || originalPrice! <= price) return null;
    return CurrencyUtils.format(originalPrice!, currency);
  }

  /// Whether the item has a discount.
  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price;

  /// Discount percentage (e.g., 25 for 25% off).
  /// Returns null if no discount exists.
  int? get discountPercent =>
      CurrencyUtils.calculateDiscountPercent(price, originalPrice);
}
