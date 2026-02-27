import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/catalog_item.dart';
import '../../../models/user_profile.dart';
import '../../../services/catalog_service.dart';
import 'booking_request_screen.dart';

class CatalogItemDetail extends StatelessWidget {
  final CatalogItem item;
  final UserProfile businessUser;
  final VoidCallback? onEnquire;

  const CatalogItemDetail({
    super.key,
    required this.item,
    required this.businessUser,
    this.onEnquire,
  });

  static void show(
    BuildContext context, {
    required CatalogItem item,
    required UserProfile businessUser,
    VoidCallback? onEnquire,
  }) {
    // Increment view count
    CatalogService().incrementItemView(item.userId, item.id);
    CatalogService().incrementBusinessStat(item.userId, 'catalogViews');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => CatalogItemDetail(
          item: item,
          businessUser: businessUser,
          onEnquire: onEnquire,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholder(isDark),
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _placeholder(isDark),
                    ),
                  ),

                const SizedBox(height: 16),

                // Type chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.type == CatalogItemType.service
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                            : const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.type == CatalogItemType.service
                            ? 'Service'
                            : 'Product',
                        style: TextStyle(
                          color: item.type == CatalogItemType.service
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!item.isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Currently Unavailable',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Name
                Text(
                  item.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                // Price
                Text(
                  item.formattedPrice,
                  style: TextStyle(
                    color: item.price != null
                        ? const Color(0xFF22C55E)
                        : subtitleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // Description
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    item.description!,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Business info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            businessUser.profileImageUrl != null
                                ? NetworkImage(
                                    businessUser.profileImageUrl!)
                                : null,
                        child: businessUser.profileImageUrl == null
                            ? Text(
                                businessUser.name.isNotEmpty
                                    ? businessUser.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessUser.businessProfile?.businessName ??
                                  businessUser.name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (businessUser.businessProfile?.softLabel !=
                                null)
                              Text(
                                businessUser
                                    .businessProfile!.softLabel!,
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Book Now (services) or Enquire (products)
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: item.isAvailable
                              ? () {
                                  if (item.type == CatalogItemType.service) {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingRequestScreen(
                                          item: item,
                                          businessUser: businessUser,
                                        ),
                                      ),
                                    );
                                  } else {
                                    onEnquire?.call();
                                  }
                                }
                              : null,
                          icon: Icon(
                            item.type == CatalogItemType.service
                                ? Icons.calendar_month_outlined
                                : Icons.chat_outlined,
                            size: 20,
                          ),
                          label: Text(
                            item.type == CatalogItemType.service
                                ? 'Book Now'
                                : 'Enquire',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.type == CatalogItemType.service
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE0E0E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    // Call button
                    if (businessUser.businessProfile?.contactPhone !=
                        null) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            final phone = businessUser
                                .businessProfile!.contactPhone!;
                            launchUrl(Uri.parse('tel:$phone'));
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black12,
                            ),
                          ),
                          child: Icon(Icons.phone_outlined,
                              color: textColor, size: 20),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          item.type == CatalogItemType.service
              ? Icons.home_repair_service_outlined
              : Icons.shopping_bag_outlined,
          size: 48,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
