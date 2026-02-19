import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderTrackingScreen({super.key, required this.orderData});

  Color _getCategoryColor() {
    return const Color(0xFF016CFF);
  }

  IconData _getCategoryIcon() {
    switch (orderData['category'] as String? ?? '') {
      case 'food':
        return Icons.fastfood;
      case 'electric':
        return Icons.devices;
      case 'house':
        return Icons.home;
      case 'place':
        return Icons.place;
      default:
        return Icons.shopping_bag;
    }
  }

  String _getDeliveryLabel() {
    switch (orderData['category'] as String? ?? '') {
      case 'food':
        return 'Delivery';
      case 'electric':
        return 'Shipping';
      case 'house':
        return 'Visit';
      case 'place':
        return 'Booking';
      default:
        return 'Delivery';
    }
  }

  List<Map<String, dynamic>> _getTimelineSteps() {
    final statusTimestamps =
        orderData['statusTimestamps'] as Map<String, dynamic>? ?? {};
    final hasPlaced = statusTimestamps['placed'] != null;
    final hasConfirmed = statusTimestamps['confirmed'] != null;
    final hasPreparing = statusTimestamps['preparing'] != null;
    final hasShipped = statusTimestamps['shipped'] != null;
    final hasDelivered = statusTimestamps['delivered'] != null;

    switch (orderData['category'] as String? ?? '') {
      case 'food':
        return [
          {
            'title': 'Order Placed',
            'subtitle': _formatTimestamp(statusTimestamps['placed']),
            'done': hasPlaced,
          },
          {
            'title': 'Restaurant Notified',
            'subtitle':
                hasConfirmed ? _formatTimestamp(statusTimestamps['confirmed']) : 'Pending',
            'done': hasConfirmed,
          },
          {
            'title': 'Preparing Food',
            'subtitle': hasPreparing
                ? _formatTimestamp(statusTimestamps['preparing'])
                : '~15 min',
            'done': hasPreparing,
          },
          {
            'title': 'Out for Delivery',
            'subtitle': hasShipped
                ? _formatTimestamp(statusTimestamps['shipped'])
                : '~30 min',
            'done': hasShipped || hasDelivered,
          },
        ];
      case 'electric':
        return [
          {
            'title': 'Order Placed',
            'subtitle': _formatTimestamp(statusTimestamps['placed']),
            'done': hasPlaced,
          },
          {
            'title': 'Seller Notified',
            'subtitle':
                hasConfirmed ? _formatTimestamp(statusTimestamps['confirmed']) : 'Processing',
            'done': hasConfirmed,
          },
          {
            'title': 'Shipped',
            'subtitle': hasShipped
                ? _formatTimestamp(statusTimestamps['shipped'])
                : '~1-2 days',
            'done': hasShipped,
          },
          {
            'title': 'Delivered',
            'subtitle': hasDelivered
                ? _formatTimestamp(statusTimestamps['delivered'])
                : '~3-5 days',
            'done': hasDelivered,
          },
        ];
      case 'house':
        return [
          {
            'title': 'Booking Placed',
            'subtitle': _formatTimestamp(statusTimestamps['placed']),
            'done': hasPlaced,
          },
          {
            'title': 'Owner Notified',
            'subtitle':
                hasConfirmed ? _formatTimestamp(statusTimestamps['confirmed']) : 'Confirming',
            'done': hasConfirmed,
          },
          {
            'title': 'Visit Scheduled',
            'subtitle': hasPreparing
                ? _formatTimestamp(statusTimestamps['preparing'])
                : 'Within 24 hrs',
            'done': hasPreparing,
          },
          {
            'title': 'Visit Confirmed',
            'subtitle': hasDelivered
                ? _formatTimestamp(statusTimestamps['delivered'])
                : 'Pending',
            'done': hasDelivered,
          },
        ];
      case 'place':
        return [
          {
            'title': 'Booking Placed',
            'subtitle': _formatTimestamp(statusTimestamps['placed']),
            'done': hasPlaced,
          },
          {
            'title': 'Payment Verified',
            'subtitle':
                hasConfirmed ? _formatTimestamp(statusTimestamps['confirmed']) : 'Confirming',
            'done': hasConfirmed,
          },
          {
            'title': 'Booking Confirmed',
            'subtitle': hasPreparing
                ? _formatTimestamp(statusTimestamps['preparing'])
                : 'Instant',
            'done': hasPreparing,
          },
          {
            'title': 'E-Ticket Generated',
            'subtitle': hasDelivered
                ? _formatTimestamp(statusTimestamps['delivered'])
                : 'Pending',
            'done': hasDelivered,
          },
        ];
      default:
        return [
          {
            'title': 'Order Placed',
            'subtitle': _formatTimestamp(statusTimestamps['placed']),
            'done': hasPlaced,
          },
          {
            'title': 'Processing',
            'subtitle':
                hasConfirmed ? _formatTimestamp(statusTimestamps['confirmed']) : 'In progress',
            'done': hasConfirmed,
          },
          {
            'title': 'Shipped',
            'subtitle': hasShipped
                ? _formatTimestamp(statusTimestamps['shipped'])
                : 'Pending',
            'done': hasShipped,
          },
          {
            'title': 'Delivered',
            'subtitle': hasDelivered
                ? _formatTimestamp(statusTimestamps['delivered'])
                : 'Pending',
            'done': hasDelivered,
          },
        ];
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Just now';
    if (ts is Timestamp) {
      final date = ts.toDate();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final min = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]}, $hour:$min $amPm';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();
    final orderId = orderData['orderId'] as String? ?? '';
    final status = orderData['status'] as String? ?? 'confirmed';
    final estimatedDelivery =
        orderData['estimatedDelivery'] as String? ?? '30-40 min';
    final totalAmount =
        (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
    final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (orderData['discount'] as num?)?.toDouble() ?? 0;
    final deliveryFee =
        (orderData['deliveryFee'] as num?)?.toDouble() ?? 0;
    final platformFee =
        (orderData['platformFee'] as num?)?.toDouble() ?? 5;
    final quantity = orderData['quantity'] as int? ?? 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(64, 64, 64, 1),
                  Color.fromRGBO(0, 0, 0, 1),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Order Details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                // White line below app bar
                Container(height: 1, color: Colors.white),

                const SizedBox(height: 8),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // Order ID Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_outlined,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '#$orderId',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getStatusLabel(status),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Estimated Delivery Card
                        _buildGlassCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.timer_outlined,
                                    color: color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Est. ${_getDeliveryLabel()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      estimatedDelivery,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Order Timeline
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ..._buildTimeline(color),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Product Info Card
                        _buildGlassCard(
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Image.network(
                                    orderData['itemImage'] as String? ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: color.withValues(alpha: 0.2),
                                      child: Icon(_getCategoryIcon(),
                                          color: color, size: 28),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderData['itemName'] as String? ??
                                          'Product',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${orderData['subtitle'] ?? ''} x$quantity',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    orderData['paymentMethod'] as String? ??
                                        'Google Pay',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Delivery Info Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildGlassCard(
                                child: Column(
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        color: color, size: 24),
                                    const SizedBox(height: 8),
                                    Text(
                                      estimatedDelivery,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Est. ${_getDeliveryLabel()}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGlassCard(
                                child: Column(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        color: color, size: 24),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Park Street',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Hyderabad',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Payment Summary
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildPriceRow('Subtotal',
                                  '₹${subtotal.toStringAsFixed(0)}'),
                              const SizedBox(height: 8),
                              _buildPriceRow('Discount',
                                  '-₹${discount.toStringAsFixed(0)}',
                                  isGreen: true),
                              const SizedBox(height: 8),
                              _buildPriceRow('Delivery Fee',
                                  deliveryFee > 0
                                      ? '₹${deliveryFee.toStringAsFixed(0)}'
                                      : 'FREE',
                                  isGreen: deliveryFee == 0),
                              const SizedBox(height: 8),
                              _buildPriceRow('Platform Fee',
                                  '₹${platformFee.toStringAsFixed(0)}'),
                              const SizedBox(height: 10),
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Back to Orders',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'placed':
        return 'Placed';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  Widget _buildPriceRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isGreen ? Colors.green[400] : Colors.white,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTimeline(Color color) {
    final steps = _getTimelineSteps();
    final List<Widget> widgets = [];

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isDone = step['done'] as bool;
      final isLast = i == steps.length - 1;

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot + line
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? color
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isDone
                            ? color
                            : Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      boxShadow: isDone
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 12, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 30,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: isDone
                          ? color.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Step content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isDone ? FontWeight.w600 : FontWeight.w400,
                        color: isDone ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone ? color : Colors.grey[700],
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

    return widgets;
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
