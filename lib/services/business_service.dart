import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/business_model.dart';
import '../models/business_post_model.dart';
import '../models/business_order_model.dart';

/// Service for managing business profiles, listings, and reviews
class BusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Singleton pattern
  static final BusinessService _instance = BusinessService._internal();
  factory BusinessService() => _instance;
  BusinessService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // BUSINESS PROFILE OPERATIONS

  /// Create a new business profile
  Future<String?> createBusiness(BusinessModel business) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('businesses')
          .add(
            business
                .copyWith(
                  userId: _currentUserId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
                .toMap(),
          );

      // Update user's business flag
      await _firestore.collection('users').doc(_currentUserId).update({
        'businessId': docRef.id,
        'businessSetupComplete': true,
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating business: $e');
      return null;
    }
  }

  /// Update business profile
  Future<bool> updateBusiness(String businessId, BusinessModel business) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .update(business.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating business: $e');
      return false;
    }
  }

  /// Get business by ID
  Future<BusinessModel?> getBusiness(String businessId) async {
    try {
      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      if (!doc.exists) return null;
      return BusinessModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting business: $e');
      return null;
    }
  }

  /// Get current user's business
  Future<BusinessModel?> getMyBusiness() async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return BusinessModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting my business: $e');
      return null;
    }
  }

  /// Stream current user's business
  Stream<BusinessModel?> watchMyBusiness() {
    if (_currentUserId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('businesses')
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return BusinessModel.fromFirestore(snapshot.docs.first);
        });
  }

  /// Check if business setup is complete
  Future<bool> isBusinessSetupComplete() async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      return doc.data()?['businessSetupComplete'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Delete business
  Future<bool> deleteBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      // Delete all listings
      final listings = await _firestore
          .collection('business_listings')
          .where('businessId', isEqualTo: businessId)
          .get();

      final batch = _firestore.batch();
      for (final doc in listings.docs) {
        batch.delete(doc.reference);
      }

      // Delete business
      batch.delete(_firestore.collection('businesses').doc(businessId));

      await batch.commit();

      // Update user
      await _firestore.collection('users').doc(_currentUserId).update({
        'businessId': FieldValue.delete(),
        'businessSetupComplete': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting business: $e');
      return false;
    }
  }

  // LISTING OPERATIONS (Products & Services)

  /// Create a new listing
  Future<String?> createListing(BusinessListing listing) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_listings')
          .add(listing.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating listing: $e');
      return null;
    }
  }

  /// Update listing
  Future<bool> updateListing(String listingId, BusinessListing listing) async {
    try {
      await _firestore
          .collection('business_listings')
          .doc(listingId)
          .update(listing.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating listing: $e');
      return false;
    }
  }

  /// Delete listing
  Future<bool> deleteListing(String listingId) async {
    try {
      await _firestore.collection('business_listings').doc(listingId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting listing: $e');
      return false;
    }
  }

  /// Get listings for a business
  Future<List<BusinessListing>> getBusinessListings(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_listings')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BusinessListing.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting listings: $e');
      return [];
    }
  }

  /// Stream listings for a business
  Stream<List<BusinessListing>> watchBusinessListings(String businessId) {
    return _firestore
        .collection('business_listings')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessListing.fromFirestore(doc))
              .toList(),
        );
  }

  /// Toggle listing availability
  Future<bool> toggleListingAvailability(
    String listingId,
    bool isAvailable,
  ) async {
    try {
      await _firestore.collection('business_listings').doc(listingId).update({
        'isAvailable': isAvailable,
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling listing: $e');
      return false;
    }
  }

  // REVIEW OPERATIONS

  /// Add a review
  Future<String?> addReview(BusinessReview review) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_reviews')
          .add(review.toMap());

      // Update business rating
      await _updateBusinessRating(review.businessId);

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding review: $e');
      return null;
    }
  }

  /// Reply to a review
  Future<bool> replyToReview(String reviewId, String reply) async {
    try {
      await _firestore.collection('business_reviews').doc(reviewId).update({
        'reply': reply,
        'replyAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error replying to review: $e');
      return false;
    }
  }

  /// Get reviews for a business
  Future<List<BusinessReview>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_reviews')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BusinessReview.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      return [];
    }
  }

  /// Stream reviews for a business
  Stream<List<BusinessReview>> watchBusinessReviews(String businessId) {
    return _firestore
        .collection('business_reviews')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessReview.fromFirestore(doc))
              .toList(),
        );
  }

  /// Update business rating based on reviews
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final reviews = await getBusinessReviews(businessId);
      if (reviews.isEmpty) return;

      final totalRating = reviews.fold<double>(
        0,
        (total, r) => total + r.rating,
      );
      final avgRating = totalRating / reviews.length;

      await _firestore.collection('businesses').doc(businessId).update({
        'rating': avgRating,
        'reviewCount': reviews.length,
      });
    } catch (e) {
      debugPrint('Error updating rating: $e');
    }
  }

  // SEARCH & DISCOVERY

  /// Search businesses
  Future<List<BusinessModel>> searchBusinesses({
    String? query,
    String? type,
    String? industry,
    double? nearLat,
    double? nearLng,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> businessQuery = _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true);

      if (type != null && type.isNotEmpty) {
        businessQuery = businessQuery.where('businessType', isEqualTo: type);
      }

      if (industry != null && industry.isNotEmpty) {
        businessQuery = businessQuery.where('industry', isEqualTo: industry);
      }

      businessQuery = businessQuery.limit(limit);

      final snapshot = await businessQuery.get();
      var businesses = snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();

      // Client-side search if query provided
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        businesses = businesses
            .where(
              (b) =>
                  b.businessName.toLowerCase().contains(lowerQuery) ||
                  (b.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  b.services.any((s) => s.toLowerCase().contains(lowerQuery)) ||
                  b.products.any((p) => p.toLowerCase().contains(lowerQuery)),
            )
            .toList();
      }

      // TODO: Add geo filtering if nearLat/nearLng provided

      return businesses;
    } catch (e) {
      debugPrint('Error searching businesses: $e');
      return [];
    }
  }

  /// Get nearby businesses
  Future<List<BusinessModel>> getNearbyBusinesses(
    double lat,
    double lng, {
    double radiusKm = 10,
    int limit = 20,
  }) async {
    // Simplified implementation - in production, use GeoFirestore
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .limit(limit * 2) // Get more and filter
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .where((b) => b.address?.hasCoordinates ?? false)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('Error getting nearby businesses: $e');
      return [];
    }
  }

  /// Get featured businesses
  Future<List<BusinessModel>> getFeaturedBusinesses({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting featured businesses: $e');
      return [];
    }
  }

  // IMAGE UPLOAD

  /// Upload business logo
  Future<String?> uploadLogo(File imageFile) async {
    return _uploadImage(imageFile, 'business_logos');
  }

  /// Upload business cover image
  Future<String?> uploadCoverImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_covers');
  }

  /// Upload listing image
  Future<String?> uploadListingImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_listings');
  }

  /// Upload business gallery image
  Future<String?> uploadGalleryImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_gallery');
  }

  Future<String?> _uploadImage(File imageFile, String folder) async {
    if (_currentUserId == null) return null;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child('$folder/$_currentUserId/$fileName');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // STATISTICS

  /// Get business statistics
  Future<Map<String, dynamic>> getBusinessStats(String businessId) async {
    try {
      final listings = await getBusinessListings(businessId);
      final reviews = await getBusinessReviews(businessId);

      final products = listings.where((l) => l.type == 'product').length;
      final services = listings.where((l) => l.type == 'service').length;

      return {
        'totalListings': listings.length,
        'products': products,
        'services': services,
        'reviews': reviews.length,
        'avgRating': reviews.isEmpty
            ? 0.0
            : reviews.fold<double>(0, (total, r) => total + r.rating) /
                  reviews.length,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'totalListings': 0,
        'products': 0,
        'services': 0,
        'reviews': 0,
        'avgRating': 0.0,
      };
    }
  }

  /// Increment business view count
  Future<void> incrementViewCount(String businessId) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  // FOLLOW OPERATIONS

  /// Follow a business
  Future<bool> followBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('business_followers').add({
        'businessId': businessId,
        'userId': _currentUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('businesses').doc(businessId).update({
        'followerCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      debugPrint('Error following business: $e');
      return false;
    }
  }

  /// Unfollow a business
  Future<bool> unfollowBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection('businesses').doc(businessId).update({
        'followerCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      debugPrint('Error unfollowing business: $e');
      return false;
    }
  }

  /// Check if user follows a business
  Future<bool> isFollowing(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ONLINE STATUS

  /// Update business online status
  Future<bool> updateOnlineStatus(String businessId, bool isOnline) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating online status: $e');
      return false;
    }
  }

  // BANK ACCOUNT OPERATIONS

  /// Update bank account details
  Future<bool> updateBankAccount(String businessId, BankAccount bankAccount) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'bankAccount': bankAccount.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating bank account: $e');
      return false;
    }
  }

  /// Remove bank account
  Future<bool> removeBankAccount(String businessId) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'bankAccount': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing bank account: $e');
      return false;
    }
  }

  // POST OPERATIONS

  /// Create a new post
  Future<String?> createPost(BusinessPost post) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_posts')
          .add(post.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  /// Update post
  Future<bool> updatePost(String postId, BusinessPost post) async {
    try {
      await _firestore
          .collection('business_posts')
          .doc(postId)
          .update(post.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating post: $e');
      return false;
    }
  }

  /// Delete post
  Future<bool> deletePost(String postId) async {
    try {
      await _firestore.collection('business_posts').doc(postId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Toggle post active status
  Future<bool> togglePostActive(String postId, bool isActive) async {
    try {
      await _firestore.collection('business_posts').doc(postId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling post: $e');
      return false;
    }
  }

  /// Get posts for a business
  Future<List<BusinessPost>> getBusinessPosts(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_posts')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BusinessPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting posts: $e');
      return [];
    }
  }

  /// Stream posts for a business
  Stream<List<BusinessPost>> watchBusinessPosts(String businessId) {
    return _firestore
        .collection('business_posts')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessPost.fromFirestore(doc))
              .toList(),
        );
  }

  // ORDER OPERATIONS

  /// Create a new order
  Future<String?> createOrder(BusinessOrder order) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_orders')
          .add(order.toMap());

      // Increment order counts for business
      await _firestore.collection('businesses').doc(order.businessId).update({
        'totalOrders': FieldValue.increment(1),
        'todayOrders': FieldValue.increment(1),
        'pendingOrders': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final orderDoc = await _firestore.collection('business_orders').doc(orderId).get();
      if (!orderDoc.exists) return false;

      final order = BusinessOrder.fromFirestore(orderDoc);
      final oldStatus = order.status;

      // Update order
      await _firestore.collection('business_orders').doc(orderId).update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == OrderStatus.completed) 'completedDate': FieldValue.serverTimestamp(),
      });

      // Update business counts
      final updates = <String, dynamic>{};

      // Decrement old status count
      if (oldStatus == OrderStatus.pending || oldStatus == OrderStatus.newOrder) {
        updates['pendingOrders'] = FieldValue.increment(-1);
      }

      // Increment new status count
      if (newStatus == OrderStatus.completed) {
        updates['completedOrders'] = FieldValue.increment(1);
        updates['totalEarnings'] = FieldValue.increment(order.totalAmount);
        updates['monthlyEarnings'] = FieldValue.increment(order.totalAmount);
        updates['todayEarnings'] = FieldValue.increment(order.totalAmount);
      } else if (newStatus == OrderStatus.cancelled) {
        updates['cancelledOrders'] = FieldValue.increment(1);
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('businesses').doc(order.businessId).update(updates);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Get orders for a business
  Future<List<BusinessOrder>> getBusinessOrders(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_orders')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BusinessOrder.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting orders: $e');
      return [];
    }
  }

  /// Stream orders for a business
  Stream<List<BusinessOrder>> watchBusinessOrders(String businessId) {
    return _firestore
        .collection('business_orders')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessOrder.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get order by ID
  Future<BusinessOrder?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('business_orders').doc(orderId).get();
      if (!doc.exists) return null;
      return BusinessOrder.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  /// Add order notes
  Future<bool> addOrderNotes(String orderId, String notes) async {
    try {
      await _firestore.collection('business_orders').doc(orderId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding order notes: $e');
      return false;
    }
  }

  /// Cancel order with reason
  Future<bool> cancelOrder(String orderId, String reason, String cancelledBy) async {
    try {
      await _firestore.collection('business_orders').doc(orderId).update({
        'status': OrderStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledBy': cancelledBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  // BUSINESS ID GENERATION

  /// Generate a unique business ID
  Future<String> generateBusinessId() async {
    final year = DateTime.now().year;
    final random = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'BIZ-$year-${random.toString().padLeft(5, '0')}';
  }
}
