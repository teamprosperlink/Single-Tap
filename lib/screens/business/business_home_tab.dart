import 'dart:io';
import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/business_model.dart';
import '../../models/business_dashboard_config.dart';
import '../../services/business_service.dart';
import '../../services/business/business_media_service.dart';
import '../../widgets/business/dashboard_cover_header.dart';
import '../../widgets/business/dashboard_quick_actions.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';
import 'gallery_screen.dart';
import 'hospitality/bookings_tab.dart';
import 'hospitality/rooms_tab.dart';
import 'appointments/appointments_tab.dart';
import 'food/orders_tab.dart';
import 'food/menu_tab.dart';
import 'retail/products_tab.dart';
import 'business_services_tab.dart';

/// Redesigned business home tab with clean, professional UI
class BusinessHomeTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;
  final Function(int) onSwitchTab;

  const BusinessHomeTab({
    super.key,
    required this.business,
    required this.onRefresh,
    required this.onSwitchTab,
  });

  @override
  State<BusinessHomeTab> createState() => _BusinessHomeTabState();
}

enum DateRange { today, week, month, custom }

class _BusinessHomeTabState extends State<BusinessHomeTab> {
  final BusinessService _businessService = BusinessService();
  bool _isOnline = false;
  late CategoryGroup _categoryGroup;
  DashboardData _dashboardData = const DashboardData();
  final DateRange _selectedDateRange = DateRange.today;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.business.isOnline;
    _categoryGroup = getCategoryGroup(widget.business.category);
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(BusinessHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.isOnline != widget.business.isOnline) {
      _isOnline = widget.business.isOnline;
    }
    if (oldWidget.business.category != widget.business.category) {
      _categoryGroup = getCategoryGroup(widget.business.category);
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load base data from business model
      final baseData = DashboardData(
        totalOrders: widget.business.totalOrders,
        pendingOrders: widget.business.pendingOrders,
        completedOrders: widget.business.completedOrders,
        todayOrders: widget.business.todayOrders,
        todayRevenue: widget.business.todayEarnings,
        weekRevenue: widget.business.monthlyEarnings,
        monthRevenue: widget.business.totalEarnings,
      );

      // Load category-specific data from Firestore
      final categoryData = await _loadCategorySpecificData();

      // Create initial dashboard data
      final updatedData = DashboardData(
        // Base data
        totalOrders: baseData.totalOrders,
        pendingOrders: baseData.pendingOrders,
        completedOrders: baseData.completedOrders,
        todayOrders: baseData.todayOrders,
        todayRevenue: baseData.todayRevenue,
        weekRevenue: baseData.weekRevenue,
        monthRevenue: baseData.monthRevenue,

        // Category-specific data
        newInquiries: categoryData['newInquiries'] ?? 0,
        respondedInquiries: categoryData['respondedInquiries'] ?? 0,
        totalItems: categoryData['totalItems'] ?? 0,
        lowStockItems: categoryData['lowStockItems'] ?? 0,
        todayAppointments: categoryData['todayAppointments'] ?? 0,
        pendingAppointments: categoryData['pendingAppointments'] ?? 0,
        availableRooms: categoryData['availableRooms'] ?? 0,
        totalRooms: categoryData['totalRooms'] ?? 0,
        todayCheckIns: categoryData['todayCheckIns'] ?? 0,
        todayCheckOuts: categoryData['todayCheckOuts'] ?? 0,
        preparingOrders: categoryData['preparingOrders'] ?? 0,
        deliveryOrders: categoryData['deliveryOrders'] ?? 0,
      );

      setState(() {
        _dashboardData = updatedData;
      });

      // Load trends and history in background (non-blocking)
      _loadTrendsAndHistory(widget.business.id);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
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
            backgroundColor: newStatus ? const Color(0xFF00D67D) : Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        // Premium black gradient background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F0F0F),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // Subtle premium overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDashboardData();
              widget.onRefresh();
            },
            color: const Color(0xFF00D67D),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header with toggle and notification
                SliverToBoxAdapter(child: _buildHeader()),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Cover Image Header (LinkedIn-style)
                      _buildCoverHeader(),
                      const SizedBox(height: 20),

