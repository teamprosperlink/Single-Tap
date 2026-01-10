import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';

/// Service for managing professional reviews
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // REVIEW CRUD OPERATIONS

  /// Create a new review
  Future<String?> createReview({
    required String professionalId,
    required double rating,
    required String reviewText,
    String? serviceId,
    String? serviceName,
    Map<String, double>? categoryRatings,
    List<String>? images,
  }) async {
    if (_currentUserId == null) return null;

    try {
      // Get reviewer info
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      final userData = userDoc.data() ?? {};

      final review = ReviewModel(
        id: '',
        reviewerId: _currentUserId!,
        reviewerName: userData['name'] ?? 'Anonymous',
        reviewerPhoto: userData['profileImageUrl'] ?? userData['photoUrl'],
        professionalId: professionalId,
        serviceId: serviceId,
        serviceName: serviceName,
        rating: rating,
        categoryRatings: categoryRatings,
        reviewText: reviewText,
        images: images ?? [],
        isVerifiedPurchase: false, // TODO: Check actual purchase history
      );

      // Add review
      final docRef = await _firestore.collection('reviews').add(review.toMap());

      // Update professional's rating summary
      await _updateRatingSummary(professionalId);

      // Update service review count if applicable
      if (serviceId != null) {
        await _firestore.collection('services').doc(serviceId).update({
          'reviewCount': FieldValue.increment(1),
        });
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating review: $e');
      return null;
    }
  }

  /// Update a review
  Future<bool> updateReview(
    String reviewId, {
    double? rating,
    String? reviewText,
    Map<String, double>? categoryRatings,
    List<String>? images,
  }) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!doc.exists) return false;

      final review = ReviewModel.fromFirestore(doc);
      if (review.reviewerId != _currentUserId) return false; // Not owner

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rating != null) updates['rating'] = rating;
      if (reviewText != null) updates['reviewText'] = reviewText;
      if (categoryRatings != null) updates['categoryRatings'] = categoryRatings;
      if (images != null) updates['images'] = images;

      await _firestore.collection('reviews').doc(reviewId).update(updates);

      // Update rating summary if rating changed
      if (rating != null) {
        await _updateRatingSummary(review.professionalId);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating review: $e');
      return false;
    }
  }

  /// Delete a review
  Future<bool> deleteReview(String reviewId) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!doc.exists) return false;

      final review = ReviewModel.fromFirestore(doc);
      if (review.reviewerId != _currentUserId) return false; // Not owner

      await _firestore.collection('reviews').doc(reviewId).delete();

      // Update rating summary
      await _updateRatingSummary(review.professionalId);

      return true;
    } catch (e) {
      debugPrint('Error deleting review: $e');
      return false;
    }
  }

  /// Add professional response to a review
  Future<bool> respondToReview(String reviewId, String response) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!doc.exists) return false;

      final review = ReviewModel.fromFirestore(doc);
      if (review.professionalId != _currentUserId) {
        return false; // Not the professional
      }

      await _firestore.collection('reviews').doc(reviewId).update({
        'professionalResponse': response,
        'responseDate': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error responding to review: $e');
      return false;
    }
  }

  // REVIEW QUERIES

  /// Get reviews for a professional
  Future<List<ReviewModel>> getReviewsForProfessional(
    String professionalId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('reviews')
          .where('professionalId', isEqualTo: professionalId)
          .where('isVisible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      return [];
    }
  }

  /// Stream reviews for a professional
  Stream<List<ReviewModel>> watchReviewsForProfessional(String professionalId) {
    return _firestore
        .collection('reviews')
        .where('professionalId', isEqualTo: professionalId)
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReviewModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get reviews for a service
  Future<List<ReviewModel>> getReviewsForService(String serviceId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('serviceId', isEqualTo: serviceId)
          .where('isVisible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting service reviews: $e');
      return [];
    }
  }

  /// Check if user has already reviewed
  Future<bool> hasUserReviewed(
    String professionalId, {
    String? serviceId,
  }) async {
    if (_currentUserId == null) return false;

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('reviews')
          .where('professionalId', isEqualTo: professionalId)
          .where('reviewerId', isEqualTo: _currentUserId);

      if (serviceId != null) {
        query = query.where('serviceId', isEqualTo: serviceId);
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking review: $e');
      return false;
    }
  }

  /// Get user's review for a professional
  Future<ReviewModel?> getUserReview(String professionalId) async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('professionalId', isEqualTo: professionalId)
          .where('reviewerId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ReviewModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting user review: $e');
      return null;
    }
  }

  // RATING SUMMARY

  /// Get rating summary for a professional
  Future<RatingSummary> getRatingSummary(String professionalId) async {
    try {
      final doc = await _firestore
          .collection('professional_stats')
          .doc(professionalId)
          .get();

      if (!doc.exists || doc.data()?['ratingSummary'] == null) {
        return RatingSummary.empty();
      }

      return RatingSummary.fromMap(doc.data()!['ratingSummary']);
    } catch (e) {
      debugPrint('Error getting rating summary: $e');
      return RatingSummary.empty();
    }
  }

  /// Update rating summary (called after review changes)
  Future<void> _updateRatingSummary(String professionalId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('professionalId', isEqualTo: professionalId)
          .where('isVisible', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        await _firestore
            .collection('professional_stats')
            .doc(professionalId)
            .set({
              'ratingSummary': RatingSummary.empty().toMap(),
            }, SetOptions(merge: true));
        return;
      }

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      // Calculate distribution
      final distribution = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double totalRating = 0;

      for (final review in reviews) {
        final roundedRating = review.rating.round().clamp(1, 5);
        distribution[roundedRating] = (distribution[roundedRating] ?? 0) + 1;
        totalRating += review.rating;
      }

      final averageRating = totalRating / reviews.length;

      final summary = RatingSummary(
        averageRating: double.parse(averageRating.toStringAsFixed(1)),
        totalReviews: reviews.length,
        distribution: distribution,
      );

      await _firestore.collection('professional_stats').doc(professionalId).set(
        {
          'ratingSummary': summary.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Also update user document
      await _firestore.collection('users').doc(professionalId).update({
        'averageRating': summary.averageRating,
        'totalReviews': summary.totalReviews,
      });
    } catch (e) {
      debugPrint('Error updating rating summary: $e');
    }
  }

  // MODERATION

  /// Flag a review for moderation
  Future<bool> flagReview(String reviewId, String reason) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'isFlagged': true,
      });

      // Create flag report
      await _firestore.collection('review_flags').add({
        'reviewId': reviewId,
        'flaggedBy': _currentUserId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      debugPrint('Error flagging review: $e');
      return false;
    }
  }
}
