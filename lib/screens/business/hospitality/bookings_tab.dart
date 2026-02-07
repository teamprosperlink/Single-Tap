import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/room_model.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';

/// Tab for viewing and managing room bookings
class BookingsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const BookingsTab({
    super.key,
    required this.business,
    this.onRefresh,
  });

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  final BusinessService _businessService = BusinessService();
  String _filterStatus = 'all'; // all, pending, confirmed, checked_in, completed, cancelled

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
            Expanded(child: _buildBookingsList(isDarkMode)),
          ],
        ),
      ),
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
              Icons.calendar_month_rounded,
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
                  'Bookings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'View and manage reservations',
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
            label: 'All',
            isSelected: _filterStatus == 'all',
            onTap: () => setState(() => _filterStatus = 'all'),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pending',
            isSelected: _filterStatus == 'pending',
            onTap: () => setState(() => _filterStatus = 'pending'),
            isDarkMode: isDarkMode,
            iconData: Icons.schedule,
            iconColor: Colors.orange,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Confirmed',
            isSelected: _filterStatus == 'confirmed',
            onTap: () => setState(() => _filterStatus = 'confirmed'),
            isDarkMode: isDarkMode,
            iconData: Icons.check_circle_outline,
            iconColor: Colors.blue,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Checked In',
            isSelected: _filterStatus == 'checked_in',
            onTap: () => setState(() => _filterStatus = 'checked_in'),
            isDarkMode: isDarkMode,
            iconData: Icons.login,
            iconColor: Colors.green,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed',
            isSelected: _filterStatus == 'completed',
            onTap: () => setState(() => _filterStatus = 'completed'),
            isDarkMode: isDarkMode,
            iconData: Icons.done_all,
            iconColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(bool isDarkMode) {
    return StreamBuilder<List<RoomBookingModel>>(
      stream: _businessService.watchRoomBookings(widget.business.id),
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
                  'Error loading bookings',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final allBookings = snapshot.data ?? [];
        final bookings = _filterBookings(allBookings);

        if (bookings.isEmpty) {
          return _buildEmptyState(isDarkMode, allBookings.isEmpty);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _BookingCard(
              booking: booking,
              isDarkMode: isDarkMode,
              onStatusChange: (status) => _updateBookingStatus(booking, status),
            );
          },
        );
      },
    );
  }

  List<RoomBookingModel> _filterBookings(List<RoomBookingModel> bookings) {
    if (_filterStatus == 'all') return bookings;
    final status = BookingStatus.fromString(_filterStatus);
    if (status == null) return bookings;
    return bookings.where((b) => b.status == status).toList();
  }

  Widget _buildEmptyState(bool isDarkMode, bool noBookingsAtAll) {
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
              noBookingsAtAll ? Icons.calendar_today_outlined : Icons.search_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            noBookingsAtAll ? 'No Bookings Yet' : 'No Matching Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              noBookingsAtAll
                  ? 'Bookings will appear here when guests make reservations'
                  : 'Try a different filter to find bookings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBookingStatus(RoomBookingModel booking, BookingStatus status) async {
    try {
      await _businessService.updateRoomBookingStatus(
        widget.business.id,
        booking.id,
        status,
      );
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

class _BookingCard extends StatelessWidget {
  final RoomBookingModel booking;
  final bool isDarkMode;
  final Function(BookingStatus) onStatusChange;

  const _BookingCard({
    required this.booking,
    required this.isDarkMode,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.guestName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (booking.guestPhone != null)
                        Text(
                          booking.guestPhone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),
            // Room and dates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.hotel,
                        size: 18,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.roomName ?? 'Room',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${booking.guests} guest${booking.guests > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check-in',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                            Text(
                              dateFormat.format(booking.checkIn),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: isDarkMode ? Colors.white38 : Colors.grey[400],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Check-out',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                            Text(
                              dateFormat.format(booking.checkOut),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Total and nights
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${booking.nights} night${booking.nights > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                Text(
                  booking.formattedTotal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D67D),
                  ),
                ),
              ],
            ),
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons based on status
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;

    switch (booking.status) {
      case BookingStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case BookingStatus.confirmed:
        color = Colors.blue;
        label = 'Confirmed';
        break;
      case BookingStatus.checkedIn:
        color = Colors.green;
        label = 'Checked In';
        break;
      case BookingStatus.checkedOut:
        color = Colors.purple;
        label = 'Checked Out';
        break;
      case BookingStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
      case BookingStatus.noShow:
        color = Colors.grey;
        label = 'No Show';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (booking.status) {
      case BookingStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onStatusChange(BookingStatus.cancelled),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => onStatusChange(BookingStatus.confirmed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        );
      case BookingStatus.confirmed:
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(BookingStatus.checkedIn),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Check In'),
        );
      case BookingStatus.checkedIn:
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(BookingStatus.checkedOut),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Check Out'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
