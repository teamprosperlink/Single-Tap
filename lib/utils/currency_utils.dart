import 'package:intl/intl.dart';

/// Utility class for currency formatting and price calculations.
class CurrencyUtils {
  CurrencyUtils._();

  static final Map<String, NumberFormat> _formatters = {};

  /// Format a currency value with the appropriate symbol and formatting.
  static String format(double amount, String currency) {
    final upper = currency.toUpperCase();
    final formatter = _formatters.putIfAbsent(upper, () {
      switch (upper) {
        case 'INR':
          return NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 2);
        case 'USD':
          return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
        case 'EUR':
          return NumberFormat.currency(locale: 'de_DE', symbol: '\u20AC', decimalDigits: 2);
        case 'GBP':
          return NumberFormat.currency(locale: 'en_GB', symbol: '\u00A3', decimalDigits: 2);
        case 'JPY':
          return NumberFormat.currency(locale: 'ja_JP', symbol: '\u00A5', decimalDigits: 0);
        case 'AED':
          return NumberFormat.currency(locale: 'ar_AE', symbol: 'AED ', decimalDigits: 2);
        default:
          return NumberFormat.currency(symbol: '$upper ', decimalDigits: 2);
      }
    });
    return formatter.format(amount);
  }

  /// Calculate discount percentage between price and original price.
  /// Returns null if no valid discount exists.
  static int? calculateDiscountPercent(double price, double? originalPrice) {
    if (originalPrice == null || originalPrice <= price || originalPrice <= 0) {
      return null;
    }
    final percent = ((originalPrice - price) / originalPrice * 100).round();
    return percent > 0 ? percent : null;
  }
}
