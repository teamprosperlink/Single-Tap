import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';

/// Modern Reviews Section with Enhanced Design
/// Features:
/// - Overall rating with progress bars
/// - User avatars with profile pictures
/// - Verified purchase badges
/// - Helpful vote buttons
/// - Photo reviews highlighted
/// - Filter and sort options
class ModernReviewsSection extends StatefulWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final int maxReviews;

  const ModernReviewsSection({
    super.key,
    required this.businessId,
    required this.config,
    this.maxReviews = 5,
  });

  @override
  State<ModernReviewsSection> createState() => _ModernReviewsSectionState();
}

class _ModernReviewsSectionState extends State<ModernReviewsSection> {
  String _sortBy = 'recent'; // recent, highest, lowest

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header with filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 24,
                color: AppTheme.darkText(isDarkMode),
              ),
              const SizedBox(width: 8),
              Text(
                'Reviews',
                style: TextStyle(
                  fontSize: AppTheme.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
              ),
              const Spacer(),
              _buildSortDropdown(isDarkMode),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Overall rating summary
        _buildRatingSummary(isDarkMode),

        const SizedBox(height: 20),

        // Reviews stream
        StreamBuilder<QuerySnapshot>(
          stream: _getReviewsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(isDarkMode);
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(isDarkMode);
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                data['_docId'] = doc.id;
                return _buildReviewCard(context, data, isDarkMode);
              },
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Stream<QuerySnapshot> _getReviewsStream() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.businessId)
        .collection('reviews')
        .limit(widget.maxReviews);

    switch (_sortBy) {
      case 'highest':
        query = query.orderBy('rating', descending: true);
        break;
      case 'lowest':
        query = query.orderBy('rating', descending: false);
        break;
      default: // recent
        query = query.orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }

  Widget _buildSortDropdown(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        underline: const SizedBox.shrink(),
        isDense: true,
        icon: Icon(
          Icons.arrow_drop_down,
          color: AppTheme.darkText(isDarkMode),
          size: 20,
        ),
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.darkText(isDarkMode),
          fontWeight: FontWeight.w500,
        ),
        items: const [
          DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
          DropdownMenuItem(value: 'highest', child: Text('Highest Rated')),
          DropdownMenuItem(value: 'lowest', child: Text('Lowest Rated')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _sortBy = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildRatingSummary(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final reviews = snapshot.data!.docs;
        if (reviews.isEmpty) return const SizedBox.shrink();

        // Calculate rating distribution
        final ratingCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        double totalRating = 0;

        for (var doc in reviews) {
          final rating = (doc.data() as Map<String, dynamic>)['rating'] as int;
          ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          totalRating += rating;
        }

        final averageRating = totalRating / reviews.length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(isDarkMode),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Average rating
              Column(
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText(isDarkMode),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < averageRating.floor()
                            ? Icons.star
                            : (index < averageRating ? Icons.star_half : Icons.star_outline),
                        color: AppTheme.warningOrange,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reviews.length} reviews',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText(isDarkMode),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 32),

              // Rating distribution
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final starCount = 5 - index;
                    final count = ratingCounts[starCount] ?? 0;
                    final percentage = count / reviews.length;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '$starCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkText(isDarkMode),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.star, size: 14, color: AppTheme.warningOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: AppTheme.secondaryText(isDarkMode)
                                    .withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.warningOrange,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryText(isDarkMode),
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
      },
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    Map<String, dynamic> review,
    bool isDarkMode,
  ) {
    final userName = review['userName'] as String? ?? 'Anonymous';
    final userPhoto = review['userPhoto'] as String?;
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] as String? ?? '';
    final createdAt = (review['createdAt'] as Timestamp?)?.toDate();
    final isVerified = review['isVerified'] as bool? ?? false;
    final helpfulCount = review['helpfulCount'] as int? ?? 0;
    final photos = review['photos'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.config.primaryColor.withValues(alpha: 0.2),
                backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
                child: userPhoto == null
                    ? Text(
                        userName[0].toUpperCase(),
                        style: TextStyle(
                          color: widget.config.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // Name and verification
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText(isDarkMode),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 12,
                                  color: AppTheme.successGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      createdAt != null ? timeago.format(createdAt) : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),

              // Star rating
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating ? Icons.star : Icons.star_outline,
                    color: AppTheme.warningOrange,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review comment
          if (comment.isNotEmpty)
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkText(isDarkMode),
                height: 1.5,
              ),
            ),

          // Review photos
          if (photos != null && photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photos[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Helpful button
          InkWell(
            onTap: () => _markHelpful(review),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: AppTheme.secondaryText(isDarkMode),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Helpful${helpfulCount > 0 ? ' ($helpfulCount)' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText(isDarkMode),
                      fontWeight: FontWeight.w500,
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

  Widget _buildLoadingSkeleton(bool isDarkMode) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.cardColor(isDarkMode).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: AppTheme.secondaryText(isDarkMode),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: AppTheme.fontLarge,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText(isDarkMode),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to leave a review!',
              style: TextStyle(
                fontSize: AppTheme.fontMedium,
                color: AppTheme.secondaryText(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markHelpful(Map<String, dynamic> review) {
    final docId = review['_docId'] as String?;
    if (docId == null) return;

    FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.businessId)
        .collection('reviews')
        .doc(docId)
        .update({'helpfulCount': FieldValue.increment(1)});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for your feedback!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
