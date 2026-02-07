import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../res/config/app_colors.dart';
import '../../utils/currency_utils.dart';

/// Reusable price display widget with discount support.
/// Consolidates duplicate price display implementations across business screens.
class PriceDisplay extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final String currency;
  final double fontSize;
  final double? originalFontSize;
  final FontWeight fontWeight;
  final Color? priceColor;
  final Color? originalPriceColor;
  final Color? discountBadgeColor;
  final bool showDiscountBadge;
  final bool showCurrencySymbol;
  final MainAxisAlignment alignment;
  final CrossAxisAlignment crossAlignment;

  const PriceDisplay({
    super.key,
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.fontSize = 16,
    this.originalFontSize,
    this.fontWeight = FontWeight.bold,
    this.priceColor,
    this.originalPriceColor,
    this.discountBadgeColor,
    this.showDiscountBadge = true,
    this.showCurrencySymbol = true,
    this.alignment = MainAxisAlignment.start,
    this.crossAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultPriceColor = priceColor ?? (isDarkMode ? AppColors.textPrimaryDark : Colors.black87);
    final defaultOriginalColor = originalPriceColor ?? (isDarkMode ? AppColors.textPrimaryDark38 : Colors.grey);
    final defaultDiscountColor = discountBadgeColor ?? AppTheme.primaryGreen;

    final hasDiscount = originalPrice != null && originalPrice! > price;
    final discountPercent = hasDiscount
        ? (((originalPrice! - price) / originalPrice!) * 100).round()
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: crossAlignment,
      children: [
        // Current price
        Text(
          _formatPrice(price),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: defaultPriceColor,
          ),
        ),

        // Original price (strikethrough)
        if (hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            _formatPrice(originalPrice!),
            style: TextStyle(
              fontSize: originalFontSize ?? (fontSize * 0.85),
              fontWeight: FontWeight.normal,
              color: defaultOriginalColor,
              decoration: TextDecoration.lineThrough,
              decorationColor: defaultOriginalColor,
            ),
          ),
        ],

        // Discount badge
        if (hasDiscount && showDiscountBadge && discountPercent != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: defaultDiscountColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-$discountPercent%',
              style: TextStyle(
                fontSize: fontSize * 0.7,
                fontWeight: FontWeight.w600,
                color: defaultDiscountColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatPrice(double amount) {
    if (!showCurrencySymbol) {
      return amount.truncateToDouble() == amount
          ? amount.toInt().toString()
          : amount.toStringAsFixed(2);
    }
    return CurrencyUtils.format(amount, currency);
  }
}

/// Compact price display for list items
class CompactPriceDisplay extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final String currency;
  final Color? color;

  const CompactPriceDisplay({
    super.key,
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(
      price: price,
      originalPrice: originalPrice,
      currency: currency,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      priceColor: color,
      showDiscountBadge: false,
    );
  }
}

/// Large price display for detail screens
class LargePriceDisplay extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final String currency;
  final String? priceLabel;

  const LargePriceDisplay({
    super.key,
    required this.price,
    this.originalPrice,
    this.currency = 'INR',
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (priceLabel != null) ...[
          Text(
            priceLabel!,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
        ],
        PriceDisplay(
          price: price,
          originalPrice: originalPrice,
          currency: currency,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          showDiscountBadge: true,
        ),
      ],
    );
  }
}

/// Price range display (for rooms, services with variable pricing)
class PriceRangeDisplay extends StatelessWidget {
  final double minPrice;
  final double maxPrice;
  final String currency;
  final double fontSize;
  final Color? color;
  final String? suffix;

  const PriceRangeDisplay({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    this.currency = 'INR',
    this.fontSize = 16,
    this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = color ?? (isDarkMode ? AppColors.textPrimaryDark : Colors.black87);

    final isSamePrice = minPrice == maxPrice;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isSamePrice
              ? _formatPrice(minPrice)
              : '${_formatPrice(minPrice)} - ${_formatPrice(maxPrice)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        if (suffix != null) ...[
          Text(
            suffix!,
            style: TextStyle(
              fontSize: fontSize * 0.8,
              color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  String _formatPrice(double amount) => CurrencyUtils.format(amount, currency);
}

/// Free badge for zero-price items
class FreeBadge extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const FreeBadge({
    super.key,
    this.fontSize = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'FREE',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}

/// Price with unit display (e.g., "₹500/night", "₹100/kg")
class PriceWithUnit extends StatelessWidget {
  final double price;
  final String unit;
  final String currency;
  final double fontSize;
  final Color? color;

  const PriceWithUnit({
    super.key,
    required this.price,
    required this.unit,
    this.currency = 'INR',
    this.fontSize = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = color ?? (isDarkMode ? AppColors.textPrimaryDark : Colors.black87);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: _formatPrice(price),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          TextSpan(
            text: '/$unit',
            style: TextStyle(
              fontSize: fontSize * 0.75,
              fontWeight: FontWeight.normal,
              color: isDarkMode ? AppColors.textPrimaryDark54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double amount) => CurrencyUtils.format(amount, currency);
}
