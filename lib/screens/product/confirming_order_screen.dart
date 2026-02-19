import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ConfirmingOrderScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String category;
  final int quantity;
  final String orderId;

  const ConfirmingOrderScreen({
    super.key,
    required this.item,
    required this.category,
    this.quantity = 1,
    required this.orderId,
  });

  @override
  State<ConfirmingOrderScreen> createState() => _ConfirmingOrderScreenState();
}

class _ConfirmingOrderScreenState extends State<ConfirmingOrderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _animController.forward();
      }
    });

    // Auto-confirm after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _isConfirmed = true);
        HapticFeedback.mediumImpact();
        _saveOrderToFirestore();
      }
    });
  }

  Future<void> _saveOrderToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final priceStr = widget.item['price'] as String? ?? '₹0';
      final unitPrice = _parsePrice(priceStr);
      final subtotal = unitPrice * widget.quantity;
      final discount = (subtotal * 0.2).round().toDouble();
      const platformFee = 5.0;
      final deliveryFee = widget.category == 'food' ? 25.0 : 0.0;
      final total = subtotal - discount + platformFee + deliveryFee;

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'orderId': widget.orderId,
        'itemName': widget.item['name'] ?? 'Product',
        'itemImage': widget.item['image'] ?? '',
        'itemPrice': priceStr,
        'category': widget.category,
        'subtitle': _getSubtitle(),
        'rating': widget.item['rating'],
        'quantity': widget.quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        'discount': discount,
        'deliveryFee': deliveryFee,
        'platformFee': platformFee,
        'totalAmount': total,
        'deliveryAddress': '789, Park Street, Hyderabad',
        'estimatedDelivery': _getDeliveryTime(),
        'paymentMethod': 'Google Pay',
        'status': 'confirmed',
        'statusTimestamps': {
          'placed': Timestamp.now(),
          'confirmed': Timestamp.now(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving order: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    return const Color(0xFF016CFF);
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
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
    switch (widget.category) {
      case 'food':
        return widget.item['restaurant'] as String? ?? '';
      case 'electric':
        return widget.item['brand'] as String? ?? '';
      case 'house':
      case 'place':
        return widget.item['location'] as String? ?? '';
      default:
        return '';
    }
  }

  double _parsePrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  String _getConfirmedTitle() {
    switch (widget.category) {
      case 'food':
      case 'electric':
        return 'Order Confirmed!';
      case 'house':
      case 'place':
        return 'Booking Confirmed!';
      default:
        return 'Order Confirmed!';
    }
  }

  String _getProcessingTitle() {
    switch (widget.category) {
      case 'food':
      case 'electric':
        return 'Processing Order...';
      case 'house':
      case 'place':
        return 'Processing Booking...';
      default:
        return 'Processing Order...';
    }
  }

  String _getDeliveryTime() {
    switch (widget.category) {
      case 'food':
        return '30-40 min';
      case 'electric':
        return '3-5 days';
      case 'house':
        return 'Within 24 hrs';
      case 'place':
        return 'Instant';
      default:
        return '30-40 min';
    }
  }

  String _getDeliveryLabel() {
    switch (widget.category) {
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
    switch (widget.category) {
      case 'food':
        return [
          {'title': 'Order Placed', 'subtitle': 'Just now', 'done': true},
          {'title': 'Restaurant Notified', 'subtitle': 'Preparing soon', 'done': _isConfirmed},
          {'title': 'Preparing Food', 'subtitle': '~15 min', 'done': false},
          {'title': 'Out for Delivery', 'subtitle': '~30 min', 'done': false},
        ];
      case 'electric':
        return [
          {'title': 'Order Placed', 'subtitle': 'Just now', 'done': true},
          {'title': 'Seller Notified', 'subtitle': 'Processing', 'done': _isConfirmed},
          {'title': 'Shipped', 'subtitle': '~1-2 days', 'done': false},
          {'title': 'Delivered', 'subtitle': '~3-5 days', 'done': false},
        ];
      case 'house':
        return [
          {'title': 'Booking Placed', 'subtitle': 'Just now', 'done': true},
          {'title': 'Owner Notified', 'subtitle': 'Confirming', 'done': _isConfirmed},
          {'title': 'Visit Scheduled', 'subtitle': 'Within 24 hrs', 'done': false},
          {'title': 'Visit Confirmed', 'subtitle': 'Pending', 'done': false},
        ];
      case 'place':
        return [
          {'title': 'Booking Placed', 'subtitle': 'Just now', 'done': true},
          {'title': 'Payment Verified', 'subtitle': 'Confirming', 'done': _isConfirmed},
          {'title': 'Booking Confirmed', 'subtitle': 'Instant', 'done': false},
          {'title': 'E-Ticket Generated', 'subtitle': 'Pending', 'done': false},
        ];
      default:
        return [
          {'title': 'Order Placed', 'subtitle': 'Just now', 'done': true},
          {'title': 'Processing', 'subtitle': 'In progress', 'done': _isConfirmed},
          {'title': 'Shipped', 'subtitle': 'Pending', 'done': false},
          {'title': 'Delivered', 'subtitle': 'Pending', 'done': false},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceStr = widget.item['price'] as String? ?? '₹0';
    final unitPrice = _parsePrice(priceStr);
    final subtotal = unitPrice * widget.quantity;
    final discount = (subtotal * 0.2).round();
    const platformFee = 5;
    final deliveryFee = widget.category == 'food' ? 25 : 0;
    final total = subtotal - discount + platformFee + deliveryFee;
    final color = _getCategoryColor();
    final orderId = widget.orderId;

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
                      Expanded(
                        child: Text(
                          _isConfirmed ? _getConfirmedTitle() : _getProcessingTitle(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                  child: _buildStepIndicator(2, color),
                ),

                const SizedBox(height: 8),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                      // Success Animation Area
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Center(
                            child: Column(
                              children: [
                                // Animated Circle + Icon
                                Transform.scale(
                                  scale: _scaleAnim.value,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          color.withValues(alpha: 0.3),
                                          color.withValues(alpha: 0.05),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.4),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.2),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      child: _isConfirmed
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              key: const ValueKey('check'),
                                              size: 60,
                                              color: color,
                                            )
                                          : SizedBox(
                                              key: const ValueKey('loading'),
                                              width: 50,
                                              height: 50,
                                              child:
                                                  CircularProgressIndicator(
                                                color: color,
                                                strokeWidth: 3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Status Text
                                FadeTransition(
                                  opacity: _fadeAnim,
                                  child: Column(
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 300),
                                        child: Text(
                                          _isConfirmed
                                              ? _getConfirmedTitle()
                                              : _getProcessingTitle(),
                                          key: ValueKey(_isConfirmed),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isConfirmed
                                            ? 'Your order has been placed successfully'
                                            : 'Please wait while we process your order...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Order Timeline
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Order Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '#$orderId',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
                                  widget.item['image'] as String? ?? '',
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
                                    widget.item['name'] as String? ??
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
                                    '${_getSubtitle()} x${widget.quantity}',
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
                                  '₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Paid via GPay',
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

                      // Delivery Info
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
                                    _getDeliveryTime(),
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
                int popCount = 0;
                Navigator.of(context).popUntil((_) => popCount++ >= 4);
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Back to Home',
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
