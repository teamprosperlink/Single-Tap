import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supper/screens/product/checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String category;

  const ProductDetailScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  static const _accent = Color(0xFF016CFF);

  String get _name => widget.item['name'] as String? ?? 'Product';
  String get _price => widget.item['price'] as String? ?? '₹0';
  String get _image => widget.item['image'] as String? ?? '';
  double get _rating => (widget.item['rating'] as num?)?.toDouble() ?? 0.0;

  String get _subtitle {
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

  IconData get _categoryIcon {
    switch (widget.category) {
      case 'food':
        return Icons.restaurant;
      case 'electric':
        return Icons.devices;
      case 'house':
        return Icons.home_rounded;
      case 'place':
        return Icons.place;
      default:
        return Icons.category;
    }
  }

  String get _categoryLabel {
    switch (widget.category) {
      case 'food':
        return 'Food & Dining';
      case 'electric':
        return 'Electronics';
      case 'house':
        return 'Property';
      case 'place':
        return 'Travel';
      default:
        return 'Product';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Back button (left)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Centered title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: Text(
                        _name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 1,
                color: Colors.white,
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Image
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1.7,
                            child: Image.network(
                              _image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[900],
                                child: Icon(
                                  _categoryIcon,
                                  size: 80,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                          // Bottom gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.4, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Image overlay content
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _categoryIcon,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _categoryLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Product Name
                                Text(
                                  _name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Subtitle + Rating row
                                Row(
                                  children: [
                                    if (_subtitle.isNotEmpty) ...[
                                      Icon(
                                        _getSubtitleIcon(),
                                        color: Colors.grey[400],
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _subtitle,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[600],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_rating',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Heart + Share buttons on image (last so they receive taps)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _isFavorite = !_isFavorite);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      _isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isFavorite
                                          ? Colors.redAccent
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showShareSheet();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.share_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price + Offer Row
                            Row(
                              children: [
                                // Price
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _accent.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _price,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (_getPriceLabel().isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          _getPriceLabel(),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Offer badge
                                if (widget.category == 'food' ||
                                    widget.category == 'electric')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.greenAccent.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_offer_rounded,
                                          color: Colors.greenAccent,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '20% OFF',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Quick Info Chips
                            _buildQuickInfoChips(),

                            const SizedBox(height: 22),

                            // Description
                            _buildGlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Description',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getDescription(),
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Features
                            _buildFeaturesSection(),

                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  IconData _getSubtitleIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.storefront_rounded;
      case 'electric':
        return Icons.business_rounded;
      case 'house':
      case 'place':
        return Icons.location_on_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _getPriceLabel() {
    switch (widget.category) {
      case 'food':
        return 'per plate';
      case 'place':
        return 'per person';
      default:
        return '';
    }
  }

  Widget _buildQuickInfoChips() {
    final chips = <Map<String, dynamic>>[];

    switch (widget.category) {
      case 'food':
        chips.addAll([
          {
            'icon': Icons.location_on_outlined,
            'text': widget.item['distance'] ?? 'N/A',
          },
          {'icon': Icons.timer_outlined, 'text': '30-40 min'},
          {'icon': Icons.delivery_dining, 'text': 'Free Delivery'},
        ]);
        break;
      case 'electric':
        chips.addAll([
          {
            'icon': Icons.verified_outlined,
            'text': widget.item['condition'] ?? 'New',
          },
          {'icon': Icons.local_shipping_outlined, 'text': 'Free Shipping'},
          {'icon': Icons.shield_outlined, 'text': '1 Year Warranty'},
        ]);
        break;
      case 'house':
        chips.addAll([
          {
            'icon': Icons.square_foot_rounded,
            'text': widget.item['area'] ?? 'N/A',
          },
          {
            'icon': Icons.apartment_rounded,
            'text': widget.item['type'] ?? 'N/A',
          },
          {'icon': Icons.event_available_rounded, 'text': 'Available Now'},
        ]);
        break;
      case 'place':
        chips.addAll([
          {
            'icon': Icons.directions_rounded,
            'text': widget.item['distance'] ?? 'N/A',
          },
          {'icon': Icons.terrain_rounded, 'text': widget.item['type'] ?? 'N/A'},
          {'icon': Icons.wb_sunny_outlined, 'text': 'Oct - Mar'},
        ]);
        break;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: chips.map((chip) {
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip['icon'] as IconData, color: _accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  chip['text'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = _getFeatures();
    final title = _getFeaturesTitle();

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getFeaturesTitle() {
    switch (widget.category) {
      case 'food':
        return 'Highlights';
      case 'electric':
        return 'Features';
      case 'house':
        return 'Amenities';
      case 'place':
        return 'Activities';
      default:
        return 'Features';
    }
  }

  List<String> _getFeatures() {
    switch (widget.category) {
      case 'food':
        return [
          'Fresh Ingredients',
          'Hygienic Kitchen',
          'Quick Service',
          'Best Taste',
          'Value for Money',
        ];
      case 'electric':
        return [
          'Original Product',
          'Fast Delivery',
          'Easy Returns',
          'Warranty',
          'COD Available',
        ];
      case 'house':
        return [
          '24/7 Security',
          'Power Backup',
          'Parking',
          'Lift',
          'Garden',
          'Gym',
        ];
      case 'place':
        return [
          'Sightseeing',
          'Photography',
          'Local Food',
          'Adventure',
          'Nature Walk',
          'Shopping',
        ];
      default:
        return [];
    }
  }

  String _getDescription() {
    switch (widget.category) {
      case 'food':
        return 'Delicious $_name prepared with fresh ingredients and authentic spices. A perfect blend of flavors served hot and fresh from the kitchen.';
      case 'electric':
        return 'Premium quality $_name with latest features and technology. Comes with manufacturer warranty and all original accessories.';
      case 'house':
        return 'Beautiful $_name in a prime area with excellent connectivity. Features modern amenities, 24/7 security, power backup, and parking.';
      case 'place':
        return 'Explore the stunning beauty of $_name. A perfect destination for travelers seeking adventure, peace, and natural beauty.';
      default:
        return 'Quality product with excellent features.';
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ClipRRect(
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
            color: Colors.black.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              // Price column
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _price,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Action Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          item: widget.item,
                          category: widget.category,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getPrimaryButtonIcon(),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getPrimaryButtonText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPrimaryButtonIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.shopping_bag_rounded;
      case 'electric':
        return Icons.shopping_cart_rounded;
      case 'house':
        return Icons.calendar_today_rounded;
      case 'place':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.shopping_cart_rounded;
    }
  }

  String _getPrimaryButtonText() {
    switch (widget.category) {
      case 'food':
        return 'Order Now';
      case 'electric':
        return 'Buy Now';
      case 'house':
        return 'Schedule Visit';
      case 'place':
        return 'Plan Trip';
      default:
        return 'Buy Now';
    }
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(30, 30, 30, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share via',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(Icons.message, 'SingleTap', Colors.green),
                  _buildShareOption(Icons.telegram, 'Telegram', Colors.blue),
                  _buildShareOption(Icons.copy, 'Copy Link', Colors.grey),
                  _buildShareOption(Icons.more_horiz, 'More', Colors.purple),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing via $label...'),
            backgroundColor: Colors.grey[800],
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
