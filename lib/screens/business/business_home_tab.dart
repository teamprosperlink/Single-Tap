import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import '../../config/business_category_config.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';

/// Dashboard data model for real-time stats
class DashboardData {
  final int metric1Value;
  final int metric2Value;
  final int metric3Value;
  final int metric4Value;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final int totalRooms;
  final int availableRooms;

  const DashboardData({
    this.metric1Value = 0,
    this.metric2Value = 0,
    this.metric3Value = 0,
    this.metric4Value = 0,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.totalRooms = 0,
    this.availableRooms = 0,
  });
}

/// Home tab showing dashboard with stats, online toggle, and quick actions
///
/// Dashboard adapts based on business category:
/// - Retail: Orders, Products, Inventory
/// - Food & Beverage: Orders, Kitchen, QR Menu
/// - Hospitality: Bookings, Room Status, Guests
/// - Healthcare: Appts, Patients, Records
/// - Beauty & Wellness: Schedule, Staff, Reviews
class BusinessHomeTab extends StatefulWidget {
  final BusinessModel business;
  final BusinessCategory category;
  final VoidCallback onRefresh;
  final Function(int) onSwitchTab;

  const BusinessHomeTab({
    super.key,
    required this.business,
    required this.category,
    required this.onRefresh,
    required this.onSwitchTab,
  });

  @override
  State<BusinessHomeTab> createState() => _BusinessHomeTabState();
}

