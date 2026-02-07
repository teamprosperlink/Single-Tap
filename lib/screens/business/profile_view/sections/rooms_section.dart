import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/room_model.dart';
import '../../../../services/business_service.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying rooms for hotels/hospitality
class RoomsSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final VoidCallback? onBookRoom;

  const RoomsSection({
    super.key,
    required this.businessId,
    required this.config,
    this.onBookRoom,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<RoomModel>>(
      stream: BusinessService().watchRooms(businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(isDarkMode);
        }

        final rooms = snapshot.data ?? [];

        if (rooms.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(isDarkMode),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  return RoomCard(
                    room: rooms[index],
                    config: config,
                    isDarkMode: isDarkMode,
                    onBook: onBookRoom,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.hotel,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Rooms',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: config.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text(
              config.emptyStateIcon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              config.emptyStateMessage,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying a room
class RoomCard extends StatelessWidget {
  final RoomModel room;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onBook;

  const RoomCard({
    super.key,
    required this.room,
    required this.config,
    required this.isDarkMode,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildRoomImage(),
          ),

          // Room details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room name
                  Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Capacity
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.capacity} ${room.capacity == 1 ? 'Guest' : 'Guests'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Amenities
                  if (room.amenities.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: room.amenities.take(3).map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white10 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            amenity,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const Spacer(),

                  // Price and book button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${room.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: config.primaryColor,
                            ),
                          ),
                          Text(
                            'per night',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      if (room.isAvailable && onBook != null)
                        ElevatedButton(
                          onPressed: onBook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: config.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Book',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (!room.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Sold Out',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomImage() {
    final imageUrl = room.images.isNotEmpty ? room.images.first : null;

    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildImagePlaceholder(),
        errorWidget: (context, url, error) => _buildImagePlaceholder(),
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 120,
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.hotel,
          size: 40,
          color: config.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
