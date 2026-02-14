import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supper/screens/home/product/confirming_order_screen.dart';

class OrderSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  final String category;
  final int quantity;

  const OrderSummaryScreen({
    super.key,
    required this.item,
    required this.category,
    this.quantity = 1,
  });

  Color _getCategoryColor() {
    return const Color(0xFF016CFF);
  }

  IconData _getCategoryIcon() {
    switch (category) {
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

  String _getSubtitle() {
    switch (category) {
      case 'food':
        return item['restaurant'] as String? ?? '';
      case 'electric':
        return item['brand'] as String? ?? '';
      case 'house':
      case 'place':
        return item['location'] as String? ?? '';
      default:
        return '';
    }
  }

  double _parsePrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  String _getButtonLabel() {
    switch (category) {
      case 'food':
        return 'Confirm & Pay';
      case 'electric':
        return 'Confirm & Pay';
      case 'house':
        return 'Confirm Booking';
      case 'place':
        return 'Confirm & Book';
      default:
        return 'Confirm & Pay';
    }
  }

  String _getDeliveryLabel() {
    switch (category) {
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

  String _getDeliveryTime() {
    switch (category) {
      case 'food':
        return '30-40 Min';
      case 'electric':
        return '3-5 Days';
      case 'house':
        return 'Within 24 hrs';
      case 'place':
        return 'Instant';
      default:
        return '30-40 Min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceStr = item['price'] as String? ?? '₹0';
    final unitPrice = _parsePrice(priceStr);
    final subtotal = unitPrice * quantity;
    final discount = (subtotal * 0.2).round();
    const platformFee = 5;
    final deliveryFee = category == 'food' ? 25 : 0;
    final total = subtotal - discount + platformFee + deliveryFee;
    final color = _getCategoryColor();
    final rating = item['rating'];
    final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

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
                          'Order Summary',
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
                Container(
                  height: 1,
                  color: Colors.white,
                ),

                // Step Indicator
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: _buildStepIndicator(1, color),
                ),

                const SizedBox(height: 8),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

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
                              const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Order #$orderId',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Product Card
                      _buildGlassCard(
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Image.network(
                                  item['image'] as String? ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: color.withValues(alpha: 0.2),
                                    child: Icon(_getCategoryIcon(),
                                        color: color, size: 32),
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
                                    item['name'] as String? ?? 'Product',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _getSubtitle(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (rating != null) ...[
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 15),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$rating',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[600],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        'Qty: $quantity',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              priceStr,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Delivery & Payment Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.location_on_rounded,
                                        color: color, size: 18),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${_getDeliveryLabel()} Address',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    '789, Park Street',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Hyderabad',
                                    style: TextStyle(
                                      fontSize: 12,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.greenAccent,
                                        size: 18),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Payment',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Google Pay',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '****5678',
                                    style: TextStyle(
                                      fontSize: 12,
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

                      // Delivery Time Card
                      _buildGlassCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.2),
                                    color.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.timer_outlined,
                                  color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estimated ${_getDeliveryLabel()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getDeliveryTime(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      color: Colors.greenAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'On Time',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Price Breakdown
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
                            _priceRow(
                              'Item Total ($quantity item${quantity > 1 ? 's' : ''})',
                              '₹${subtotal.toStringAsFixed(0)}',
                            ),
                            const SizedBox(height: 10),
                            _priceRow(
                              'Discount (20%)',
                              '-₹$discount',
                              valueColor: Colors.greenAccent,
                            ),
                            const SizedBox(height: 10),
                            _priceRow(
                              '${_getDeliveryLabel()} Fee',
                              deliveryFee > 0 ? '₹$deliveryFee' : 'FREE',
                              valueColor:
                                  deliveryFee == 0 ? Colors.greenAccent : null,
                            ),
                            const SizedBox(height: 10),
                            _priceRow('Platform Fee', '₹$platformFee'),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.15),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Amount to Pay',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    Colors.greenAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.greenAccent
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.savings_outlined,
                                      color: Colors.greenAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total savings ₹$discount',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.celebration_outlined,
                                      color: Colors.greenAccent, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Secure Payment Banner
                      _buildGlassCard(
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Colors.grey[500], size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your payment is secured with 256-bit encryption',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                            Icon(Icons.lock_outline,
                                color: Colors.grey[600], size: 16),
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
                top:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmingOrderScreen(
                      item: item,
                      category: category,
                      quantity: quantity,
                      orderId: orderId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF016CFF),
                      const Color(0xFF016CFF).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF016CFF).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${_getButtonLabel()} ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
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

  Widget _priceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int currentStep, Color color) {
    final steps = ['Checkout', 'Summary', 'Confirm'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final lineStep = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: lineStep < currentStep
                    ? color
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          );
        }
        final step = index ~/ 2;
        final isActive = step <= currentStep;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isActive ? color : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: isActive
                      ? color
                      : Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: isActive && step < currentStep
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${step + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : Colors.grey[600],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[step],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? color : Colors.grey[600],
              ),
            ),
          ],
        );
      }),
    );
  }
}
