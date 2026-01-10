import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_model.dart';
import '../../models/portfolio_item_model.dart';
import '../../models/review_model.dart';
import '../../models/user_profile.dart';
import '../../services/professional_service.dart';
import '../../services/review_service.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/professional/send_inquiry_sheet.dart';
import 'service_detail_screen.dart';
import 'portfolio_detail_screen.dart';

/// Public-facing professional profile screen
class PublicProfessionalProfileScreen extends StatefulWidget {
  final String professionalId;
  final UserProfile? profile;

  const PublicProfessionalProfileScreen({
    super.key,
    required this.professionalId,
    this.profile,
  });

  @override
  State<PublicProfessionalProfileScreen> createState() =>
      _PublicProfessionalProfileScreenState();
}

class _PublicProfessionalProfileScreenState
    extends State<PublicProfessionalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfessionalService _professionalService = ProfessionalService();
  final ReviewService _reviewService = ReviewService();

  UserProfile? _profile;
  List<ServiceModel> _services = [];
  List<PortfolioItemModel> _portfolio = [];
  RatingSummary _ratingSummary = RatingSummary.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profile = widget.profile;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load profile if not provided
      if (_profile == null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.professionalId)
            .get();
        if (doc.exists) {
          _profile = UserProfile.fromFirestore(doc);
        }
      }

      // Load services
      final services =
          await _professionalService.getUserServices(widget.professionalId);

      // Load portfolio
      final portfolio =
          await _professionalService.getUserPortfolio(widget.professionalId);

      // Load rating summary
      final summary =
          await _reviewService.getRatingSummary(widget.professionalId);

      if (mounted) {
        setState(() {
          _services = services.where((s) => s.isActive).toList();
          _portfolio = portfolio;
          _ratingSummary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
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
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D67D)),
        ),
      );
    }

    if (_profile == null) {
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
                Icons.person_off,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Professional not found',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Profile Header
            SliverAppBar(
              expandedHeight: 320,
              floating: false,
              pinned: true,
              backgroundColor:
                  isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
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
                    // TODO: Share profile
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(isDarkMode),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF00D67D),
                    unselectedLabelColor:
                        isDarkMode ? Colors.white54 : Colors.grey[600],
                    indicatorColor: const Color(0xFF00D67D),
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'Services (${_services.length})'),
                      Tab(text: 'Portfolio (${_portfolio.length})'),
                      Tab(text: 'Reviews (${_ratingSummary.totalReviews})'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildServicesTab(isDarkMode),
            _buildPortfolioTab(isDarkMode),
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDarkMode),
    );
  }

  Widget _buildProfileHeader(bool isDarkMode) {
    final profile = _profile!;
    final proProfile = profile.professionalProfile;

    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF00D67D).withValues(alpha: 0.3),
                isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
              ],
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Profile Photo
                Hero(
                  tag: 'profile_${profile.uid}',
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profile.profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profile.profileImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: Color(0xFF00D67D),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: Color(0xFF00D67D),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.person,
                                size: 48,
                                color: Color(0xFF00D67D),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Name and verification
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        proProfile?.businessName ?? profile.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (profile.isVerifiedAccount) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF00D67D),
                        size: 24,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // Category and experience
                Text(
                  [
                    proProfile?.category ?? 'Professional',
                    if (proProfile?.yearsOfExperience != null)
                      '${proProfile!.yearsOfExperience} years',
                  ].join(' • '),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 12),

                // Rating and stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rating
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white10 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _ratingSummary.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            ' (${_ratingSummary.totalReviews})',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Location
                    if (profile.location != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.location!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Hourly rate
                if (proProfile?.hourlyRate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${proProfile!.currency ?? '\$'}${proProfile.hourlyRate!.toStringAsFixed(0)}/hr',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesTab(bool isDarkMode) {
    if (_services.isEmpty) {
      return _buildEmptyState(
        icon: Icons.work_off,
        title: 'No services yet',
        subtitle: 'This professional hasn\'t added any services',
        isDarkMode: isDarkMode,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return _buildServiceCard(service, isDarkMode);
      },
    );
  }

  Widget _buildServiceCard(ServiceModel service, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(
              service: service,
              professional: _profile,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (service.images.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: service.images.first,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 160,
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D67D),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 160,
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.category,
                      style: const TextStyle(
                        color: Color(0xFF00D67D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Title
                  Text(
                    service.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    service.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Price and delivery
                  Row(
                    children: [
                      Text(
                        service.formattedPrice,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D67D),
                        ),
                      ),
                      if (service.deliveryTime != null) ...[
                        const Spacer(),
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.deliveryTime!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioTab(bool isDarkMode) {
    if (_portfolio.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No portfolio items',
        subtitle: 'This professional hasn\'t added any work samples',
        isDarkMode: isDarkMode,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _portfolio.length,
      itemBuilder: (context, index) {
        final item = _portfolio[index];
        return PortfolioGridItem(
          item: item,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortfolioDetailScreen(
                  item: item,
                  professionalName:
                      _profile?.professionalProfile?.businessName ??
                          _profile?.name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsTab(bool isDarkMode) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _reviewService.watchReviewsForProfessional(widget.professionalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyState(
            icon: Icons.rate_review_outlined,
            title: 'No reviews yet',
            subtitle: 'Be the first to review this professional',
            isDarkMode: isDarkMode,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Rating Summary
            _buildRatingSummaryCard(isDarkMode),

            const SizedBox(height: 20),

            // Reviews list
            ...reviews.map((review) => _buildReviewCard(review, isDarkMode)),
          ],
        );
      },
    );
  }

  Widget _buildRatingSummaryCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          // Average rating
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
                    size: 18,
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
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor:
                                isDarkMode ? Colors.white10 : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00D67D),
                            ),
                            minHeight: 8,
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

          Text(
            review.reviewText,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              height: 1.5,
            ),
          ),

          if (review.professionalResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
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
                        'Response',
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode) {
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
            // Message button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Open chat with professional
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00D67D),
                  side: const BorderSide(color: Color(0xFF00D67D)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Inquiry button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SendInquirySheet.show(
                    context,
                    professionalId: widget.professionalId,
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text('Send Inquiry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
