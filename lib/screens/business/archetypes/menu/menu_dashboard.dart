import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../models/business_model.dart';
import '../../../../models/menu_model.dart';
import '../../../../models/business_order_model.dart';
import '../../../../models/business_category_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/app_components.dart';
import 'package:flutter/services.dart';
import '../../business_notifications_screen.dart';
import '../../business_orders_screen.dart';
import '../../business_analytics_screen.dart';
import '../../food/menu_item_form_screen.dart';
import '../../food/menu_tab.dart';
import '../../appointments/appointments_tab.dart';

/// Menu Archetype Dashboard
/// For: Food & Beverage, Beauty & Wellness, Automotive categories
/// Features: Orders overview, menu management, bookings (for services)
class MenuDashboard extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const MenuDashboard({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<MenuDashboard> createState() => _MenuDashboardState();
}

class _MenuDashboardState extends State<MenuDashboard> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  bool _isLoading = true;
  int _totalMenuItems = 0;
  int _todayOrders = 0;
  double _todayRevenue = 0.0;
  int _pendingOrders = 0;
  List<MenuItemModel> _popularItems = [];
  List<BusinessOrderModel> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadMenuStats(),
        _loadOrderStats(),
        _loadPopularItems(),
        _loadRecentOrders(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMenuStats() async {
    final menuSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('menu_items')
        .get();

    if (mounted) {
      setState(() {
        _totalMenuItems = menuSnapshot.size;
      });
    }
  }

  Future<void> _loadOrderStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final ordersSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();

    double revenue = 0.0;
    int pending = 0;

    for (var doc in ordersSnapshot.docs) {
      final order = BusinessOrderModel.fromFirestore(doc);
      if (order.status != OrderStatus.cancelled) {
        revenue += order.totalAmount;
      }
      if (order.status == OrderStatus.pending || order.status == OrderStatus.accepted) {
        pending++;
      }
    }

    if (mounted) {
      setState(() {
        _todayOrders = ordersSnapshot.size;
        _todayRevenue = revenue;
        _pendingOrders = pending;
      });
    }
  }

  Future<void> _loadPopularItems() async {
    final menuSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('menu_items')
        .orderBy('orderCount', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _popularItems = menuSnapshot.docs
            .map((doc) => MenuItemModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    final ordersSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _recentOrders = ordersSnapshot.docs
            .map((doc) => BusinessOrderModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  String get _categoryDisplayName {
    switch (widget.business.category) {
      case BusinessCategory.foodBeverage:
        return 'Restaurant';
      case BusinessCategory.beautyWellness:
        return 'Salon & Spa';
      case BusinessCategory.automotive:
        return 'Auto Service';
      default:
        return 'Menu';
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
          widget.onRefresh();
        },
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppTheme.cardColor(isDarkMode),
              elevation: 0,
              pinned: true,
              title: Text(
                widget.business.businessName,
                style: TextStyle(
                  color: AppTheme.textPrimary(isDarkMode),
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.fontSizeLarge,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textPrimary(isDarkMode),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessNotificationsScreen()));
                  },
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D67D)),
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

                      // Stats Overview
                      _buildStatsOverview(isDarkMode),
                      const SizedBox(height: 24),

                      // Quick Actions
                      _buildQuickActions(isDarkMode),
                      const SizedBox(height: 24),

                      // Pending Orders Alert
                      if (_pendingOrders > 0) ...[
                        _buildPendingOrdersAlert(isDarkMode),
                        const SizedBox(height: 24),
                      ],

                      // Popular Items
                      _buildPopularItems(isDarkMode),
                      const SizedBox(height: 24),

                      // Recent Orders
                      _buildRecentOrders(isDarkMode),
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
    IconData categoryIcon = widget.business.category == BusinessCategory.foodBeverage
        ? Icons.restaurant
        : widget.business.category == BusinessCategory.beautyWellness
            ? Icons.spa
            : Icons.directions_car;

    return AppComponents.gradientHeader(
      title: '$_categoryDisplayName Dashboard',
      subtitle: DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      icon: categoryIcon,
      gradientStart: AppTheme.menuAmber,
      gradientEnd: const Color(0xFFEA580C),
    );
  }

  Widget _buildStatsOverview(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Today\'s Overview',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: AppTheme.spacing12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacing12,
          crossAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 1.5,
          children: [
            AppComponents.statsCard(
              icon: Icons.receipt_long,
              label: 'Orders Today',
              value: _todayOrders.toString(),
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.attach_money,
              label: 'Revenue Today',
              value: '\$${_todayRevenue.toStringAsFixed(2)}',
              color: AppTheme.statusSuccess,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.pending_actions,
              label: 'Pending Orders',
              value: _pendingOrders.toString(),
              color: _pendingOrders > 0 ? AppTheme.menuAmber : AppTheme.statusSuccess,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.restaurant_menu,
              label: 'Menu Items',
              value: _totalMenuItems.toString(),
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    final isServiceBased = widget.business.category == BusinessCategory.beautyWellness ||
        widget.business.category == BusinessCategory.automotive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Quick Actions',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: AppTheme.spacing12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacing12,
          crossAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 2,
          children: [
            AppComponents.actionButton(
              icon: Icons.add_box,
              label: isServiceBased ? 'Add Service' : 'Add Menu Item',
              color: AppTheme.menuAmber,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => MenuItemFormScreen(businessId: widget.business.id, onSaved: () { _loadDashboardData(); widget.onRefresh(); })));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.list_alt,
              label: 'View Orders',
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessOrdersScreen(business: widget.business)));
              },
            ),
            if (isServiceBased)
              AppComponents.actionButton(
                icon: Icons.calendar_today,
                label: 'Appointments',
                color: AppTheme.portfolioPurple,
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentsTab(business: widget.business, onRefresh: () { _loadDashboardData(); widget.onRefresh(); })));
                },
              )
            else
              AppComponents.actionButton(
                icon: Icons.restaurant_menu,
                label: 'Manage Menu',
                color: AppTheme.portfolioPurple,
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MenuTab(business: widget.business, onRefresh: () { _loadDashboardData(); widget.onRefresh(); })));
                },
              ),
            AppComponents.actionButton(
              icon: Icons.analytics,
              label: 'Analytics',
              color: AppTheme.retailGreen,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessAnalyticsScreen(business: widget.business)));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingOrdersAlert(bool isDarkMode) {
    return AppComponents.alertBanner(
      title: 'Pending Orders',
      message: '$_pendingOrders orders waiting for action',
      icon: Icons.pending_actions,
      color: AppTheme.statusWarning,
      isDarkMode: isDarkMode,
      actionLabel: 'View',
      onAction: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessOrdersScreen(business: widget.business, initialFilter: 'Pending')));
      },
    );
  }

  Widget _buildPopularItems(bool isDarkMode) {
    if (_popularItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Popular Items',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => MenuTab(business: widget.business, onRefresh: () { _loadDashboardData(); widget.onRefresh(); })));
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _popularItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing12),
          itemBuilder: (context, index) {
            final item = _popularItems[index];
            return _buildMenuItemCard(item, isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(MenuItemModel item, bool isDarkMode) {
    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant_menu, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.orderCount} orders',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(bool isDarkMode) {
    if (_recentOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Recent Orders',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessOrdersScreen(business: widget.business)));
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentOrders.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing12),
          itemBuilder: (context, index) {
            final order = _recentOrders[index];
            return _buildOrderCard(order, isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildOrderCard(BusinessOrderModel order, bool isDarkMode) {
    Color statusColor;
    switch (order.status) {
      case OrderStatus.pending:
      case OrderStatus.newOrder:
        statusColor = AppTheme.statusWarning;
        break;
      case OrderStatus.accepted:
      case OrderStatus.inProgress:
        statusColor = AppTheme.appointmentBlue;
        break;
      case OrderStatus.completed:
        statusColor = AppTheme.statusSuccess;
        break;
      case OrderStatus.cancelled:
        statusColor = AppTheme.statusError;
        break;
      default:
        statusColor = Colors.grey;
    }

    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppComponents.statusBadge(
                    text: order.statusName.toUpperCase(),
                    color: statusColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: isDarkMode ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, h:mm a').format(order.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.shopping_bag,
                size: 14,
                color: isDarkMode ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                '${order.items.length} items',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
