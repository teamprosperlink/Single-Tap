import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/business_model.dart';
import '../../../../services/business_service.dart';
import '../../../../config/category_profile_config.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/config/app_theme.dart';

/// Section displaying customer reviews
class ReviewsSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final int maxReviews;

  const ReviewsSection({
    super.key,
    required this.businessId,
    required this.config,
    this.maxReviews = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<BusinessReview>>(
      stream: BusinessService().watchBusinessReviews(businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading(isDarkMode);
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        final displayReviews = reviews.take(maxReviews).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, isDarkMode, reviews),
            _buildRatingSummary(isDarkMode, reviews),
            ...displayReviews.map((review) => _ReviewCard(
                  review: review,
                  config: config,
                  isDarkMode: isDarkMode,
                )),
            if (reviews.length > maxReviews)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: () => _showAllReviews(context, reviews),
                  child: Text(
                    'See all ${reviews.length} reviews',
                    style: TextStyle(
                      color: config.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, bool isDarkMode, List<BusinessReview> reviews) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Reviews',
                style: TextStyle(
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${reviews.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText(isDarkMode),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(bool isDarkMode, List<BusinessReview> reviews) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final avgRating =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    // Count ratings per star
    final ratingCounts = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      ratingCounts[i] = reviews.where((r) => r.rating.round() == i).length;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCardSecondary : AppColors.lightGrayTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          // Average rating
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < avgRating.floor()
                        ? Icons.star
                        : index < avgRating
                            ? Icons.star_half
                            : Icons.star_border,
                    size: 16,
                    color: AppColors.iosYellow,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${reviews.length} reviews',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText(isDarkMode),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Rating bars
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final stars = 5 - index;
                final count = ratingCounts[stars] ?? 0;
                final percentage =
                    reviews.isEmpty ? 0.0 : count / reviews.length;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$stars',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryText(isDarkMode),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.star,
                        size: 12,
                        color: AppColors.iosYellow,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor:
                                AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.15),
                            color: config.primaryColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
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

  Widget _buildLoading(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: config.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Text(
              '⭐',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to review!',
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllReviews(BuildContext context, List<BusinessReview> reviews) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: config.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'All Reviews (${reviews.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    return _ReviewCard(
                      review: reviews[index],
                      config: config,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final BusinessReview review;
  final CategoryProfileConfig config;
  final bool isDarkMode;

  const _ReviewCard({
    required this.review,
    required this.config,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and rating
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: config.primaryColor.withValues(alpha: 0.1),
                backgroundImage: review.userPhoto != null
                    ? CachedNetworkImageProvider(review.userPhoto!)
                    : null,
                child: review.userPhoto == null
                    ? Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: config.primaryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRatingColor(review.rating).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: _getRatingColor(review.rating),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRatingColor(review.rating),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Comment
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],

          // Review images
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < review.images.length - 1 ? 8 : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: review.images[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Business reply
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: config.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Business Response',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: config.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.reply!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
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

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else {
      return '${(diff.inDays / 365).floor()} years ago';
    }
  }
}