                      // Quick Actions (2x2 grid)
                      _buildQuickActionsGrid(),
                      const SizedBox(height: 20),

                      // Revenue Chart (7-day trend)
                      _buildRevenueChartCard(),
                      if (_dashboardData.revenueHistory.isNotEmpty)
                        const SizedBox(height: 20),

                      // Revenue Overview
                      _buildRevenueCard(),
                      const SizedBox(height: 20),

                      // Category-Specific Insights
                      _buildInsightsWidget(),
                      const SizedBox(height: 20),

                      // Recent Activity
                      _buildActivitySection(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business Logo
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GalleryScreen(business: widget.business),
                ),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.business.logo != null
                    ? Image.network(
                        widget.business.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildLogoPlaceholder(),
                      )
                    : _buildLogoPlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Business Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.business.businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.business.isVerified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D67D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        _getLocationText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online Status Toggle (compact)
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOnline
                      ? const Color(0xFF00D67D).withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isOnline ? Icons.toggle_on : Icons.toggle_off,
                    size: 20,
                    color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (_getPendingItemsCount() > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _getPendingItemsCount() > 9 ? '9+' : '${_getPendingItemsCount()}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Center(
      child: Text(
        widget.business.businessName.isNotEmpty
            ? widget.business.businessName[0].toUpperCase()
            : 'B',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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


  Widget _buildCoverHeader() {
    return DashboardCoverHeader(
      business: widget.business,
      categoryColor: _getCategoryColor(),
      categoryIcon: _getCategoryIcon(),
      categoryLabel: _getCategoryLabel(),
      onEditCover: _handleEditCover,
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = BusinessDashboardConfig.getQuickActions(_categoryGroup);
    return DashboardQuickActions(
      actions: actions,
      onActionTap: _handleQuickActionRoute,
      isDarkMode: true,
    );
  }

  Color _getCategoryColor() {
    switch (_categoryGroup) {
      case CategoryGroup.food:
        return const Color(0xFFFFA726); // Amber
      case CategoryGroup.retail:
        return const Color(0xFF00D67D); // Green
      case CategoryGroup.hospitality:
        return const Color(0xFF6366F1); // Indigo
      case CategoryGroup.services:
        return const Color(0xFF42A5F5); // Blue
      case CategoryGroup.fitness:
        return const Color(0xFFEF5350); // Red
      case CategoryGroup.education:
        return const Color(0xFF26A69A); // Teal
      case CategoryGroup.professional:
        return const Color(0xFF5C6BC0); // Indigo
      case CategoryGroup.creative:
        return const Color(0xFF8B5CF6); // Purple
      case CategoryGroup.events:
        return const Color(0xFFEC407A); // Pink
      case CategoryGroup.construction:
        return const Color(0xFFFFA726); // Orange
    }
  }

  IconData _getCategoryIcon() {
    switch (_categoryGroup) {
      case CategoryGroup.food:
        return Icons.restaurant;
      case CategoryGroup.retail:
        return Icons.storefront;
      case CategoryGroup.hospitality:
        return Icons.hotel;
      case CategoryGroup.services:
        return Icons.build;
      case CategoryGroup.fitness:
        return Icons.fitness_center;
      case CategoryGroup.education:
        return Icons.school;
      case CategoryGroup.professional:
        return Icons.work;
      case CategoryGroup.creative:
        return Icons.palette;
      case CategoryGroup.events:
        return Icons.celebration;
      case CategoryGroup.construction:
        return Icons.construction;
    }
  }

  String _getCategoryLabel() {
    switch (_categoryGroup) {
      case CategoryGroup.food:
        return 'Food & Beverage';
      case CategoryGroup.retail:
        return 'Retail';
      case CategoryGroup.hospitality:
        return 'Hospitality';
      case CategoryGroup.services:
        return 'Services';
      case CategoryGroup.fitness:
        return 'Fitness';
      case CategoryGroup.education:
        return 'Education';
      case CategoryGroup.professional:
        return 'Professional';
      case CategoryGroup.creative:
        return 'Creative';
      case CategoryGroup.events:
        return 'Events';
      case CategoryGroup.construction:
        return 'Construction';
    }
  }

  Future<void> _handleEditCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Uploading cover image...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Upload image using BusinessMediaService
      final mediaService = BusinessMediaService();
      final imageUrl = await mediaService.uploadCoverImage(File(image.path));

      if (imageUrl != null) {
        // Update Firestore with new cover image URL
        await FirebaseProvider.firestore
            .collection('businesses')
            .doc(widget.business.id)
            .update({'coverImage': imageUrl});

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover image updated successfully'),
              backgroundColor: Color(0xFF00D67D),
            ),
          );
          widget.onRefresh();
        }
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cover image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleQuickActionRoute(String route) {
    HapticFeedback.lightImpact();

    switch (route) {
      case 'orders':
        _navigateToOrders();
        break;
      case 'menu':
        _navigateToMenu();
        break;
      case 'tables':
        _showComingSoon('Table Reservations');
        break;
      case 'products':
        _navigateToProducts();
        break;
      case 'add_product':
        _navigateToProducts();
        break;
      case 'bookings':
      case 'appointments':
      case 'checkins':
      case 'checkouts':
        _navigateToBookings();
        break;
      case 'rooms':
        _navigateToRooms();
        break;
      case 'services':
        _navigateToServices();
        break;
      case 'clients':
        _showComingSoon('Client Management');
        break;
      case 'classes':
        _navigateToServices();
        break;
      case 'members':
        _showComingSoon('Member Management');
        break;
      case 'courses':
        _navigateToServices();
        break;
      case 'enrollments':
        _showComingSoon('Enrollment Management');
        break;
      case 'attendance':
        _showComingSoon('Attendance Tracking');
        break;
      case 'projects':
        _showComingSoon('Project Management');
        break;
      case 'portfolio':
      case 'gallery':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryScreen(business: widget.business),
          ),
        );
        break;
      case 'commissions':
      case 'quotes':
      case 'inquiries':
        _navigateToInquiries();
        break;
      case 'packages':
        _navigateToServices();
        break;
      case 'calendar':
        _showComingSoon('Calendar');
        break;
      case 'analytics':
        _navigateToAnalytics();
        break;
      default:
        _showComingSoon(route);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: const Color(0xFFFFA726),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTrendIndicator(double trend) {
    final isPositive = trend >= 0;
    final trendColor = isPositive ? const Color(0xFF00D67D) : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${trend.abs().toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartCard() {
    if (_dashboardData.revenueHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.15),
            const Color(0xFF42A5F5).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '7-Day Revenue Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_dashboardData.revenueTrend != null)
                _buildTrendIndicator(_dashboardData.revenueTrend!),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${_formatCompactNumber(value)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: _getMaxRevenue() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: _dashboardData.revenueHistory.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF42A5F5),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF42A5F5),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactNumber(double number) {
    if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(0)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  double _getMaxRevenue() {
    if (_dashboardData.revenueHistory.isEmpty) return 100;
    final maxValue = _dashboardData.revenueHistory.reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue : 100;
  }

  Widget _buildInsightsWidget() {
    final insights = _getCategoryInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7E57C2).withValues(alpha: 0.15),
            const Color(0xFF7E57C2).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7E57C2).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF7E57C2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight['icon'] as IconData,
                  size: 16,
                  color: const Color(0xFF7E57C2).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight['text'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getCategoryInsights() {
    final insights = <Map<String, dynamic>>[];

    switch (_categoryGroup) {
      case CategoryGroup.food:
        if (_dashboardData.preparingOrders > 5) {
          insights.add({
            'icon': Icons.warning_amber_rounded,
            'text': '${_dashboardData.preparingOrders} orders in preparation - Consider adding kitchen staff',
          });
        }
        if (_dashboardData.deliveryOrders > 0) {
          insights.add({
            'icon': Icons.delivery_dining,
            'text': '${_dashboardData.deliveryOrders} orders out for delivery',
          });
        }
        if (_dashboardData.revenueTrend != null && _dashboardData.revenueTrend! > 20) {
          insights.add({
            'icon': Icons.trending_up,
            'text': 'Revenue up ${_dashboardData.revenueTrend!.toStringAsFixed(0)}% from yesterday! Great job!',
          });
        }
        break;

      case CategoryGroup.retail:
        if (_dashboardData.lowStockItems > 0) {
          insights.add({
            'icon': Icons.inventory_2_outlined,
            'text': '${_dashboardData.lowStockItems} items are running low on stock',
          });
        }
        if (_dashboardData.ordersTrend != null && _dashboardData.ordersTrend! < -10) {
          insights.add({
            'icon': Icons.trending_down,
            'text': 'Orders decreased ${_dashboardData.ordersTrend!.abs().toStringAsFixed(0)}% - Consider running promotions',
          });
        }
        if (_dashboardData.totalItems > 100) {
          insights.add({
            'icon': Icons.store,
            'text': 'You have ${_dashboardData.totalItems} products listed',
          });
        }
        break;

      case CategoryGroup.hospitality:
        if (_dashboardData.availableRooms == 0) {
          insights.add({
            'icon': Icons.hotel,
            'text': 'All rooms are fully booked!',
          });
        } else if (_dashboardData.availableRooms < 3) {
          insights.add({
            'icon': Icons.warning_amber_rounded,
            'text': 'Only ${_dashboardData.availableRooms} rooms available',
          });
        }
        if (_dashboardData.todayCheckIns > 0) {
          insights.add({
            'icon': Icons.login,
            'text': '${_dashboardData.todayCheckIns} guests checking in today',
          });
        }
        break;

      case CategoryGroup.fitness:
        if (_dashboardData.todayAppointments > 5) {
          insights.add({
            'icon': Icons.fitness_center,
            'text': '${_dashboardData.todayAppointments} classes scheduled today',
          });
        }
        if (_dashboardData.todayCheckIns > 20) {
          insights.add({
            'icon': Icons.people,
            'text': 'High member activity: ${_dashboardData.todayCheckIns} check-ins today',
          });
        }
        break;

      case CategoryGroup.education:
        if (_dashboardData.todayAppointments > 0) {
          insights.add({
            'icon': Icons.school,
            'text': '${_dashboardData.todayAppointments} classes running today',
          });
        }
        if (_dashboardData.newInquiries > 3) {
          insights.add({
            'icon': Icons.chat_bubble_outline,
            'text': '${_dashboardData.newInquiries} new student inquiries',
          });
        }
        break;

      case CategoryGroup.professional:
        if (_dashboardData.todayAppointments > 0) {
          insights.add({
            'icon': Icons.videocam,
            'text': '${_dashboardData.todayAppointments} meetings scheduled today',
          });
        }
        if (_dashboardData.pendingOrders > 5) {
          insights.add({
            'icon': Icons.work_outline,
            'text': '${_dashboardData.pendingOrders} active projects',
          });
        }
        break;

      case CategoryGroup.services:
        if (_dashboardData.todayAppointments > 10) {
          insights.add({
            'icon': Icons.calendar_today,
            'text': 'Busy day ahead: ${_dashboardData.todayAppointments} appointments',
          });
        }
        if (_dashboardData.newInquiries > 5) {
          insights.add({
            'icon': Icons.notifications_active,
            'text': '${_dashboardData.newInquiries} new inquiries need response',
          });
        }
        break;

      case CategoryGroup.creative:
        if (_dashboardData.todayAppointments > 0) {
          insights.add({
            'icon': Icons.brush,
            'text': '${_dashboardData.todayAppointments} projects in progress',
          });
        }
        if (_dashboardData.newInquiries > 0) {
          insights.add({
            'icon': Icons.chat_bubble_outline,
            'text': '${_dashboardData.newInquiries} new client inquiries',
          });
        }
        break;

      case CategoryGroup.events:
        if (_dashboardData.todayAppointments > 0) {
          insights.add({
            'icon': Icons.event,
            'text': '${_dashboardData.todayAppointments} events scheduled',
          });
        }
        if (_dashboardData.pendingOrders > 0) {
          insights.add({
            'icon': Icons.pending_actions,
            'text': '${_dashboardData.pendingOrders} bookings pending confirmation',
          });
        }
        break;

      case CategoryGroup.construction:
        if (_dashboardData.pendingOrders > 0) {
          insights.add({
            'icon': Icons.construction,
            'text': '${_dashboardData.pendingOrders} active projects',
          });
        }
        if (_dashboardData.newInquiries > 0) {
          insights.add({
            'icon': Icons.request_quote,
            'text': '${_dashboardData.newInquiries} quote requests pending',
          });
        }
        break;
    }

    // Add generic insights if no specific ones
    if (insights.isEmpty) {
      if (_dashboardData.todayRevenue > 0) {
        insights.add({
          'icon': Icons.insights,
          'text': 'Today\'s revenue: ₹${_formatAmount(_dashboardData.todayRevenue)}',
        });
      }
    }

    return insights.take(3).toList(); // Show max 3 insights
  }

  Widget _buildRevenueCard() {
    final weekRevenue = _dashboardData.weekRevenue;
    final monthRevenue = _dashboardData.monthRevenue;
    final revenueTitle = BusinessDashboardConfig.getRevenueTitle(_categoryGroup);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToAnalytics();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00D67D).withValues(alpha: 0.15),
              const Color(0xFF00D67D).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00D67D).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  revenueTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatAmount(weekRevenue)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Month',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_formatAmount(monthRevenue)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    final activityTitle = BusinessDashboardConfig.getActivityTitle(_categoryGroup);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              activityTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _navigateToInquiries();
              },
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseProvider.firestore
              .collection('businesses')
              .doc(widget.business.id)
              .collection('activity')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            final activities = snapshot.hasData && snapshot.data!.docs.isNotEmpty
                ? snapshot.data!.docs
                : null;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: activities == null
                  ? _buildEmptyActivity()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activities.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 60,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final activity = activities[index].data() as Map<String, dynamic>;
                        return _buildActivityItem(
                          icon: _getActivityIcon(activity['type'] ?? ''),
                          color: _getActivityColor(activity['type'] ?? ''),
                          title: activity['title'] ?? 'Activity',
                          subtitle: activity['subtitle'] ?? '',
                          time: _formatActivityTime(activity['timestamp']),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'Your business activities will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInquiries() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessInquiriesScreen(
          business: widget.business,
          initialFilter: 'All',
        ),
      ),
    );
  }

  void _navigateToOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdersTab(
          business: widget.business,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
  }

  void _navigateToMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuTab(
          business: widget.business,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
  }

  void _navigateToProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsTab(
          business: widget.business,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
  }

  void _navigateToRooms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomsTab(
          business: widget.business,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
  }

  void _navigateToServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessServicesTab(
          business: widget.business,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessAnalyticsScreen(business: widget.business),
      ),
    );
  }

  void _navigateToBookings() {
    // Navigate to appropriate bookings screen based on category
    if (_categoryGroup == CategoryGroup.hospitality) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingsTab(
            business: widget.business,
            onRefresh: widget.onRefresh,
          ),
        ),
      );
    } else {
      // For service-based categories (beauty, healthcare, fitness, education, etc.)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentsTab(
            business: widget.business,
            onRefresh: widget.onRefresh,
          ),
        ),
      );
    }
  }


  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'review':
        return Icons.star_outline;
      case 'booking':
        return Icons.calendar_today_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'order':
        return const Color(0xFF00D67D);
      case 'message':
        return const Color(0xFF42A5F5);
      case 'review':
        return const Color(0xFFFFA726);
      case 'booking':
        return const Color(0xFF7E57C2);
      default:
        return const Color(0xFF00D67D);
    }
  }

  String _formatActivityTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return timeago.format(timestamp.toDate(), locale: 'en_short');
    }
    return '';
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }


  int _getPendingItemsCount() {
    switch (_categoryGroup) {
      case CategoryGroup.food:
      case CategoryGroup.retail:
        return _dashboardData.pendingOrders;
      case CategoryGroup.hospitality:
        return _dashboardData.pendingOrders; // bookings
      case CategoryGroup.services:
      case CategoryGroup.fitness:
      case CategoryGroup.education:
      case CategoryGroup.professional:
      case CategoryGroup.creative:
        return _dashboardData.todayAppointments + _dashboardData.newInquiries;
      case CategoryGroup.events:
      case CategoryGroup.construction:
        return _dashboardData.pendingOrders + _dashboardData.newInquiries;
    }
  }

  /// Get date range based on selected filter
  Map<String, DateTime> _getDateRangeForFilter() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    switch (_selectedDateRange) {
      case DateRange.today:
        return {
          'start': todayStart,
          'end': todayStart.add(const Duration(days: 1)),
        };

      case DateRange.week:
        // Get start of week (Monday)
        final weekday = today.weekday;
        final weekStart = todayStart.subtract(Duration(days: weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return {
          'start': weekStart,
          'end': weekEnd,
        };

      case DateRange.month:
        // Get start of month
        final monthStart = DateTime(today.year, today.month, 1);
        final nextMonth = today.month == 12
            ? DateTime(today.year + 1, 1, 1)
            : DateTime(today.year, today.month + 1, 1);
        return {
          'start': monthStart,
          'end': nextMonth,
        };

      case DateRange.custom:
        // For now, default to today
        return {
          'start': todayStart,
          'end': todayStart.add(const Duration(days: 1)),
        };
    }
  }

  Future<Map<String, int>> _loadCategorySpecificData() async {
    final businessId = widget.business.id;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      switch (_categoryGroup) {
        case CategoryGroup.food:
          return await _loadFoodData(businessId);
        case CategoryGroup.retail:
          return await _loadRetailData(businessId);
        case CategoryGroup.hospitality:
          return await _loadHospitalityData(businessId, todayStart, todayEnd);
        case CategoryGroup.services:
          return await _loadServicesData(businessId, todayStart, todayEnd);
        case CategoryGroup.fitness:
          return await _loadFitnessData(businessId, todayStart, todayEnd);
        case CategoryGroup.education:
          return await _loadEducationData(businessId, todayStart, todayEnd);
        case CategoryGroup.professional:
          return await _loadProfessionalData(businessId, todayStart, todayEnd);
        case CategoryGroup.creative:
        case CategoryGroup.events:
        case CategoryGroup.construction:
          return await _loadServicesData(businessId, todayStart, todayEnd);
      }
    } catch (e) {
      debugPrint('Error loading category data: $e');
      return {};
    }
  }

  Future<Map<String, int>> _loadFoodData(String businessId) async {
    final preparingQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('orders')
        .where('status', isEqualTo: 'preparing')
        .count()
        .get();

    final deliveryQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('orders')
        .where('status', isEqualTo: 'delivery')
        .count()
        .get();

    return {
      'preparingOrders': preparingQuery.count ?? 0,
      'deliveryOrders': deliveryQuery.count ?? 0,
    };
  }

  Future<Map<String, int>> _loadRetailData(String businessId) async {
    final productsSnapshot = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .get();

    int totalItems = 0;
    int lowStockItems = 0;

    for (var doc in productsSnapshot.docs) {
      final data = doc.data();
      final quantity = data['quantity'] ?? 0;
      final minQuantity = data['minQuantity'] ?? 10;

      totalItems++;
      if (quantity < minQuantity) {
        lowStockItems++;
      }
    }

    return {
      'totalItems': totalItems,
      'lowStockItems': lowStockItems,
    };
  }

  Future<Map<String, int>> _loadHospitalityData(String businessId, DateTime todayStart, DateTime todayEnd) async {
    // Get date range based on filter
    final dateRange = _getDateRangeForFilter();
    final rangeStart = dateRange['start']!;
    final rangeEnd = dateRange['end']!;

    final roomsSnapshot = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('rooms')
        .get();

    int totalRooms = roomsSnapshot.docs.length;
    int occupiedRooms = roomsSnapshot.docs.where((doc) => doc.data()['status'] == 'occupied').length;
    int availableRooms = totalRooms - occupiedRooms;

    // Use filtered date range for check-ins/check-outs
    final checkInsQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('checkInDate', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final checkOutsQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('checkOutDate', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('checkOutDate', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    return {
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
      'todayCheckIns': checkInsQuery.count ?? 0,
      'todayCheckOuts': checkOutsQuery.count ?? 0,
    };
  }

  Future<Map<String, int>> _loadServicesData(String businessId, DateTime todayStart, DateTime todayEnd) async {
    // Get date range based on filter
    final dateRange = _getDateRangeForFilter();
    final rangeStart = dateRange['start']!;
    final rangeEnd = dateRange['end']!;

    final appointmentsQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('date', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final inquiriesQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inquiries')
        .where('status', isEqualTo: 'new')
        .count()
        .get();

    return {
      'todayAppointments': appointmentsQuery.count ?? 0,
      'newInquiries': inquiriesQuery.count ?? 0,
    };
  }

  Future<Map<String, int>> _loadFitnessData(String businessId, DateTime todayStart, DateTime todayEnd) async {
    // Get date range based on filter
    final dateRange = _getDateRangeForFilter();
    final rangeStart = dateRange['start']!;
    final rangeEnd = dateRange['end']!;

    final classesQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('classes')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('date', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final checkInsQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('member_checkins')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('timestamp', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    return {
      'todayAppointments': classesQuery.count ?? 0,  // Using 'appointments' field for classes
      'todayCheckIns': checkInsQuery.count ?? 0,
    };
  }

  Future<Map<String, int>> _loadEducationData(String businessId, DateTime todayStart, DateTime todayEnd) async {
    // Get date range based on filter
    final dateRange = _getDateRangeForFilter();
    final rangeStart = dateRange['start']!;
    final rangeEnd = dateRange['end']!;

    final classesQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('classes')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('date', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final attendanceQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('date', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final inquiriesQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inquiries')
        .where('status', isEqualTo: 'new')
        .count()
        .get();

    return {
      'todayAppointments': classesQuery.count ?? 0,
      'todayCheckIns': attendanceQuery.count ?? 0,
      'newInquiries': inquiriesQuery.count ?? 0,
    };
  }

  Future<Map<String, int>> _loadProfessionalData(String businessId, DateTime todayStart, DateTime todayEnd) async {
    // Get date range based on filter
    final dateRange = _getDateRangeForFilter();
    final rangeStart = dateRange['start']!;
    final rangeEnd = dateRange['end']!;

    final meetingsQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('meetings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('date', isLessThan: Timestamp.fromDate(rangeEnd))
        .count()
        .get();

    final inquiriesQuery = await FirebaseProvider.firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inquiries')
        .where('status', isEqualTo: 'new')
        .count()
        .get();

    return {
      'todayAppointments': meetingsQuery.count ?? 0,  // Using 'appointments' for meetings
      'newInquiries': inquiriesQuery.count ?? 0,
    };
  }

  /// Calculate trend percentage (today vs yesterday)
  Future<Map<String, double>> _calculateTrends(String businessId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final yesterdayEnd = todayStart;

      // Get yesterday's data based on category
      int yesterdayOrders = 0;
      double yesterdayRevenue = 0;
      int yesterdayAppointments = 0;

      switch (_categoryGroup) {
        case CategoryGroup.food:
        case CategoryGroup.retail:
          final ordersSnapshot = await FirebaseProvider.firestore
              .collection('businesses')
              .doc(businessId)
              .collection('orders')
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
              .where('createdAt', isLessThan: Timestamp.fromDate(yesterdayEnd))
              .get();

          yesterdayOrders = ordersSnapshot.docs.length;
          yesterdayRevenue = ordersSnapshot.docs.fold(0.0, (total, doc) =>
            total + ((doc.data()['total'] ?? 0) as num).toDouble()
          );
          break;

        case CategoryGroup.hospitality:
          final bookingsSnapshot = await FirebaseProvider.firestore
              .collection('businesses')
              .doc(businessId)
              .collection('bookings')
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
              .where('createdAt', isLessThan: Timestamp.fromDate(yesterdayEnd))
              .get();

          yesterdayOrders = bookingsSnapshot.docs.length;
          break;

        case CategoryGroup.services:
        case CategoryGroup.fitness:
        case CategoryGroup.education:
        case CategoryGroup.professional:
        case CategoryGroup.creative:
        case CategoryGroup.events:
        case CategoryGroup.construction:
          final appointmentsSnapshot = await FirebaseProvider.firestore
              .collection('businesses')
              .doc(businessId)
              .collection('appointments')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
              .where('date', isLessThan: Timestamp.fromDate(yesterdayEnd))
              .get();

          yesterdayAppointments = appointmentsSnapshot.docs.length;
          break;
      }

      // Calculate percentage change
      double ordersTrend = 0;
      double revenueTrend = 0;
      double appointmentsTrend = 0;

      if (yesterdayOrders > 0) {
        ordersTrend = ((_dashboardData.todayOrders - yesterdayOrders) / yesterdayOrders) * 100;
      } else if (_dashboardData.todayOrders > 0) {
        ordersTrend = 100; // All new orders
      }

      if (yesterdayRevenue > 0) {
        revenueTrend = ((_dashboardData.todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
      } else if (_dashboardData.todayRevenue > 0) {
        revenueTrend = 100;
      }

      if (yesterdayAppointments > 0) {
        appointmentsTrend = ((_dashboardData.todayAppointments - yesterdayAppointments) / yesterdayAppointments) * 100;
      } else if (_dashboardData.todayAppointments > 0) {
        appointmentsTrend = 100;
      }

      return {
        'ordersTrend': ordersTrend,
        'revenueTrend': revenueTrend,
        'appointmentsTrend': appointmentsTrend,
      };
    } catch (e) {
      debugPrint('Error calculating trends: $e');
      return {};
    }
  }

  /// Load historical data for charts (last 7 days)
  Future<Map<String, List<double>>> _loadHistoricalData(String businessId) async {
    try {
      final today = DateTime.now();
      final revenueHistory = <double>[];
      final ordersHistory = <double>[];

      for (int i = 6; i >= 0; i--) {
        final dayStart = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
        final dayEnd = dayStart.add(const Duration(days: 1));

        // Get day's orders and revenue
        final ordersSnapshot = await FirebaseProvider.firestore
            .collection('businesses')
            .doc(businessId)
            .collection('orders')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        ordersHistory.add(ordersSnapshot.docs.length.toDouble());

        final dayRevenue = ordersSnapshot.docs.fold(0.0, (total, doc) =>
          total + ((doc.data()['total'] ?? 0) as num).toDouble()
        );
        revenueHistory.add(dayRevenue);
      }

      return {
        'revenueHistory': revenueHistory,
        'ordersHistory': ordersHistory,
      };
    } catch (e) {
      debugPrint('Error loading historical data: $e');
      return {
        'revenueHistory': List.filled(7, 0.0),
        'ordersHistory': List.filled(7, 0.0),
      };
    }
  }

  /// Load trends and history (non-blocking background task)
  Future<void> _loadTrendsAndHistory(String businessId) async {
    try {
      final trends = await _calculateTrends(businessId);
      final history = await _loadHistoricalData(businessId);

      if (mounted) {
        setState(() {
          _dashboardData = DashboardData(
            totalOrders: _dashboardData.totalOrders,
            pendingOrders: _dashboardData.pendingOrders,
            completedOrders: _dashboardData.completedOrders,
            todayOrders: _dashboardData.todayOrders,
            todayRevenue: _dashboardData.todayRevenue,
            weekRevenue: _dashboardData.weekRevenue,
            monthRevenue: _dashboardData.monthRevenue,
            newInquiries: _dashboardData.newInquiries,
            respondedInquiries: _dashboardData.respondedInquiries,
            totalItems: _dashboardData.totalItems,
            lowStockItems: _dashboardData.lowStockItems,
            todayAppointments: _dashboardData.todayAppointments,
            pendingAppointments: _dashboardData.pendingAppointments,
            availableRooms: _dashboardData.availableRooms,
            totalRooms: _dashboardData.totalRooms,
            todayCheckIns: _dashboardData.todayCheckIns,
            todayCheckOuts: _dashboardData.todayCheckOuts,
            preparingOrders: _dashboardData.preparingOrders,
            deliveryOrders: _dashboardData.deliveryOrders,
            // Add trends
            ordersTrend: trends['ordersTrend'],
            revenueTrend: trends['revenueTrend'],
            appointmentsTrend: trends['appointmentsTrend'],
            // Add history
            revenueHistory: history['revenueHistory'] ?? [],
            ordersHistory: history['ordersHistory'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading trends and history: $e');
    }
  }
}
