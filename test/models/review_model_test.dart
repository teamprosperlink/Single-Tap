import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/review_model.dart';

void main() {
  group('RatingSummary', () {
    test('empty factory creates zeroed summary', () {
      final summary = RatingSummary.empty();
      expect(summary.averageRating, 0);
      expect(summary.totalReviews, 0);
      expect(summary.distribution.length, 5);
      expect(summary.distribution[5], 0);
      expect(summary.distribution[1], 0);
    });

    test('getPercentage returns 0 when no reviews', () {
      final summary = RatingSummary.empty();
      expect(summary.getPercentage(5), 0);
      expect(summary.getPercentage(1), 0);
    });

    test('getPercentage calculates correct distribution', () {
      final summary = RatingSummary(
        averageRating: 4.0,
        totalReviews: 100,
        distribution: {5: 50, 4: 30, 3: 10, 2: 5, 1: 5},
      );
      expect(summary.getPercentage(5), 50.0);
      expect(summary.getPercentage(4), 30.0);
      expect(summary.getPercentage(1), 5.0);
    });

    test('getPercentage returns 0 for missing rating key', () {
      final summary = RatingSummary(
        averageRating: 4.0,
        totalReviews: 10,
        distribution: {5: 10},
      );
      expect(summary.getPercentage(3), 0);
    });

    test('fromMap parses string keys to int keys', () {
      final summary = RatingSummary.fromMap({
        'averageRating': 4.2,
        'totalReviews': 50,
        'distribution': {'5': 25, '4': 15, '3': 5, '2': 3, '1': 2},
      });
      expect(summary.averageRating, 4.2);
      expect(summary.totalReviews, 50);
      expect(summary.distribution[5], 25);
      expect(summary.distribution[1], 2);
    });

    test('toMap converts int keys to string keys', () {
      final summary = RatingSummary(
        averageRating: 3.5,
        totalReviews: 20,
        distribution: {5: 10, 4: 5, 3: 3, 2: 1, 1: 1},
      );
      final map = summary.toMap();
      expect(map['averageRating'], 3.5);
      expect(map['totalReviews'], 20);
      expect((map['distribution'] as Map)['5'], 10);
      expect((map['distribution'] as Map)['1'], 1);
    });

    test('fromMap/toMap round-trip', () {
      final original = RatingSummary(
        averageRating: 4.5,
        totalReviews: 75,
        distribution: {5: 40, 4: 20, 3: 10, 2: 3, 1: 2},
      );
      final map = original.toMap();
      final restored = RatingSummary.fromMap(map);
      expect(restored.averageRating, original.averageRating);
      expect(restored.totalReviews, original.totalReviews);
      expect(restored.distribution[5], original.distribution[5]);
    });
  });

  group('ReviewModel - formattedDate', () {
    ReviewModel makeReview({required DateTime createdAt}) {
      return ReviewModel(
        id: 'r-1',
        reviewerId: 'rev-1',
        reviewerName: 'Reviewer',
        businessId: 'pro-1',
        rating: 4.0,
        reviewText: 'Great service',
        createdAt: createdAt,
      );
    }

    test('minutes ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      expect(review.formattedDate, '15 min ago');
    });

    test('hours ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(review.formattedDate, '3 hours ago');
    });

    test('yesterday', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(review.formattedDate, 'Yesterday');
    });

    test('days ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      expect(review.formattedDate, '4 days ago');
    });

    test('weeks ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(review.formattedDate, '2 weeks ago');
    });

    test('months ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      );
      expect(review.formattedDate, '2 months ago');
    });

    test('years ago', () {
      final review = makeReview(
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
      );
      expect(review.formattedDate, '1 years ago');
    });
  });

  group('ReviewModel - copyWith', () {
    test('preserves unchanged fields', () {
      final original = ReviewModel(
        id: 'r-1',
        reviewerId: 'rev-1',
        reviewerName: 'Alice',
        businessId: 'pro-1',
        rating: 5.0,
        reviewText: 'Amazing!',
        images: ['img1.jpg'],
      );
      final copy = original.copyWith(rating: 3.0);
      expect(copy.rating, 3.0);
      expect(copy.reviewerName, 'Alice');
      expect(copy.reviewText, 'Amazing!');
      expect(copy.images, ['img1.jpg']);
    });
  });

  group('ReviewModel - defaults', () {
    test('default values are correct', () {
      final review = ReviewModel(
        id: 'r-1',
        reviewerId: 'rev-1',
        reviewerName: 'Test',
        businessId: 'pro-1',
        rating: 4.0,
        reviewText: 'Good',
      );
      expect(review.images, isEmpty);
      expect(review.isVerifiedPurchase, isFalse);
      expect(review.isVisible, isTrue);
      expect(review.isFlagged, isFalse);
    });
  });
}
