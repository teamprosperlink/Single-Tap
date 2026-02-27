import 'package:flutter/material.dart';
import '../models/catalog_item.dart';

class CatalogCardWidget extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showAvailability;
  final bool compact;

  const CatalogCardWidget({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.showAvailability = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: compact ? 150 : null,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            AspectRatio(
              aspectRatio: compact ? 1.2 : 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(isDark),
                    )
                  else
                    _placeholder(isDark),
                  // Availability badge
                  if (showAvailability && !item.isAvailable)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Type badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _badgeColor(item.type),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _badgeLabel(item.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact && item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    item.formattedPrice,
                    style: TextStyle(
                      color: item.price != null
                          ? const Color(0xFF22C55E)
                          : subtitleColor,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(CatalogItemType type) {
    switch (type) {
      case CatalogItemType.service:
        return const Color(0xFF3B82F6).withValues(alpha: 0.9);
      case CatalogItemType.product:
        return const Color(0xFF22C55E).withValues(alpha: 0.9);
    }
  }

  String _badgeLabel(CatalogItemType type) {
    switch (type) {
      case CatalogItemType.service:
        return 'Service';
      case CatalogItemType.product:
        return 'Product';
    }
  }

  IconData _placeholderIcon(CatalogItemType type) {
    switch (type) {
      case CatalogItemType.service:
        return Icons.build_outlined;
      case CatalogItemType.product:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          _placeholderIcon(item.type),
          size: compact ? 28 : 40,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
