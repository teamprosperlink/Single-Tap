import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String category; // 'food', 'electric', 'house', 'place'

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

  @override
  Widget build(BuildContext context) {
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
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                  Color(0xFF0f0f23),
                ],
              ),
            ),
          ),
          CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1a1a2e),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isFavorite = !_isFavorite);
                },
                icon: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showShareSheet();
                },
                icon: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(Icons.share, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.item['image'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: Icon(
                          _getCategoryIcon(),
                          size: 80,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Category badge
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getCategoryLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.item['rating']}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Subtitle based on category
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPriceIcon(),
                          color: Colors.green[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.item['price'] as String,
                          style: TextStyle(
                            color: Colors.green[400],
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_getPriceLabel().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            _getPriceLabel(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Cards
                  _buildInfoSection(),

                  const SizedBox(height: 24),

                  // Description
                  _buildDescriptionSection(),

                  const SizedBox(height: 24),

                  // Features/Highlights
                  _buildFeaturesSection(),

                  const SizedBox(height: 24),

                  // Reviews Section
                  _buildReviewsSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.restaurant;
      case 'electric':
        return Icons.devices;
      case 'house':
        return Icons.home;
      case 'place':
        return Icons.place;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case 'food':
        return Colors.orange;
      case 'electric':
        return Colors.blue;
      case 'house':
        return Colors.purple;
      case 'place':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel() {
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

  String _getSubtitle() {
    switch (widget.category) {
      case 'food':
        return widget.item['restaurant'] as String? ?? '';
      case 'electric':
        return widget.item['brand'] as String? ?? '';
      case 'house':
        return widget.item['location'] as String? ?? '';
      case 'place':
        return widget.item['location'] as String? ?? '';
      default:
        return '';
    }
  }

  IconData _getPriceIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.restaurant_menu;
      case 'electric':
        return Icons.shopping_cart;
      case 'house':
        return Icons.home_work;
      case 'place':
        return Icons.flight;
      default:
        return Icons.attach_money;
    }
  }

  String _getPriceLabel() {
    switch (widget.category) {
      case 'food':
        return 'per plate';
      case 'place':
        return 'approx. per person';
      default:
        return '';
    }
  }

  Widget _buildInfoSection() {
    List<Map<String, dynamic>> infoItems = [];

    switch (widget.category) {
      case 'food':
        infoItems = [
          {'icon': Icons.location_on, 'label': 'Distance', 'value': widget.item['distance'] ?? 'N/A'},
          {'icon': Icons.access_time, 'label': 'Delivery', 'value': '30-40 min'},
          {'icon': Icons.local_offer, 'label': 'Offer', 'value': '20% OFF'},
        ];
        break;
      case 'electric':
        infoItems = [
          {'icon': Icons.verified, 'label': 'Condition', 'value': widget.item['condition'] ?? 'New'},
          {'icon': Icons.local_shipping, 'label': 'Delivery', 'value': 'Free'},
          {'icon': Icons.security, 'label': 'Warranty', 'value': '1 Year'},
        ];
        break;
      case 'house':
        infoItems = [
          {'icon': Icons.square_foot, 'label': 'Area', 'value': widget.item['area'] ?? 'N/A'},
          {'icon': Icons.apartment, 'label': 'Type', 'value': widget.item['type'] ?? 'N/A'},
          {'icon': Icons.calendar_today, 'label': 'Available', 'value': 'Immediate'},
        ];
        break;
      case 'place':
        infoItems = [
          {'icon': Icons.directions, 'label': 'Distance', 'value': widget.item['distance'] ?? 'N/A'},
          {'icon': Icons.terrain, 'label': 'Type', 'value': widget.item['type'] ?? 'N/A'},
          {'icon': Icons.wb_sunny, 'label': 'Best Time', 'value': 'Oct-Mar'},
        ];
        break;
    }

    return Row(
      children: infoItems.map((info) {
        return Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      info['icon'] as IconData,
                      color: _getCategoryColor(),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info['label'] as String,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info['value'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionSection() {
    String description = _getDescription();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  String _getDescription() {
    final name = widget.item['name'] as String;
    switch (widget.category) {
      case 'food':
        return 'Delicious $name prepared with fresh ingredients and authentic spices. A perfect blend of flavors that will tantalize your taste buds. Served hot and fresh from our kitchen to your table.';
      case 'electric':
        return 'Premium quality $name with latest features and technology. Comes with manufacturer warranty and all original accessories. Perfect for your daily needs with excellent performance and reliability.';
      case 'house':
        return 'Beautiful $name located in a prime area with excellent connectivity. Features modern amenities, 24/7 security, power backup, and parking facility. Well-ventilated with natural light and peaceful surroundings.';
      case 'place':
        return 'Explore the stunning beauty of $name. A perfect destination for travelers seeking adventure, peace, and natural beauty. Create unforgettable memories with breathtaking views and local experiences.';
      default:
        return 'Quality product with excellent features.';
    }
  }

  Widget _buildFeaturesSection() {
    List<String> features = _getFeatures();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getFeaturesTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((feature) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getCategoryColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getCategoryColor().withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _getCategoryColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    feature,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
        return ['Fresh Ingredients', 'Hygienic', 'Quick Service', 'Best Taste', 'Value for Money'];
      case 'electric':
        return ['Original Product', 'Fast Delivery', 'Easy Returns', 'Warranty', 'COD Available'];
      case 'house':
        return ['24/7 Security', 'Power Backup', 'Parking', 'Lift', 'Garden', 'Gym'];
      case 'place':
        return ['Sightseeing', 'Photography', 'Local Food', 'Adventure', 'Nature Walk', 'Shopping'];
      default:
        return [];
    }
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'See All',
                style: TextStyle(color: _getCategoryColor()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildReviewCard(
          'Rahul S.',
          4.5,
          'Amazing experience! Highly recommended for everyone.',
          '2 days ago',
        ),
        const SizedBox(height: 12),
        _buildReviewCard(
          'Priya M.',
          5.0,
          'Excellent quality and service. Will definitely come back!',
          '1 week ago',
        ),
      ],
    );
  }

  Widget _buildReviewCard(String name, double rating, String review, String time) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getCategoryColor().withValues(alpha: 0.2),
                child: Text(
                  name[0],
                  style: TextStyle(
                    color: _getCategoryColor(),
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
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : (index < rating ? Icons.star_half : Icons.star_border),
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
      child: Row(
        children: [
          // Chat/Call Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_getSecondaryButtonAction()),
                    backgroundColor: Colors.grey[800],
                  ),
                );
              },
              icon: Icon(_getSecondaryButtonIcon()),
              label: Text(_getSecondaryButtonText()),
              style: OutlinedButton.styleFrom(
                foregroundColor: _getCategoryColor(),
                side: BorderSide(color: _getCategoryColor()),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Primary Action Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_getPrimaryButtonAction()),
                    backgroundColor: _getCategoryColor(),
                  ),
                );
              },
              icon: Icon(_getPrimaryButtonIcon()),
              label: Text(_getPrimaryButtonText()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

  IconData _getSecondaryButtonIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.call;
      case 'electric':
        return Icons.chat;
      case 'house':
        return Icons.chat;
      case 'place':
        return Icons.bookmark;
      default:
        return Icons.chat;
    }
  }

  String _getSecondaryButtonText() {
    switch (widget.category) {
      case 'food':
        return 'Call';
      case 'electric':
        return 'Chat';
      case 'house':
        return 'Chat';
      case 'place':
        return 'Save';
      default:
        return 'Chat';
    }
  }

  String _getSecondaryButtonAction() {
    switch (widget.category) {
      case 'food':
        return 'Calling restaurant...';
      case 'electric':
        return 'Opening chat with seller...';
      case 'house':
        return 'Opening chat with owner...';
      case 'place':
        return 'Saved to your wishlist!';
      default:
        return 'Action performed';
    }
  }

  IconData _getPrimaryButtonIcon() {
    switch (widget.category) {
      case 'food':
        return Icons.shopping_bag;
      case 'electric':
        return Icons.shopping_cart;
      case 'house':
        return Icons.calendar_today;
      case 'place':
        return Icons.flight_takeoff;
      default:
        return Icons.shopping_cart;
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

  String _getPrimaryButtonAction() {
    switch (widget.category) {
      case 'food':
        return 'Order placed successfully!';
      case 'electric':
        return 'Added to cart!';
      case 'house':
        return 'Visit scheduled!';
      case 'place':
        return 'Opening trip planner...';
      default:
        return 'Action performed';
    }
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
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
                  _buildShareOption(Icons.message, 'WhatsApp', Colors.green),
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
