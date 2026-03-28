import 'package:flutter/material.dart';
import '../config/app_theme.dart';
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
    final cardColor = AppTheme.cardColor(isDark);
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
                  if (item.allImages.isNotEmpty)
                    Image.network(
                      item.allImages.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(isDark),
                    )
                  else
                    _placeholder(isDark),
                  // Multi-image indicator
                  if (item.allImages.length > 1)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              '${item.allImages.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          ? AppTheme.primaryAction
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
        return AppTheme.primaryAction.withValues(alpha: 0.9);
      case CatalogItemType.product:
        return AppTheme.secondaryAccent.withValues(alpha: 0.9);
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
