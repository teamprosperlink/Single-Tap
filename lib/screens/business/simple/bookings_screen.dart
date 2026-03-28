import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/app_theme.dart';
import '../../../models/booking_model.dart';
import '../../../services/booking_service.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bookingService = BookingService();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.backgroundColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Bookings')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Bookings',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryAction,
          unselectedLabelColor:
              isDark ? Colors.white60 : Colors.black54,
          indicatorColor: AppTheme.primaryAction,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(
            filter: BookingStatus.pending,
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.hourglass_empty_rounded,
            emptyTitle: 'No pending bookings',
            emptySubtitle: 'New booking requests will appear here',
          ),
          _buildBookingList(
            filter: BookingStatus.confirmed,
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.check_circle_outline,
            emptyTitle: 'No confirmed bookings',
            emptySubtitle: 'Confirmed bookings will appear here',
          ),
          _buildBookingList(
            filters: [BookingStatus.completed, BookingStatus.cancelled],
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.history_rounded,
            emptyTitle: 'No booking history',
            emptySubtitle: 'Completed and cancelled bookings appear here',
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList({
    BookingStatus? filter,
    List<BookingStatus>? filters,
    required bool isDark,
    required Color textColor,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.streamOwnerBookings(
        _userId!,
        filter: filter,
        filters: filters,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyState(
              isDark, textColor, emptyIcon, emptyTitle, emptySubtitle);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _buildBookingCard(bookings[index], isDark, textColor),
        );
      },
    );
  }

  Widget _buildBookingCard(
      BookingModel booking, bool isDark, Color textColor) {
    final cardBg = AppTheme.cardColor(isDark);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: customer name + status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryAction.withValues(alpha: 0.12),
                child: Text(
                  booking.customerName.isNotEmpty
                      ? booking.customerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryAction,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.customerName,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (booking.customerPhone != null)
                      Text(booking.customerPhone!,
                          style:
                              TextStyle(color: subtitleColor, fontSize: 12)),
                  ],
                ),
              ),
              _statusChip(booking.status),
            ],
          ),

          const SizedBox(height: 12),

          // Service + date/time
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.build_outlined,
                        size: 16, color: subtitleColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.serviceName ?? 'Service',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    if (booking.servicePrice != null)
                      Text(
                        '₹${booking.servicePrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppTheme.primaryAction,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: subtitleColor),
                    const SizedBox(width: 8),
                    Text(booking.formattedDate,
                        style: TextStyle(color: textColor, fontSize: 13)),
                    if (booking.bookingTime != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time_outlined,
                          size: 16, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(booking.bookingTime!,
                          style:
                              TextStyle(color: textColor, fontSize: 13)),
                    ],
                  ],
                ),
                if (booking.duration != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 16, color: subtitleColor),
                      const SizedBox(width: 8),
                      Text(booking.formattedDuration ?? '',
                          style:
                              TextStyle(color: subtitleColor, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Notes
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(booking.notes!,
                style: TextStyle(
                    color: subtitleColor, fontSize: 13, fontStyle: FontStyle.italic)),
          ],

          // Cancel reason
          if (booking.status == BookingStatus.cancelled &&
              booking.cancelReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorStatus.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.errorStatus, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(booking.cancelReason!,
                        style:
                            const TextStyle(color: AppTheme.errorStatus, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          if (booking.status == BookingStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _declineBooking(booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorStatus,
                        side: const BorderSide(color: AppTheme.errorStatus),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Decline',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _confirmBooking(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAction,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (booking.status == BookingStatus.confirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () => _completeBooking(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAction,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Mark Complete',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          // Timestamp
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(booking.timeAgo,
                style: TextStyle(color: subtitleColor, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BookingStatus status) {
    Color color;
    String label;
    switch (status) {
      case BookingStatus.pending:
        color = AppTheme.warningStatus;
        label = 'Pending';
      case BookingStatus.confirmed:
        color = AppTheme.successStatus;
        label = 'Confirmed';
      case BookingStatus.completed:
        color = AppTheme.primaryAction;
        label = 'Completed';
      case BookingStatus.cancelled:
        color = AppTheme.errorStatus;
        label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _confirmBooking(BookingModel booking) async {
    await _bookingService.updateBookingStatus(
        booking.id, BookingStatus.confirmed);
  }

  Future<void> _declineBooking(BookingModel booking) async {
    final reason = await _showCancelReasonDialog();
    if (reason == null) return;
    await _bookingService.updateBookingStatus(
        booking.id, BookingStatus.cancelled,
        cancelReason: reason);
  }

  Future<void> _completeBooking(BookingModel booking) async {
    await _bookingService.updateBookingStatus(
        booking.id, BookingStatus.completed);
  }

  Future<String?> _showCancelReasonDialog() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Decline Reason',
            style: TextStyle(
                color: AppTheme.textPrimary(isDark),
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary(isDark)),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Optional: reason for declining...',
            hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx,
                  controller.text.trim().isEmpty ? 'Declined' : controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorStatus,
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, IconData icon,
      String title, String subtitle) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: subtitleColor),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 13)),
        ],
      ),
    );
  }
}
