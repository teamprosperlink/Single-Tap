import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';
import '../../../models/booking_model.dart';
import '../../../config/app_theme.dart';
import '../../../config/app_components.dart';
import 'package:flutter/services.dart';
import '../business_notifications_screen.dart';
import 'bookings_tab.dart';
import 'rooms_tab.dart';

/// Hospitality Archetype Dashboard
/// For: Hotels, Resorts, Lodges
/// Features: Revenue tracking, occupancy overview, bookings, room management
class HospitalityDashboardScreen extends StatefulWidget {
  final BusinessModel? business;
  final VoidCallback? onRefresh;

  const HospitalityDashboardScreen({
    super.key,
    this.business,
    this.onRefresh,
  });

  @override
  State<HospitalityDashboardScreen> createState() =>
      _HospitalityDashboardScreenState();
}

class _HospitalityDashboardScreenState
    extends State<HospitalityDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  bool _isLoading = true;
  double _totalRevenue = 0.0;
  double _revenueGrowth = 0.0;
  int _occupancyToday = 0;
  int _totalRooms = 0;
  int _guestsActionNeeded = 0;
  int _todayBookings = 0;
  List<BookingModel> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    if (widget.business != null) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      if (widget.business != null) {
        await Future.wait([
          _loadRevenueStats(),
          _loadOccupancyStats(),
          _loadBookingStats(),
          _loadRecentBookings(),
        ]);
      }
    } catch (e) {
      debugPrint('Error loading hospitality dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRevenueStats() async {
    if (widget.business == null) return;

    // Get this week's revenue
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final bookingsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business!.id)
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartMidnight))
        .get();

    double thisWeekRevenue = 0.0;
    for (var doc in bookingsSnapshot.docs) {
      final booking = BookingModel.fromFirestore(doc);
      if (booking.status != BookingStatus.cancelled) {
        thisWeekRevenue += booking.total;
      }
    }

    // Get last week's revenue for growth calculation
    final lastWeekStart = weekStartMidnight.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStartMidnight;

    final lastWeekSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business!.id)
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeekStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(lastWeekEnd))
        .get();

    double lastWeekRevenue = 0.0;
    for (var doc in lastWeekSnapshot.docs) {
      final booking = BookingModel.fromFirestore(doc);
      if (booking.status != BookingStatus.cancelled) {
        lastWeekRevenue += booking.total;
      }
    }

    double growth = 0.0;
    if (lastWeekRevenue > 0) {
      growth = ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
    }

    if (mounted) {
      setState(() {
        _totalRevenue = thisWeekRevenue;
        _revenueGrowth = growth;
      });
    }
  }

  Future<void> _loadOccupancyStats() async {
    if (widget.business == null) return;

    final roomsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business!.id)
        .collection('rooms')
        .get();

    int occupiedRooms = 0;
    for (var doc in roomsSnapshot.docs) {
      final data = doc.data();
      if (data['isAvailable'] == false) {
        occupiedRooms++;
      }
    }

    if (mounted) {
      setState(() {
        _totalRooms = roomsSnapshot.size;
        _occupancyToday = occupiedRooms;
      });
    }
  }

  Future<void> _loadBookingStats() async {
    if (widget.business == null) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final bookingsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business!.id)
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();

    int actionNeeded = 0;
    for (var doc in bookingsSnapshot.docs) {
      final booking = BookingModel.fromFirestore(doc);
      if (booking.status == BookingStatus.pending) {
        actionNeeded++;
      }
    }

    if (mounted) {
      setState(() {
        _todayBookings = bookingsSnapshot.size;
        _guestsActionNeeded = actionNeeded;
      });
    }
  }

  Future<void> _loadRecentBookings() async {
    if (widget.business == null) return;

    final bookingsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business!.id)
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _recentBookings = bookingsSnapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
          widget.onRefresh?.call();
        },
        color: AppTheme.hospitalityIndigo,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppTheme.cardColor(isDarkMode),
              elevation: 0,
              pinned: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.business?.businessName ?? 'Hospitality Dashboard',
                    style: TextStyle(
                      color: AppTheme.textPrimary(isDarkMode),
                      fontWeight: FontWeight.bold,
                      fontSize: AppTheme.fontTitle,
                    ),
                  ),
                  if (widget.business?.isVerified == true)
                    Text(
                      'Verified Business',
                      style: TextStyle(
                        color: AppTheme.infoBlue,
                        fontSize: AppTheme.fontSmall,
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textPrimary(isDarkMode),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BusinessNotificationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.hospitalityIndigo,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      _buildWelcomeSection(isDarkMode),
                      const SizedBox(height: 24),

                      // Today's Overview Stats
                      _buildTodayOverview(isDarkMode),
                      const SizedBox(height: 24),

                      // Quick Actions
                      _buildQuickActions(isDarkMode),
                      const SizedBox(height: 24),

                      // Action Needed Alert
                      if (_guestsActionNeeded > 0) ...[
                        _buildActionNeededAlert(isDarkMode),
                        const SizedBox(height: 24),
                      ],

                      // Recent Bookings
                      _buildRecentBookings(isDarkMode),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isDarkMode) {
    return AppComponents.revenueCard(
      label: 'Total Revenue (This Week)',
      amount: '₹${NumberFormat('#,##,###').format(_totalRevenue)}',
      change: '${_revenueGrowth.toStringAsFixed(1)}%',
      isPositive: _revenueGrowth >= 0,
      isDarkMode: isDarkMode,
      gradientStart: AppTheme.hospitalityIndigo,
      gradientEnd: const Color(0xFF4F46E5),
    );
  }

  Widget _buildTodayOverview(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Overview",
          style: TextStyle(
            fontSize: AppTheme.fontHeading,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(isDarkMode),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppComponents.statsCard(
                icon: Icons.hotel_rounded,
                label: 'Occupancy',
                value: '$_occupancyToday/$_totalRooms',
                color: AppTheme.infoBlue,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppComponents.statsCard(
                icon: Icons.people_outline_rounded,
                label: 'Guests',
                value: _guestsActionNeeded.toString(),
                color: AppTheme.warningOrange,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppComponents.statsCard(
                icon: Icons.calendar_today_rounded,
                label: 'Bookings',
                value: _todayBookings.toString(),
                color: AppTheme.hospitalityIndigo,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppComponents.statsCard(
                icon: Icons.currency_rupee_rounded,
                label: 'Revenue',
                value: '₹${NumberFormat.compact().format(_totalRevenue)}',
                color: AppTheme.successGreen,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: AppTheme.fontHeading,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(isDarkMode),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppComponents.actionButton(
                icon: Icons.calendar_month_rounded,
                label: 'Bookings',
                color: AppTheme.hospitalityIndigo,
                isDarkMode: isDarkMode,
                onTap: () {
                  if (widget.business != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingsTab(
                          business: widget.business!,
                          onRefresh: widget.onRefresh ?? () {},
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppComponents.actionButton(
                icon: Icons.bed_rounded,
                label: 'Room Status',
                color: AppTheme.infoBlue,
                isDarkMode: isDarkMode,
                onTap: () {
                  if (widget.business != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomsTab(
                          business: widget.business!,
                          onRefresh: widget.onRefresh ?? () {},
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionNeededAlert(bool isDarkMode) {
    return AppComponents.alertBanner(
      title: 'Pending Guest Requests',
      message: '$_guestsActionNeeded guests need your attention',
      icon: Icons.notifications_active_rounded,
      color: AppTheme.warningOrange,
      isDarkMode: isDarkMode,
      actionLabel: 'View',
      onAction: () {
        if (widget.business != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingsTab(
                business: widget.business!,
                onRefresh: widget.onRefresh ?? () {},
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildRecentBookings(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Recent Activity',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            if (widget.business != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsTab(
                    business: widget.business!,
                    onRefresh: widget.onRefresh ?? () {},
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        if (_recentBookings.isEmpty)
          AppComponents.emptyState(
            icon: Icons.event_busy_rounded,
            title: 'No Recent Activity',
            message: 'Your business activities will appear here',
            isDarkMode: isDarkMode,
          )
        else
          ..._recentBookings.map((booking) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBookingCard(booking, isDarkMode),
              )),
      ],
    );
  }

  Widget _buildBookingCard(BookingModel booking, bool isDarkMode) {
    Color statusColor;
    String statusText;

    switch (booking.status) {
      case BookingStatus.pending:
        statusColor = AppTheme.warningOrange;
        statusText = 'Pending';
        break;
      case BookingStatus.confirmed:
        statusColor = AppTheme.infoBlue;
        statusText = 'Confirmed';
        break;
      case BookingStatus.inProgress:
        statusColor = AppTheme.purpleAccent;
        statusText = 'In Progress';
        break;
      case BookingStatus.completed:
        statusColor = AppTheme.successGreen;
        statusText = 'Completed';
        break;
      case BookingStatus.cancelled:
        statusColor = AppTheme.errorRed;
        statusText = 'Cancelled';
        break;
      case BookingStatus.checkedIn:
        statusColor = AppTheme.successGreen;
        statusText = 'Checked In';
        break;
      case BookingStatus.checkedOut:
        statusColor = Colors.grey;
        statusText = 'Checked Out';
        break;
    }

    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.customerName,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(isDarkMode),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking • ${booking.checkIn != null ? DateFormat('MMM d').format(booking.checkIn!) : 'No date'}',
                  style: TextStyle(
                    fontSize: AppTheme.fontRegular,
                    color: AppTheme.secondaryText(isDarkMode),
                  ),
                ),
              ],
            ),
          ),
          AppComponents.statusBadge(
            text: statusText,
            color: statusColor,
          ),
        ],
      ),
    );
  }
}