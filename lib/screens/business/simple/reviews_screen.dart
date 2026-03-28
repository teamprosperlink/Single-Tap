import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/business/business_shimmer_widgets.dart';
import '../../../widgets/business/business_empty_state.dart';
import '../../../models/review_model.dart';
import '../../../services/review_service.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _reviewService = ReviewService();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.backgroundColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Reviews')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Reviews',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: _reviewService.streamReviews(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShimmerListItem(isDarkMode: isDark),
              ),
            );
          }

          final reviews = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              // Rating summary header
              SliverToBoxAdapter(
                child: _buildRatingSummary(
                    reviews, isDark, textColor, subtitleColor),
              ),

              // Reviews list
              if (reviews.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(isDark, textColor, subtitleColor),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildReviewCard(
                            reviews[index], isDark, textColor, subtitleColor),
                      ),
                      childCount: reviews.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingSummary(List<ReviewModel> reviews, bool isDark,
      Color textColor, Color subtitleColor) {
    // Calculate summary from reviews
    double avgRating = 0;
    final distribution = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    if (reviews.isNotEmpty) {
      double total = 0;
      for (final r in reviews) {
        total += r.rating;
        final stars = r.rating.round().clamp(1, 5);
        distribution[stars] = (distribution[stars] ?? 0) + 1;
      }
      avgRating = total / reviews.length;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: avg + stars
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: TextStyle(
                    color: textColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avgRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppTheme.warningStatus,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text('${reviews.length} reviews',
                  style: TextStyle(color: subtitleColor, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 20),
          // Right: distribution bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final stars = 5 - i;
                final count = distribution[stars] ?? 0;
                final pct =
                    reviews.isEmpty ? 0.0 : count / reviews.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$stars',
                          style: TextStyle(
                              color: subtitleColor, fontSize: 12)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.warningStatus),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text('$count',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: subtitleColor, fontSize: 12)),
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

  Widget _buildReviewCard(ReviewModel review, bool isDark, Color textColor,
      Color subtitleColor) {
    final cardBg = AppTheme.cardColor(isDark);

    // Look up real reviewer profile from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users').doc(review.reviewerId).get(),
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>?;
        final reviewerName = userData?['name'] as String? ??
            userData?['displayName'] as String? ??
            review.reviewerName;
        final reviewerPhoto = userData?['profileImageUrl'] as String? ??
            userData?['photoUrl'] as String? ??
            review.reviewerPhoto;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.cardShadow(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reviewer info
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF0F0F5),
                    backgroundImage:
                        reviewerPhoto != null && reviewerPhoto.isNotEmpty
                            ? CachedNetworkImageProvider(reviewerPhoto)
                            : null,
                    child: reviewerPhoto == null || reviewerPhoto.isEmpty
                        ? Text(
                            reviewerName.isNotEmpty
                                ? reviewerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.warningStatus,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reviewerName,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(review.formattedDate,
                            style:
                                TextStyle(color: subtitleColor, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Stars
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: AppTheme.warningStatus,
                      );
                    }),
                  ),
                ],
              ),

              // Review text
              if (review.reviewText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(review.reviewText,
                    style:
                        TextStyle(color: textColor, fontSize: 14, height: 1.4)),
              ],

              // Owner response
              if (review.businessResponse != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Response',
                          style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(review.businessResponse!,
                          style: TextStyle(
                              color: textColor, fontSize: 13, height: 1.3)),
                    ],
                  ),
                ),
              ],

              // Reply button (only if no response yet)
              if (review.businessResponse == null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showReplySheet(review),
                  child: const Text('Reply',
                      style: TextStyle(
                          color: AppTheme.primaryAction,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showReplySheet(ReviewModel review) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppTheme.textPrimary(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reply to ${review.reviewerName}',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: textColor),
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Write your response...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _reviewService.addOwnerResponse(
                        review.id, controller.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAction,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Send Reply',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      bool isDark, Color textColor, Color subtitleColor) {
    return BusinessEmptyState(
      icon: Icons.star_outline_rounded,
      title: 'No reviews yet',
      subtitle: 'Customer reviews will appear here',
      isDarkMode: isDark,
    );
  }
}
