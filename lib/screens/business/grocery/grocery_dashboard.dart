/// Grocery-specific dashboard with inventory tracking by weight, perishables, and expiry dates
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supper/services/firebase_provider.dart';
import '../retail/product_form_screen.dart';
import '../retail/product_category_screen.dart';

class GroceryDashboard extends StatefulWidget {
  final String businessId;

  const GroceryDashboard({super.key, required this.businessId});

  @override
  State<GroceryDashboard> createState() => _GroceryDashboardState();
}

class _GroceryDashboardState extends State<GroceryDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadGroceryStats();
  }

  Future<void> _loadGroceryStats() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseProvider.firestore;

      // Get all products for this grocery business
      final productsSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('products')
          .get();

      int totalProducts = productsSnapshot.docs.length;
      int lowStockCount = 0;
      int expiringCount = 0;
      int perishableCount = 0;
      double totalInventoryValue = 0;

      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final stock = data['stock'] as num? ?? 0;
        final minStock = data['minStock'] as num? ?? 5;
        final price = data['price'] as num? ?? 0;
        final expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();
        final isPerishable = data['isPerishable'] as bool? ?? false;

        // Low stock check
        if (stock <= minStock) {
          lowStockCount++;
        }

        // Expiring soon check (within 7 days)
        if (expiryDate != null && expiryDate.isBefore(weekFromNow)) {
          expiringCount++;
        }

        // Perishable count
        if (isPerishable) {
          perishableCount++;
        }

        // Total inventory value
        totalInventoryValue += (stock * price);
      }

      // Get today's orders
      final ordersSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(
              DateTime(now.year, now.month, now.day),
            ),
          )
          .get();

      final todayOrders = ordersSnapshot.docs.length;
      double todayRevenue = 0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final total = data['total'] as num? ?? 0;
        todayRevenue += total;
      }

      setState(() {
        _stats = {
          'totalProducts': totalProducts,
          'lowStockCount': lowStockCount,
          'expiringCount': expiringCount,
          'perishableCount': perishableCount,
          'inventoryValue': totalInventoryValue,
          'todayOrders': todayOrders,
          'todayRevenue': todayRevenue,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading grocery stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    final totalProducts = _stats['totalProducts'] ?? 0;
    final lowStockCount = _stats['lowStockCount'] ?? 0;
    final expiringCount = _stats['expiringCount'] ?? 0;
    final perishableCount = _stats['perishableCount'] ?? 0;
    final inventoryValue = _stats['inventoryValue'] ?? 0.0;
    final todayOrders = _stats['todayOrders'] ?? 0;
    final todayRevenue = _stats['todayRevenue'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadGroceryStats,
      color: const Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Grocery Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time inventory and sales overview',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  title: 'Total Products',
                  value: totalProducts.toString(),
                  icon: Icons.inventory_2,
                  color: const Color(0xFF10B981),
                  subtitle: '$perishableCount perishable',
                ),
                _buildStatCard(
                  title: 'Low Stock',
                  value: lowStockCount.toString(),
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                  subtitle: 'Need restock',
                  onTap: () => _navigateToLowStock(context),
                ),
                _buildStatCard(
                  title: 'Expiring Soon',
                  value: expiringCount.toString(),
                  icon: Icons.schedule,
                  color: Colors.red,
                  subtitle: 'Within 7 days',
                  onTap: () => _navigateToExpiringSoon(context),
                ),
                _buildStatCard(
                  title: 'Inventory Value',
                  value: '\$${inventoryValue.toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  color: const Color(0xFF3B82F6),
                  subtitle: 'Total stock value',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Today's Performance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.today, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        'Today\'s Performance',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTodayStat(
                        label: 'Orders',
                        value: todayOrders.toString(),
                        icon: Icons.shopping_cart,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildTodayStat(
                        label: 'Revenue',
                        value: '\$${todayRevenue.toStringAsFixed(0)}',
                        icon: Icons.payments,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionChip(
                  label: 'Add Product',
                  icon: Icons.add_box,
                  color: const Color(0xFF10B981),
                  onTap: () => _addProduct(context),
                ),
                _buildQuickActionChip(
                  label: 'View Orders',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _viewOrders(context),
                ),
                _buildQuickActionChip(
                  label: 'Manage Categories',
                  icon: Icons.category,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _manageCategories(context),
                ),
                _buildQuickActionChip(
                  label: 'Price Tags',
                  icon: Icons.local_offer,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _printPriceTags(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: onTap != null
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  void _navigateToLowStock(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Low Stock Items'),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseProvider.firestore
                .collection('businesses')
                .doc(widget.businessId)
                .collection('products')
                .orderBy('stock')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final stock = data['stock'] as num? ?? 0;
                final minStock = data['minStock'] as num? ?? 5;
                return stock <= minStock;
              }).toList();
              if (docs.isEmpty) {
                return const Center(child: Text('No low stock items'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Unnamed';
                  final stock = data['stock'] as num? ?? 0;
                  final minStock = data['minStock'] as num? ?? 5;
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                      ),
                      title: Text(name),
                      subtitle: Text('Stock: $stock / Min: $minStock'),
                      trailing: Icon(
                        Icons.circle,
                        size: 12,
                        color: stock == 0 ? Colors.red : Colors.orange,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToExpiringSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    final weekFromNow = DateTime.now().add(const Duration(days: 7));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Expiring Soon'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseProvider.firestore
                .collection('businesses')
                .doc(widget.businessId)
                .collection('products')
                .where(
                  'expiryDate',
                  isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow),
                )
                .orderBy('expiryDate')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No items expiring soon'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Unnamed';
                  final expiryDate = (data['expiryDate'] as Timestamp?)
                      ?.toDate();
                  final isExpired =
                      expiryDate != null && expiryDate.isBefore(DateTime.now());
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isExpired ? Icons.error : Icons.schedule,
                        color: isExpired ? Colors.red : Colors.orange,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        expiryDate != null
                            ? '${isExpired ? "Expired" : "Expires"}: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}'
                            : 'No expiry date',
                      ),
                      trailing: isExpired
                          ? const Chip(
                              label: Text('Expired'),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _addProduct(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          businessId: widget.businessId,
          onSaved: () {
            _loadGroceryStats();
          },
        ),
      ),
    );
  }

  void _viewOrders(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Orders'),
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseProvider.firestore
                .collection('businesses')
                .doc(widget.businessId)
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No orders yet'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final total = data['total'] as num? ?? 0;
                  final status = data['status'] as String? ?? 'pending';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final customerName =
                      data['customerName'] as String? ?? 'Customer';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        status == 'completed'
                            ? Icons.check_circle
                            : Icons.receipt_long,
                        color: status == 'completed'
                            ? Colors.green
                            : const Color(0xFF3B82F6),
                      ),
                      title: Text(customerName),
                      subtitle: Text(
                        createdAt != null
                            ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                            : 'Unknown date',
                      ),
                      trailing: Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _manageCategories(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCategoryScreen(businessId: widget.businessId),
      ),
    );
  }

  void _printPriceTags(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Price tag printing will be available in a future update.',
        ),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
  }
}
