import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/app_theme.dart';
import '../../../models/booking_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/review_service.dart';
import 'write_review_screen.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bookingService = BookingService();
  final _reviewService = ReviewService();
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
        appBar: AppBar(title: const Text('My Bookings')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryAction,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: AppTheme.primaryAction,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(
            statuses: [BookingStatus.pending, BookingStatus.confirmed],
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.calendar_today_outlined,
            emptyTitle: 'No upcoming bookings',
            emptySubtitle: 'Your confirmed and pending bookings appear here',
          ),
          _buildBookingList(
            statuses: [BookingStatus.completed],
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.check_circle_outline,
            emptyTitle: 'No completed bookings',
            emptySubtitle: 'Completed bookings will appear here',
            showReviewButton: true,
          ),
          _buildBookingList(
            statuses: [BookingStatus.cancelled],
            isDark: isDark,
            textColor: textColor,
            emptyIcon: Icons.cancel_outlined,
            emptyTitle: 'No cancelled bookings',
            emptySubtitle: 'Cancelled bookings will appear here',
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList({
    required List<BookingStatus> statuses,
    required bool isDark,
    required Color textColor,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showReviewButton = false,
  }) {
    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.streamCustomerBookings(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];
        final bookings =
            all.where((b) => statuses.contains(b.status)).toList();

        if (bookings.isEmpty) {
          return _buildEmptyState(
              isDark, textColor, emptyIcon, emptyTitle, emptySubtitle);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildBookingCard(
            bookings[index],
            isDark,
            textColor,
            showReviewButton: showReviewButton,
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(
    BookingModel booking,
    bool isDark,
    Color textColor, {
    bool showReviewButton = false,
  }) {
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
          // Header: business name + status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppTheme.primaryAction.withValues(alpha: 0.12),
                child: const Icon(Icons.storefront,
                    color: AppTheme.primaryAction, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.businessName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (booking.serviceName != null)
                      Text(
                        booking.serviceName!,
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                  ],
                ),
              ),
              _statusChip(booking.status),
            ],
          ),
          const SizedBox(height: 12),
          // Date, time, price row
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: subtitleColor),
              const SizedBox(width: 6),
              Text(
                booking.formattedDate,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
              if (booking.bookingTime != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.access_time_outlined,
                    size: 14, color: subtitleColor),
                const SizedBox(width: 4),
                Text(
                  booking.bookingTime!,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ],
              const Spacer(),
              if (booking.servicePrice != null)
                Text(
                  '\u20B9${booking.servicePrice!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppTheme.primaryAction,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          // Notes
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              booking.notes!,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.errorStatus),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.cancelReason!,
                      style: const TextStyle(
                          color: AppTheme.errorStatus, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Actions
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                booking.timeAgo,
                style: TextStyle(color: subtitleColor, fontSize: 11),
              ),
              const Spacer(),
              // Cancel button for pending/confirmed
              if (booking.status == BookingStatus.pending ||
                  booking.status == BookingStatus.confirmed)
                TextButton(
                  onPressed: () => _cancelBooking(booking),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorStatus,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              // Review button for completed
              if (showReviewButton &&
                  booking.status == BookingStatus.completed)
                _ReviewButton(
                  booking: booking,
                  reviewService: _reviewService,
                  userId: _userId!,
                ),
            ],
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
        color = AppTheme.primaryAction;
        label = 'Confirmed';
      case BookingStatus.completed:
        color = AppTheme.successStatus;
        label = 'Completed';
      case BookingStatus.cancelled:
        color = AppTheme.errorStatus;
        label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _cancelBooking(BookingModel booking) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: AppTheme.cardColor(isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cancel Booking',
              style: TextStyle(color: AppTheme.textPrimary(isDark))),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            style: TextStyle(color: AppTheme.textPrimary(isDark)),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Cancel Booking',
                  style: TextStyle(color: AppTheme.errorStatus)),
            ),
          ],
        );
      },
    );

    if (reason == null || !mounted) return;

    final success = await _bookingService.updateBookingStatus(
      booking.id,
      BookingStatus.cancelled,
      cancelReason: reason.isNotEmpty ? reason : null,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Booking cancelled' : 'Failed to cancel'),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, IconData icon,
      String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                size: 28,
                color: isDark ? Colors.white24 : Colors.black26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget to handle async hasUserReviewed check
class _ReviewButton extends StatefulWidget {
  final BookingModel booking;
  final ReviewService reviewService;
  final String userId;

  const _ReviewButton({
    required this.booking,
    required this.reviewService,
    required this.userId,
  });

  @override
  State<_ReviewButton> createState() => _ReviewButtonState();
}

class _ReviewButtonState extends State<_ReviewButton> {
  bool? _hasReviewed;

  @override
  void initState() {
    super.initState();
    _checkReview();
  }

  Future<void> _checkReview() async {
    final result = await widget.reviewService
        .hasUserReviewed(widget.booking.businessOwnerId, widget.userId);
    if (!mounted) return;
    setState(() => _hasReviewed = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasReviewed == null) return const SizedBox.shrink();
    if (_hasReviewed!) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successStatus.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: AppTheme.successStatus),
            SizedBox(width: 4),
            Text(
              'Reviewed',
              style: TextStyle(
                color: AppTheme.successStatus,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return TextButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WriteReviewScreen(
              businessUserId: widget.booking.businessOwnerId,
              businessName: widget.booking.businessName,
            ),
          ),
        ).then((_) => _checkReview());
      },
      icon: const Icon(Icons.star_outline, size: 16),
      label: const Text('Review'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.warningStatus,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
