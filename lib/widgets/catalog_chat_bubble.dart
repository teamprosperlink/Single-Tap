import 'package:flutter/material.dart';

class CatalogChatBubble extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final String? text;
  final bool isMine;
  final VoidCallback? onViewItem;

  const CatalogChatBubble({
    super.key,
    required this.metadata,
    this.text,
    required this.isMine,
    this.onViewItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemName = metadata['catalogItemName'] as String? ?? 'Item';
    final itemPrice = metadata['catalogItemPrice'];
    final itemCurrency = metadata['catalogItemCurrency'] as String? ?? 'INR';
    final itemImage = metadata['catalogItemImage'] as String?;

    final priceText = itemPrice != null
        ? _formatPrice(itemPrice.toDouble(), itemCurrency)
        : 'Contact for price';

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Rich card
        GestureDetector(
          onTap: onViewItem,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item image
                if (itemImage != null && itemImage.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      itemImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(isDark),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _imagePlaceholder(isDark),
                  ),
                // Item details
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: TextStyle(
                          color: itemPrice != null
                              ? const Color(0xFF22C55E)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.black.withValues(alpha: 0.5)),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'View Item',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Text message below
        if (text != null && text!.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }

  Widget _imagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 32,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  String _formatPrice(double price, String currency) {
    final symbol = currency == 'USD'
        ? '\$'
        : currency == 'INR'
            ? '\u20B9'
            : currency;
    return '$symbol${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';
  }
}
