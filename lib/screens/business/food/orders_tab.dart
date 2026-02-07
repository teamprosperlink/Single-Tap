import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/menu_model.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';

/// Tab for viewing and managing food orders
class OrdersTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const OrdersTab({
    super.key,
    required this.business,
    this.onRefresh,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final BusinessService _businessService = BusinessService();
  String _filterStatus = 'all';

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
            Expanded(child: _buildOrdersList(isDarkMode)),
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
              Icons.receipt_long_rounded,
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
                  'Orders',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Manage customer orders',
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
            label: 'Preparing',
            isSelected: _filterStatus == 'preparing',
            onTap: () => setState(() => _filterStatus = 'preparing'),
            isDarkMode: isDarkMode,
            iconData: Icons.restaurant,
            iconColor: Colors.blue,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Ready',
            isSelected: _filterStatus == 'ready',
            onTap: () => setState(() => _filterStatus = 'ready'),
            isDarkMode: isDarkMode,
            iconData: Icons.check_circle_outline,
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

  Widget _buildOrdersList(bool isDarkMode) {
    return StreamBuilder<List<FoodOrderModel>>(
      stream: _businessService.watchFoodOrders(widget.business.id),
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
                  'Error loading orders',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final allOrders = snapshot.data ?? [];
        final orders = _filterOrders(allOrders);

        if (orders.isEmpty) {
          return _buildEmptyState(isDarkMode, allOrders.isEmpty);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _OrderCard(
              order: order,
              isDarkMode: isDarkMode,
              onStatusChange: (status) => _updateOrderStatus(order, status),
            );
          },
        );
      },
    );
  }

  List<FoodOrderModel> _filterOrders(List<FoodOrderModel> orders) {
    if (_filterStatus == 'all') return orders;
    final status = FoodOrderStatus.fromString(_filterStatus);
    if (status == null) return orders;
    return orders.where((o) => o.status == status).toList();
  }

  Widget _buildEmptyState(bool isDarkMode, bool noOrdersAtAll) {
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
              noOrdersAtAll ? Icons.receipt_long_outlined : Icons.search_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            noOrdersAtAll ? 'No Orders Yet' : 'No Matching Orders',
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
              noOrdersAtAll
                  ? 'Orders will appear here when customers place them'
                  : 'Try a different filter to find orders',
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

  Future<void> _updateOrderStatus(FoodOrderModel order, FoodOrderStatus status) async {
    try {
      await _businessService.updateFoodOrderStatus(
        widget.business.id,
        order.id,
        status,
      );
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
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

class _OrderCard extends StatelessWidget {
  final FoodOrderModel order;
  final bool isDarkMode;
  final Function(FoodOrderStatus) onStatusChange;

  const _OrderCard({
    required this.order,
    required this.isDarkMode,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
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
            // Header with order number and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${timeFormat.format(order.createdAt)} • ${dateFormat.format(order.createdAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),
            // Order type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getOrderTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getOrderTypeIcon(),
                        size: 14,
                        color: _getOrderTypeColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.orderType.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getOrderTypeColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Customer info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.1),
                    child: Text(
                      order.customerName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00D67D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          order.customerPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.phone,
                      color: const Color(0xFF00D67D),
                    ),
                    onPressed: () {
                      // TODO: Call customer
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Order items
            Text(
              'Items (${order.totalItems})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D67D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '\u20B9${item.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
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
                        order.notes!,
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
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '\u20B9${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D67D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;

    switch (order.status) {
      case FoodOrderStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case FoodOrderStatus.confirmed:
        color = Colors.blue;
        label = 'Confirmed';
        break;
      case FoodOrderStatus.preparing:
        color = Colors.purple;
        label = 'Preparing';
        break;
      case FoodOrderStatus.ready:
        color = Colors.green;
        label = 'Ready';
        break;
      case FoodOrderStatus.outForDelivery:
        color = Colors.teal;
        label = 'Out for Delivery';
        break;
      case FoodOrderStatus.delivered:
      case FoodOrderStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case FoodOrderStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
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

  Color _getOrderTypeColor() {
    switch (order.orderType) {
      case OrderType.dineIn:
        return Colors.blue;
      case OrderType.takeaway:
        return Colors.orange;
      case OrderType.delivery:
        return Colors.green;
    }
  }

  IconData _getOrderTypeIcon() {
    switch (order.orderType) {
      case OrderType.dineIn:
        return Icons.restaurant;
      case OrderType.takeaway:
        return Icons.shopping_bag_outlined;
      case OrderType.delivery:
        return Icons.delivery_dining;
    }
  }

  Widget _buildActionButtons() {
    switch (order.status) {
      case FoodOrderStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onStatusChange(FoodOrderStatus.cancelled),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => onStatusChange(FoodOrderStatus.confirmed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Accept'),
              ),
            ),
          ],
        );
      case FoodOrderStatus.confirmed:
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(FoodOrderStatus.preparing),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.restaurant, size: 18),
          label: const Text('Start Preparing'),
        );
      case FoodOrderStatus.preparing:
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(FoodOrderStatus.ready),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Mark Ready'),
        );
      case FoodOrderStatus.ready:
        if (order.orderType == OrderType.delivery) {
          return ElevatedButton.icon(
            onPressed: () => onStatusChange(FoodOrderStatus.outForDelivery),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delivery_dining, size: 18),
            label: const Text('Out for Delivery'),
          );
        }
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(FoodOrderStatus.completed),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Complete Order'),
        );
      case FoodOrderStatus.outForDelivery:
        return ElevatedButton.icon(
          onPressed: () => onStatusChange(FoodOrderStatus.delivered),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark Delivered'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
