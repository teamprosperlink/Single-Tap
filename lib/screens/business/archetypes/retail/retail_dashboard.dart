import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../models/business_model.dart';
import '../../../../models/product_model.dart';
import '../../../../models/business_order_model.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/app_components.dart';
import 'package:flutter/services.dart';
import '../../business_notifications_screen.dart';
import '../../business_orders_screen.dart';
import '../../business_analytics_screen.dart';
import '../../retail/product_form_screen.dart';
import 'inventory_tab.dart';
import 'product_list_tab.dart';

/// Retail Archetype Dashboard
/// For: Grocery, Retail categories
/// Features: Sales overview, product management, inventory tracking, orders
class RetailDashboard extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const RetailDashboard({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<RetailDashboard> createState() => _RetailDashboardState();
}

class _RetailDashboardState extends State<RetailDashboard> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  bool _isLoading = true;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _todayOrders = 0;
  double _todayRevenue = 0.0;
  List<ProductModel> _topProducts = [];
  List<BusinessOrderModel> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load statistics in parallel
      await Future.wait([
        _loadProductStats(),
        _loadOrderStats(),
        _loadTopProducts(),
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

  Future<void> _loadProductStats() async {
    final productsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('products')
        .get();

    int lowStock = 0;
    for (var doc in productsSnapshot.docs) {
      final product = ProductModel.fromFirestore(doc);
      if (product.stock < 10) {
        lowStock++;
      }
    }

    if (mounted) {
      setState(() {
        _totalProducts = productsSnapshot.size;
        _lowStockCount = lowStock;
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
    for (var doc in ordersSnapshot.docs) {
      final order = BusinessOrderModel.fromFirestore(doc);
      if (order.status != OrderStatus.cancelled) {
        revenue += order.totalAmount;
      }
    }

    if (mounted) {
      setState(() {
        _todayOrders = ordersSnapshot.size;
        _todayRevenue = revenue;
      });
    }
  }

  Future<void> _loadTopProducts() async {
    final productsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('products')
        .orderBy('salesCount', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _topProducts = productsSnapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
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
        color: const Color(0xFF00D67D),
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

                      // Low Stock Alert
                      if (_lowStockCount > 0) ...[
                        _buildLowStockAlert(isDarkMode),
                        const SizedBox(height: 24),
                      ],

                      // Top Products
                      _buildTopProducts(isDarkMode),
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
    return AppComponents.gradientHeader(
      title: 'Retail Dashboard',
      subtitle: DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      icon: Icons.store,
      gradientStart: AppTheme.retailGreen,
      gradientEnd: const Color(0xFF059669),
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
              icon: Icons.shopping_cart,
              label: 'Orders Today',
              value: _todayOrders.toString(),
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.attach_money,
              label: 'Revenue Today',
              value: '\$${_todayRevenue.toStringAsFixed(2)}',
              color: AppTheme.retailGreen,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.inventory_2,
              label: 'Total Products',
              value: _totalProducts.toString(),
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.warning_amber,
              label: 'Low Stock',
              value: _lowStockCount.toString(),
              color: _lowStockCount > 0 ? AppTheme.statusError : AppTheme.retailGreen,
              isDarkMode: isDarkMode,
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
              label: 'Add Product',
              color: AppTheme.retailGreen,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(businessId: widget.business.id, onSaved: () { _loadDashboardData(); widget.onRefresh(); })));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.inventory,
              label: 'Manage Inventory',
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Inventory')), body: InventoryTab(business: widget.business, onRefresh: widget.onRefresh))));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.receipt_long,
              label: 'View Orders',
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessOrdersScreen(business: widget.business)));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.analytics,
              label: 'Analytics',
              color: AppTheme.menuAmber,
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

  Widget _buildLowStockAlert(bool isDarkMode) {
    return AppComponents.alertBanner(
      title: 'Low Stock Alert',
      message: '$_lowStockCount products are running low on stock',
      icon: Icons.warning_amber,
      color: AppTheme.statusError,
      isDarkMode: isDarkMode,
      actionLabel: 'View',
      onAction: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Inventory')), body: InventoryTab(business: widget.business, onRefresh: widget.onRefresh))));
      },
    );
  }

  Widget _buildTopProducts(bool isDarkMode) {
    if (_topProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Top Products',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('All Products')), body: ProductListTab(business: widget.business, onRefresh: widget.onRefresh))));
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _topProducts.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing12),
          itemBuilder: (context, index) {
            final product = _topProducts[index];
            return _buildProductCard(product, isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product, bool isDarkMode) {
    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.images.isNotEmpty
                ? Image.network(
                    product.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.inventory_2, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock: ${product.stock}',
                  style: TextStyle(
                    fontSize: 12,
                    color: product.stock < 10
                        ? const Color(0xFFEF4444)
                        : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.salesCount} sold',
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
