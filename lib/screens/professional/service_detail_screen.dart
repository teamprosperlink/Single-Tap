import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/service_model.dart';
import '../../models/review_model.dart';
import '../../models/user_profile.dart';
import '../../services/professional_service.dart';
import '../../services/review_service.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/professional/send_inquiry_sheet.dart';
import 'public_professional_profile_screen.dart';

/// Public view of a service for clients
class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;
  final UserProfile? professional;

  const ServiceDetailScreen({
    super.key,
    required this.service,
    this.professional,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final ProfessionalService _professionalService = ProfessionalService();
  final ReviewService _reviewService = ReviewService();

  UserProfile? _professional;
  List<ReviewModel> _reviews = [];
  RatingSummary _ratingSummary = RatingSummary.empty();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _professional = widget.professional;
    _loadData();
    _incrementViews();
  }

  Future<void> _loadData() async {
    try {
      // Load professional profile if not provided
      if (_professional == null) {
        // getProfessionalProfile returns ProfessionalProfile, not UserProfile
        // We'll load reviews instead which is more important for the service detail
        await _professionalService.getProfessionalProfile(widget.service.userId);
      }

      // Load reviews for this service
      final reviews = await _reviewService.getReviewsForService(widget.service.id);
      final summary = await _reviewService.getRatingSummary(widget.service.userId);

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _ratingSummary = summary;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _incrementViews() async {
    await _professionalService.incrementServiceViews(widget.service.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final service = widget.service;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Image Gallery Header
          _buildImageGallery(isDarkMode, service),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  _buildTitleSection(isDarkMode, service),

                  const SizedBox(height: 20),

                  // Professional Card
                  _buildProfessionalCard(isDarkMode),

                  const SizedBox(height: 24),

                  // Description
                  _buildSection(
                    'Description',
                    isDarkMode,
                    child: Text(
                      service.description,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Service Details
                  _buildDetailsSection(isDarkMode, service),

                  if (service.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildTagsSection(isDarkMode, service),
                  ],

                  const SizedBox(height: 24),

                  // Reviews Section
                  _buildReviewsSection(isDarkMode),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDarkMode, service),
    );
  }

  Widget _buildImageGallery(bool isDarkMode, ServiceModel service) {
    final images = service.images.isNotEmpty
        ? service.images
        : ['https://via.placeholder.com/800x600?text=No+Image'];

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
          onPressed: () {
            // TODO: Share service
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Image PageView
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D67D),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                );
              },
            ),

            // Image indicators
            if (images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentImageIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == index
                            ? const Color(0xFF00D67D)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isDarkMode, ServiceModel service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00D67D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            service.category,
            style: const TextStyle(
              color: Color(0xFF00D67D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Title
        Text(
          service.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        // Price and stats row
        Row(
          children: [
            // Price
            Text(
              service.formattedPrice,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D67D),
              ),
            ),

            if (service.deliveryTime != null) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.deliveryTime!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Views and Inquiries
            _buildStatBadge(
              Icons.visibility_outlined,
              '${service.views}',
              isDarkMode,
            ),
            const SizedBox(width: 12),
            _buildStatBadge(
              Icons.chat_outlined,
              '${service.inquiries}',
              isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String value, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDarkMode ? Colors.white38 : Colors.grey[400],
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white38 : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalCard(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfessionalProfileScreen(
              professionalId: widget.service.userId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Photo
            Builder(
              builder: (context) {
                final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(_professional?.profileImageUrl);
                final name = _professional?.professionalProfile?.businessName ?? _professional?.name ?? 'P';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

                Widget buildFallbackAvatar() {
                  return CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFF00D67D),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  );
                }

                if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                  return buildFallbackAvatar();
                }

                return ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: fixedPhotoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => buildFallbackAvatar(),
                    errorWidget: (context, url, error) {
                      if (error.toString().contains('429')) {
                        PhotoUrlHelper.markAsRateLimited(url);
                      }
                      return buildFallbackAvatar();
                    },
                  ),
                );
              },
            ),

            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _professional?.professionalProfile?.businessName ??
                              _professional?.name ??
                              'Professional',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_professional?.isVerifiedAccount == true) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 18,
                          color: Color(0xFF00D67D),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _ratingSummary.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        ' (${_ratingSummary.totalReviews} reviews)',
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

            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, bool isDarkMode, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDetailsSection(bool isDarkMode, ServiceModel service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.category_outlined,
            'Category',
            service.category,
            isDarkMode,
          ),
          _buildDivider(isDarkMode),
          _buildDetailRow(
            Icons.attach_money,
            'Pricing',
            service.pricingType.displayName,
            isDarkMode,
          ),
          if (service.deliveryTime != null) ...[
            _buildDivider(isDarkMode),
            _buildDetailRow(
              Icons.schedule,
              'Delivery',
              service.deliveryTime!,
              isDarkMode,
            ),
          ],
          _buildDivider(isDarkMode),
          _buildDetailRow(
            Icons.currency_exchange,
            'Currency',
            service.currency,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00D67D), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      color: isDarkMode ? Colors.white10 : Colors.grey[200],
    );
  }

  Widget _buildTagsSection(bool isDarkMode, ServiceModel service) {
    return _buildSection(
      'Tags',
      isDarkMode,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: service.tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewsSection(bool isDarkMode) {
    return _buildSection(
      'Reviews',
      isDarkMode,
      child: Column(
        children: [
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Average Rating
                    Column(
                      children: [
                        Text(
                          _ratingSummary.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < _ratingSummary.averageRating.floor()
                                  ? Icons.star
                                  : index < _ratingSummary.averageRating
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_ratingSummary.totalReviews} reviews',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 24),

                    // Distribution
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) {
                          final rating = 5 - index;
                          final percentage = _ratingSummary.getPercentage(rating);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  '$rating',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: isDarkMode
                                          ? Colors.white10
                                          : Colors.grey[200],
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF00D67D),
                                      ),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${percentage.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.white38
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Review List
          if (_reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to review this service',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white38 : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_reviews.take(3).map((review) => _buildReviewCard(review, isDarkMode))),

          if (_reviews.length > 3) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: Show all reviews
              },
              child: const Text(
                'See all reviews',
                style: TextStyle(color: Color(0xFF00D67D)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer info
          Row(
            children: [
              Builder(
                builder: (context) {
                  final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(review.reviewerPhoto);
                  final initial = review.reviewerName.isNotEmpty ? review.reviewerName[0].toUpperCase() : '?';

                  Widget buildFallbackAvatar() {
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF00D67D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                    return buildFallbackAvatar();
                  }

                  return ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: fixedPhotoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => buildFallbackAvatar(),
                      errorWidget: (context, url, error) {
                        if (error.toString().contains('429')) {
                          PhotoUrlHelper.markAsRateLimited(url);
                        }
                        return buildFallbackAvatar();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      review.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review text
          Text(
            review.reviewText,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              height: 1.5,
            ),
          ),

          // Professional response
          if (review.professionalResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Response from seller',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.professionalResponse!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white60 : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode, ServiceModel service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.formattedPrice,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D67D),
                  ),
                ),
                if (service.pricingType != PricingType.fixed)
                  Text(
                    service.pricingType.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 20),

            // Contact button
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SendInquirySheet.show(
                    context,
                    professionalId: widget.service.userId,
                    service: widget.service,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Send Inquiry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
