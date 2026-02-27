import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import 'notification_service.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _reviewsRef =>
      _firestore.collection('business_reviews');

  // ── Submit Review ──

  Future<bool> submitReview(ReviewModel review) async {
    try {
      await _reviewsRef.doc(review.id.isEmpty ? null : review.id).set(
            review.toMap(),
            SetOptions(merge: true),
          );

      // Recalculate rating summary
      await _recalculateRatingSummary(review.professionalId);

      // Notify business owner
      await NotificationService().sendNotificationToUser(
        userId: review.professionalId,
        title: 'New Review',
        body:
            '${review.reviewerName} left a ${review.rating.toInt()}-star review',
        type: 'review',
        data: {'reviewId': review.id},
      );

      return true;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    }
  }

  // ── Stream Reviews ──

  Stream<List<ReviewModel>> streamReviews(String professionalId) {
    return _reviewsRef
        .where('professionalId', isEqualTo: professionalId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList())
        .transform(StreamTransformer<List<ReviewModel>,
            List<ReviewModel>>.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (error, stackTrace, sink) {
            debugPrint('Error streaming reviews: $error');
            sink.add(<ReviewModel>[]);
          },
        ));
  }

  // ── Owner Response ──

  Future<bool> addOwnerResponse(String reviewId, String responseText) async {
    try {
      await _reviewsRef.doc(reviewId).update({
        'professionalResponse': responseText,
        'responseDate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding owner response: $e');
      return false;
    }
  }

  // ── Rating Summary ──

  Future<RatingSummary> getRatingSummary(String professionalId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(professionalId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['ratingSummary'] != null) {
          return RatingSummary.fromMap(
              data['ratingSummary'] as Map<String, dynamic>);
        }
      }
      return RatingSummary.empty();
    } catch (e) {
      debugPrint('Error getting rating summary: $e');
      return RatingSummary.empty();
    }
  }

  Future<void> _recalculateRatingSummary(String professionalId) async {
    try {
      final snap = await _reviewsRef
          .where('professionalId', isEqualTo: professionalId)
          .where('isVisible', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        await _firestore.collection('users').doc(professionalId).update({
          'ratingSummary': RatingSummary.empty().toMap(),
        });
        return;
      }

      final reviews =
          snap.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();

      double totalRating = 0;
      final distribution = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (final review in reviews) {
        totalRating += review.rating.clamp(1.0, 5.0);
        final stars = review.rating.round().clamp(1, 5);
        distribution[stars] = (distribution[stars] ?? 0) + 1;
      }

      final summary = RatingSummary(
        averageRating: totalRating / reviews.length,
        totalReviews: reviews.length,
        distribution: distribution,
      );

      await _firestore.collection('users').doc(professionalId).update({
        'ratingSummary': summary.toMap(),
      });
    } catch (e) {
      debugPrint('Error recalculating rating summary: $e');
    }
  }

  // ── Check if user already reviewed ──

  Future<bool> hasUserReviewed(
      String professionalId, String reviewerId) async {
    try {
      final snap = await _reviewsRef
          .where('professionalId', isEqualTo: professionalId)
          .where('reviewerId', isEqualTo: reviewerId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking review: $e');
      return false;
    }
  }
}
