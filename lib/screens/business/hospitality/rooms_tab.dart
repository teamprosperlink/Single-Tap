import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/room_model.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';
import 'room_form_screen.dart';

/// Tab for managing hotel/hospitality rooms
class RoomsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const RoomsTab({
    super.key,
    required this.business,
    this.onRefresh,
  });

  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab> {
  final BusinessService _businessService = BusinessService();
  String _filterType = 'all'; // all, available, unavailable
  bool _hasRooms = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDarkMode),
            _buildFilterChips(isDarkMode),
            Expanded(child: _buildRoomsList(isDarkMode)),
          ],
        ),
      ),
      floatingActionButton: _hasRooms
          ? FloatingActionButton.extended(
              onPressed: _addRoom,
              backgroundColor: const Color(0xFF00D67D),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Room',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.hotel_rounded,
              color: Color(0xFF00D67D),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rooms',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Manage your room inventory',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _FilterChip(
            label: 'All Rooms',
            isSelected: _filterType == 'all',
            onTap: () => setState(() => _filterType = 'all'),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Available',
            isSelected: _filterType == 'available',
            onTap: () => setState(() => _filterType = 'available'),
            isDarkMode: isDarkMode,
            iconData: Icons.check_circle_outline,
            iconColor: Colors.green,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Unavailable',
            isSelected: _filterType == 'unavailable',
            onTap: () => setState(() => _filterType = 'unavailable'),
            isDarkMode: isDarkMode,
            iconData: Icons.cancel_outlined,
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(bool isDarkMode) {
    return StreamBuilder<List<RoomModel>>(
      stream: _businessService.watchRooms(widget.business.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading rooms',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final allRooms = snapshot.data ?? [];
        final rooms = _filterRooms(allRooms);

        // Update state to control FAB visibility
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_hasRooms != allRooms.isNotEmpty) {
            setState(() {
              _hasRooms = allRooms.isNotEmpty;
            });
          }
        });

        if (rooms.isEmpty) {
          return _buildEmptyState(isDarkMode, allRooms.isEmpty);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _RoomCard(
              room: room,
              isDarkMode: isDarkMode,
              onTap: () => _editRoom(room),
              onToggleAvailability: () => _toggleAvailability(room),
              onDelete: () => _deleteRoom(room),
            );
          },
        );
      },
    );
  }

  List<RoomModel> _filterRooms(List<RoomModel> rooms) {
    switch (_filterType) {
      case 'available':
        return rooms.where((r) => r.isAvailable && r.availableRooms > 0).toList();
      case 'unavailable':
        return rooms.where((r) => !r.isAvailable || r.availableRooms == 0).toList();
      default:
        return rooms;
    }
  }

  Widget _buildEmptyState(bool isDarkMode, bool noRoomsAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              noRoomsAtAll ? Icons.hotel_rounded : Icons.search_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            noRoomsAtAll ? 'No Rooms Yet' : 'No Matching Rooms',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noRoomsAtAll
                ? 'Add your first room to get started'
                : 'Try a different filter',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          if (noRoomsAtAll) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
            ),
          ],
        ],
      ),
    );
  }

  void _addRoom() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          businessId: widget.business.id,
          onSaved: () {
            Navigator.pop(context);
            widget.onRefresh?.call();
          },
        ),
      ),
    );
  }

  void _editRoom(RoomModel room) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          businessId: widget.business.id,
          room: room,
          onSaved: () {
            Navigator.pop(context);
            widget.onRefresh?.call();
          },
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(RoomModel room) async {
    HapticFeedback.lightImpact();
    final updatedRoom = room.copyWith(isAvailable: !room.isAvailable);
    await _businessService.updateRoom(widget.business.id, room.id, updatedRoom);
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete "${room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _businessService.deleteRoom(widget.business.id, room.id);
      widget.onRefresh?.call();
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final IconData? iconData;
  final Color? iconColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.iconData,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(
                iconData,
                size: 16,
                color: isSelected ? Colors.white : iconColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDelete;

  const _RoomCard({
    required this.room,
    required this.isDarkMode,
    required this.onTap,
    required this.onToggleAvailability,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Room image or placeholder
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        image: room.images.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(room.images.first),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: room.images.isEmpty
                          ? const Icon(
                              Icons.hotel,
                              color: Color(0xFF00D67D),
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              _buildAvailabilityBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room.type.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            room.formattedPrice,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D67D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Room details
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.people_outline,
                      '${room.capacity} Guests',
                      isDarkMode,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.door_front_door_outlined,
                      '${room.availableRooms}/${room.totalRooms} Available',
                      isDarkMode,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.bed_outlined,
                      room.bedType.displayName,
                      isDarkMode,
                    ),
                  ],
                ),
                if (room.amenities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: room.amenities.take(4).map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                // Action buttons - Compact size
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onToggleAvailability,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: room.isAvailable ? Colors.orange : Colors.green,
                          side: BorderSide(
                            color: room.isAvailable ? Colors.orange : Colors.green,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          room.isAvailable ? Icons.visibility_off : Icons.visibility,
                          size: 16,
                        ),
                        label: Text(
                          room.isAvailable ? 'Hide' : 'Show',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D67D),
                          side: const BorderSide(color: Color(0xFF00D67D)),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red[400],
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    final isAvailable = room.isAvailable && room.availableRooms > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAvailable ? 'Available' : 'Unavailable',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAvailable ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
