import 'package:flutter/material.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';
import '../../../config/category_profile_config.dart';
import 'templates/generic_template.dart';
// Note: Category-specific templates archived for MVP simplification
// Using GenericTemplate for all business categories

/// Main entry point for customer-facing business profile view
///
/// This screen:
/// 1. Fetches business data from Firebase
/// 2. Determines the appropriate template based on category
/// 3. Renders the category-specific profile view
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => BusinessProfileScreen(businessId: 'abc123'),
///   ),
/// );
/// ```
class BusinessProfileScreen extends StatefulWidget {
  final String businessId;

  const BusinessProfileScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final BusinessService _businessService = BusinessService();
  BusinessModel? _business;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _trackView();
  }

  Future<void> _loadBusiness() async {
    try {
      final business = await _businessService.getBusiness(widget.businessId);
      if (mounted) {
        setState(() {
          _business = business;
          _isLoading = false;
          if (business == null) {
            _error = 'Business not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load business';
        });
      }
    }
  }

  Future<void> _trackView() async {
    // Increment view count for analytics
    await _businessService.incrementViewCount(widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _buildLoadingScreen(isDarkMode);
    }

    if (_error != null || _business == null) {
      return _buildErrorScreen(isDarkMode);
    }

    // Get the profile configuration for this business category
    final config = CategoryProfileConfig.getConfig(_business!.category);

    // Route to appropriate template based on category
    return _buildTemplate(_business!, config);
  }

  Widget _buildTemplate(BusinessModel business, CategoryProfileConfig config) {
    // MVP Simplification: Use generic template for all business categories
    // Category-specific templates archived for future enhancement
    return GenericTemplate(business: business, config: config);
  }

  Widget _buildLoadingScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: const _LoadingShimmer(),
    );
  }

  Widget _buildErrorScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _error ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This business may have been removed or is unavailable.',
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadBusiness();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading shimmer effect for profile
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // Hero shimmer
        SliverToBoxAdapter(
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[300],
            ),
            child: Stack(
              children: [
                // Shimmer effect
                _ShimmerBox(
                  width: double.infinity,
                  height: 280,
                  isDarkMode: isDarkMode,
                ),
                // Back button placeholder
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quick actions shimmer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: _ShimmerBox(
                      width: double.infinity,
                      height: 44,
                      borderRadius: 12,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Highlights shimmer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                5,
                (index) => _ShimmerBox(
                  width: 80 + (index * 10).toDouble(),
                  height: 32,
                  borderRadius: 16,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
          ),
        ),

        // Content shimmer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: 120,
                  height: 24,
                  borderRadius: 4,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ShimmerBox(
                      width: double.infinity,
                      height: 80,
                      borderRadius: 12,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDarkMode;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 0,
    required this.isDarkMode,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(1.0 + _animation.value, 0),
              colors: widget.isDarkMode
                  ? [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.grey[300]!,
                      Colors.grey[100]!,
                      Colors.grey[300]!,
                    ],
            ),
          ),
        );
      },
    );
  }
}