class _BusinessHomeTabState extends State<BusinessHomeTab> {
  final BusinessService _businessService = BusinessService();
  bool _isOnline = false;
  DashboardData _dashboardData = const DashboardData();
  bool _isLoadingStats = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.business.isOnline;
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(BusinessHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.isOnline != widget.business.isOnline) {
      _isOnline = widget.business.isOnline;
    }
    if (oldWidget.business.id != widget.business.id ||
        oldWidget.category != widget.category) {
      _loadDashboardData();
    }
  }

  /// Load dashboard data based on business category
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
      _loadError = null;
    });

    try {
      switch (widget.category) {
        case BusinessCategory.hospitality:
        case BusinessCategory.travelTourism:
          await _loadHospitalityStats();
          break;
        case BusinessCategory.healthcare:
        case BusinessCategory.beautyWellness:
        case BusinessCategory.fitness:
          await _loadAppointmentStats();
          break;
        case BusinessCategory.retail:
        case BusinessCategory.grocery:
        case BusinessCategory.foodBeverage:
        default:
          await _loadDefaultStats();
          break;
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load dashboard data';
          _isLoadingStats = false;
        });
      }
    }
  }

  /// Load hospitality-specific stats (bookings, check-ins, rooms, revenue)
  Future<void> _loadHospitalityStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int totalRooms = 0;
    int availableRooms = 0;
    try {
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.business.id)
          .collection('rooms')
          .limit(100)
          .get();

      for (final doc in roomsSnapshot.docs) {
        final data = doc.data();
        final roomTotal = (data['totalRooms'] ?? data['quantity'] ?? 1);
        final roomAvailable = (data['availableRooms'] ?? data['available'] ?? roomTotal);
        totalRooms += roomTotal is int ? roomTotal : (roomTotal as num).toInt();
        availableRooms += roomAvailable is int ? roomAvailable : (roomAvailable as num).toInt();
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
    }

    int totalBookings = 0;
    int todayCheckIns = 0;
    int todayCheckOuts = 0;
    int pendingBookings = 0;
    double todayRevenue = 0;
    double weekRevenue = 0;
    double monthRevenue = 0;

    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.business.id)
          .collection('room_bookings')
          .orderBy('checkIn', descending: true)
          .limit(200)
          .get();

      totalBookings = bookingsSnapshot.docs.length;

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
        final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
        final status = data['status'] as String?;
        final total = (data['totalAmount'] ?? data['total'] ?? 0).toDouble();

        if (checkIn != null && checkIn.isAfter(startOfDay) && checkIn.isBefore(endOfDay)) {
          todayCheckIns++;
          todayRevenue += total;
        }

        if (checkOut != null && checkOut.isAfter(startOfDay) && checkOut.isBefore(endOfDay)) {
          todayCheckOuts++;
        }

        if (status == 'pending') pendingBookings++;

        if (checkIn != null && checkIn.isAfter(startOfWeek)) weekRevenue += total;
        if (checkIn != null && checkIn.isAfter(startOfMonth)) monthRevenue += total;
      }
    } catch (e) {
      debugPrint('Error loading hospitality bookings: $e');
    }

    if (mounted) {
      setState(() {
        _dashboardData = DashboardData(
          metric1Value: totalBookings,
          metric2Value: todayCheckIns,
          metric3Value: todayCheckOuts,
          metric4Value: pendingBookings,
          totalRooms: totalRooms,
          availableRooms: availableRooms,
          todayRevenue: todayRevenue,
          weekRevenue: weekRevenue,
          monthRevenue: monthRevenue,
        );
        _isLoadingStats = false;
      });
    }
  }

  /// Load appointment-based stats (healthcare, beauty, fitness)
  Future<void> _loadAppointmentStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    int totalAppointments = 0;
    int todayAppointments = 0;
    int completedAppointments = 0;
    int pendingAppointments = 0;

    try {
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.business.id)
          .collection('appointments')
          .orderBy('dateTime', descending: true)
          .limit(200)
          .get();

      totalAppointments = appointmentsSnapshot.docs.length;

      for (final doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
        final status = data['status'] as String?;

        if (dateTime != null && dateTime.isAfter(startOfDay) && dateTime.isBefore(endOfDay)) {
          todayAppointments++;
        }

        if (status == 'completed') completedAppointments++;
        if (status == 'pending' || status == 'confirmed') pendingAppointments++;
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
    }

    if (mounted) {
      setState(() {
        _dashboardData = DashboardData(
          metric1Value: totalAppointments,
          metric2Value: todayAppointments,
          metric3Value: completedAppointments,
          metric4Value: pendingAppointments,
          todayRevenue: widget.business.todayEarnings,
          weekRevenue: widget.business.monthlyEarnings,
          monthRevenue: widget.business.totalEarnings,
        );
        _isLoadingStats = false;
      });
    }
  }

  /// Load default stats from business model
  Future<void> _loadDefaultStats() async {
    if (mounted) {
      setState(() {
        _dashboardData = DashboardData(
          metric1Value: widget.business.totalOrders,
          metric2Value: widget.business.pendingOrders,
          metric3Value: widget.business.completedOrders,
          metric4Value: widget.business.todayOrders,
          todayRevenue: widget.business.todayEarnings,
          weekRevenue: widget.business.monthlyEarnings,
          monthRevenue: widget.business.totalEarnings,
        );
        _isLoadingStats = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _toggleOnlineStatus() async {
    HapticFeedback.lightImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    try {
      await _businessService.updateOnlineStatus(widget.business.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'You are now online' : 'You are now offline'),
            backgroundColor: newStatus ? Colors.green : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      setState(() => _isOnline = !newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            AppAssets.homeBackgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(color: AppColors.darkOverlay()),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildAppBarHeader(),

              // Divider line
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),

              // Scrollable content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadDashboardData();
                    widget.onRefresh();
                  },
                  color: const Color(0xFF00D67D),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Quick Actions
                      _buildQuickActions(),
                      const SizedBox(height: 24),

                      // Stats Grid
                      _buildSectionTitle('Overview'),
                      const SizedBox(height: 12),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),

                      // Revenue section (for applicable categories)
                      if (_shouldShowRevenue()) ...[
                        _buildRevenueSection(),
                        const SizedBox(height: 24),
                      ],

                      // Analytics Preview
                      _buildAnalyticsPreview(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowRevenue() {
    switch (widget.category) {
      case BusinessCategory.hospitality:
      case BusinessCategory.travelTourism:
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
      case BusinessCategory.foodBeverage:
        return true;
      default:
        return false;
    }
  }

  Widget _buildAppBarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business logo
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: widget.business.logo != null
                  ? Image.network(
                      widget.business.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                    )
                  : _buildLogoPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),

          // Business name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.business.businessName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.white54),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _getLocationText(),
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online/Offline toggle
          _buildOnlineToggleCompact(),

          const SizedBox(width: 8),

          // Notification button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
            },
            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  String _getLocationText() {
    final address = widget.business.address;
    if (address == null) return 'Location not set';

    final parts = <String>[];
    if (address.city != null && address.city!.isNotEmpty) parts.add(address.city!);
    if (address.state != null && address.state!.isNotEmpty) parts.add(address.state!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not set';
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00D67D),
      ),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineToggleCompact() {
    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _isOnline ? Icons.toggle_on : Icons.toggle_off,
            size: 44,
            color: _isOnline ? const Color(0xFF00D67D) : Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final terminology = CategoryTerminology.getForCategory(widget.category);
    final quickActions = terminology.quickActions;

    return Row(
      children: List.generate(quickActions.length, (index) {
        final action = quickActions[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == quickActions.length - 1 ? 0 : 6,
            ),
            child: _buildQuickActionCard(
              icon: action.icon,
              label: action.label,
              color: action.color,
              onTap: () => _handleQuickAction(action.label),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleQuickAction(String label) {
    switch (label.toLowerCase()) {
      case 'orders':
      case 'bookings':
      case 'appts':
      case 'schedule':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessInquiriesScreen(
              business: widget.business,
              initialFilter: 'All',
            ),
          ),
        );
        break;
      case 'products':
      case 'menu':
      case 'rooms':
      case 'services':
      case 'inventory':
      case 'kitchen':
      case 'room status':
        widget.onSwitchTab(1); // Switch to content tab
        break;
      case 'analytics':
      case 'reviews':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
        break;
      default:
        // Handle other actions
        break;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return _buildLoadingStatsGrid();
    }

    if (_loadError != null) {
      return _buildErrorStatsGrid();
    }

    final terminology = CategoryTerminology.getForCategory(widget.category);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        GlassmorphicStatCard(
          title: terminology.metric1Label,
          value: '${_dashboardData.metric1Value}',
          icon: terminology.metric1Icon,
          accentColor: const Color(0xFF00D67D),
          onTap: () => _navigateToInquiries('All'),
        ),
        GlassmorphicStatCard(
          title: 'Today',
          value: '${_dashboardData.metric4Value}',
          icon: Icons.today,
          accentColor: Colors.purple,
          onTap: () => _navigateToInquiries('Today'),
        ),
        GlassmorphicStatCard(
          title: terminology.metric3Label,
          value: '${_dashboardData.metric3Value}',
          icon: terminology.metric3Icon,
          accentColor: Colors.blue,
          onTap: () => _navigateToInquiries('Responded'),
        ),
        GlassmorphicStatCard(
          title: 'Pending',
          value: '${_dashboardData.metric2Value}',
          icon: Icons.pending_outlined,
          accentColor: Colors.orange,
          onTap: () => _navigateToInquiries('New'),
        ),
      ],
    );
  }

  Widget _buildLoadingStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: List.generate(4, (index) {
        return GlassmorphicCard(
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorStatsGrid() {
    return GlassmorphicCard(
      onTap: _loadDashboardData,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange.withValues(alpha: 0.8),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Failed to load data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to retry',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueSection() {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF00D67D),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Revenue Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildRevenueItem(
                    label: 'Today',
                    amount: _dashboardData.todayRevenue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildRevenueItem(
                    label: 'This Week',
                    amount: _dashboardData.weekRevenue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildRevenueItem(
                    label: 'This Month',
                    amount: _dashboardData.monthRevenue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueItem({
    required String label,
    required double amount,
  }) {
    return Column(
      children: [
        Text(
          amount > 0 ? '\u20B9${_formatCurrency(amount)}' : '\u20B90',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D67D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPreview() {
    return GlassmorphicCard(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
      },
      showGlow: true,
      glowColor: const Color(0xFF00D67D),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF00D67D),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'See insights about your business',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInquiries(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessInquiriesScreen(
          business: widget.business,
          initialFilter: filter,
        ),
      ),
    );
  }
}
