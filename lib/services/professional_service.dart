import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/service_model.dart';
import '../models/portfolio_item_model.dart';
import '../models/user_profile.dart';

/// Service for managing professional profiles, services, and portfolio
class ProfessionalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Singleton pattern
  static final ProfessionalService _instance = ProfessionalService._internal();
  factory ProfessionalService() => _instance;
  ProfessionalService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // PROFESSIONAL PROFILE OPERATIONS

  /// Update professional profile information
  Future<bool> updateProfessionalProfile({
    required String businessName,
    required String category,
    required List<String> specializations,
    int? yearsOfExperience,
    double? hourlyRate,
    String? currency,
    List<String>? portfolioUrls,
    List<String>? certifications,
  }) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'professionalProfile': {
          'businessName': businessName,
          'category': category,
          'specializations': specializations,
          'yearsOfExperience': yearsOfExperience,
          'hourlyRate': hourlyRate,
          'currency': currency ?? 'USD',
          'portfolioUrls': portfolioUrls ?? [],
          'certifications': certifications ?? [],
          'servicesOffered': [],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'professionalSetupComplete': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating professional profile: $e');
      return false;
    }
  }

  /// Get professional profile for a user
  Future<ProfessionalProfile?> getProfessionalProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data?['professionalProfile'] == null) return null;

      return ProfessionalProfile.fromMap(data!['professionalProfile']);
    } catch (e) {
      debugPrint('Error getting professional profile: $e');
      return null;
    }
  }

  /// Check if professional setup is complete
  Future<bool> isProfessionalSetupComplete() async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      return doc.data()?['professionalSetupComplete'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // SERVICE OPERATIONS

  /// Create a new service
  Future<String?> createService(ServiceModel service) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('services')
          .add(
            service
                .copyWith(
                  userId: _currentUserId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
                .toMap(),
          );

      // Update user's service count
      await _firestore.collection('users').doc(_currentUserId).update({
        'serviceCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating service: $e');
      return null;
    }
  }

  /// Update an existing service
  Future<bool> updateService(String serviceId, ServiceModel service) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('services')
          .doc(serviceId)
          .update(service.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating service: $e');
      return false;
    }
  }

  /// Delete a service
  Future<bool> deleteService(String serviceId) async {
    if (_currentUserId == null) return false;

    try {
      // Get service to delete images
      final doc = await _firestore.collection('services').doc(serviceId).get();
      if (doc.exists) {
        final service = ServiceModel.fromFirestore(doc);

        // Delete images from storage
        for (final imageUrl in service.images) {
          await _deleteImageFromStorage(imageUrl);
        }
      }

      await _firestore.collection('services').doc(serviceId).delete();

      // Update user's service count
      await _firestore.collection('users').doc(_currentUserId).update({
        'serviceCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting service: $e');
      return false;
    }
  }

  /// Get all services for a user
  Future<List<ServiceModel>> getUserServices(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('services')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ServiceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user services: $e');
      return [];
    }
  }

  /// Get current user's services
  Future<List<ServiceModel>> getMyServices() async {
    if (_currentUserId == null) return [];
    return getUserServices(_currentUserId!);
  }

  /// Stream user's services
  Stream<List<ServiceModel>> watchUserServices(String userId) {
    return _firestore
        .collection('services')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ServiceModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream current user's services
  Stream<List<ServiceModel>> watchMyServices() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }
    return watchUserServices(_currentUserId!);
  }

  /// Toggle service active status
  Future<bool> toggleServiceActive(String serviceId, bool isActive) async {
    try {
      await _firestore.collection('services').doc(serviceId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling service: $e');
      return false;
    }
  }

  /// Search services (for marketplace)
  Future<List<ServiceModel>> searchServices({
    String? query,
    String? category,
    double? maxPrice,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> servicesQuery = _firestore
          .collection('services')
          .where('isActive', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        servicesQuery = servicesQuery.where('category', isEqualTo: category);
      }

      if (maxPrice != null) {
        servicesQuery = servicesQuery.where(
          'price',
          isLessThanOrEqualTo: maxPrice,
        );
      }

      servicesQuery = servicesQuery.limit(limit);

      final snapshot = await servicesQuery.get();
      var services = snapshot.docs
          .map((doc) => ServiceModel.fromFirestore(doc))
          .toList();

      // Client-side search if query provided
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        services = services
            .where(
              (s) =>
                  s.title.toLowerCase().contains(lowerQuery) ||
                  s.description.toLowerCase().contains(lowerQuery) ||
                  s.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)),
            )
            .toList();
      }

      return services;
    } catch (e) {
      debugPrint('Error searching services: $e');
      return [];
    }
  }

  // PORTFOLIO OPERATIONS

  /// Create a new portfolio item
  Future<String?> createPortfolioItem(PortfolioItemModel item) async {
    if (_currentUserId == null) return null;

    try {
      // Get current count for ordering
      final count = await _firestore
          .collection('portfolio')
          .where('userId', isEqualTo: _currentUserId)
          .count()
          .get();

      final docRef = await _firestore
          .collection('portfolio')
          .add(
            item
                .copyWith(
                  userId: _currentUserId,
                  order: count.count ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
                .toMap(),
          );

      // Update user's portfolio count
      await _firestore.collection('users').doc(_currentUserId).update({
        'portfolioCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating portfolio item: $e');
      return null;
    }
  }

  /// Update a portfolio item
  Future<bool> updatePortfolioItem(
    String itemId,
    PortfolioItemModel item,
  ) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('portfolio')
          .doc(itemId)
          .update(item.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating portfolio item: $e');
      return false;
    }
  }

  /// Delete a portfolio item
  Future<bool> deletePortfolioItem(String itemId) async {
    if (_currentUserId == null) return false;

    try {
      // Get item to delete images
      final doc = await _firestore.collection('portfolio').doc(itemId).get();
      if (doc.exists) {
        final item = PortfolioItemModel.fromFirestore(doc);

        // Delete images from storage
        for (final imageUrl in item.images) {
          await _deleteImageFromStorage(imageUrl);
        }
      }

      await _firestore.collection('portfolio').doc(itemId).delete();

      // Update user's portfolio count
      await _firestore.collection('users').doc(_currentUserId).update({
        'portfolioCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting portfolio item: $e');
      return false;
    }
  }

  /// Get all portfolio items for a user
  Future<List<PortfolioItemModel>> getUserPortfolio(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('portfolio')
          .where('userId', isEqualTo: userId)
          .where('isVisible', isEqualTo: true)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => PortfolioItemModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user portfolio: $e');
      return [];
    }
  }

  /// Get current user's portfolio
  Future<List<PortfolioItemModel>> getMyPortfolio() async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('portfolio')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => PortfolioItemModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting my portfolio: $e');
      return [];
    }
  }

  /// Stream user's portfolio
  Stream<List<PortfolioItemModel>> watchUserPortfolio(String userId) {
    return _firestore
        .collection('portfolio')
        .where('userId', isEqualTo: userId)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PortfolioItemModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream current user's portfolio
  Stream<List<PortfolioItemModel>> watchMyPortfolio() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }
    return watchUserPortfolio(_currentUserId!);
  }

  /// Reorder portfolio items
  Future<bool> reorderPortfolio(List<String> itemIds) async {
    if (_currentUserId == null) return false;

    try {
      final batch = _firestore.batch();

      for (int i = 0; i < itemIds.length; i++) {
        batch.update(_firestore.collection('portfolio').doc(itemIds[i]), {
          'order': i,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error reordering portfolio: $e');
      return false;
    }
  }

  // IMAGE UPLOAD OPERATIONS

  /// Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String folder) async {
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

  /// Upload service image
  Future<String?> uploadServiceImage(File imageFile) async {
    return uploadImage(imageFile, 'services');
  }

  /// Upload portfolio image
  Future<String?> uploadPortfolioImage(File imageFile) async {
    return uploadImage(imageFile, 'portfolio');
  }

  /// Delete image from storage
  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  // STATISTICS

  /// Get professional statistics
  Future<Map<String, dynamic>> getProfessionalStats() async {
    if (_currentUserId == null) {
      return {'services': 0, 'portfolio': 0, 'views': 0, 'inquiries': 0};
    }

    try {
      final services = await getMyServices();
      final portfolio = await getMyPortfolio();

      int totalViews = 0;
      int totalInquiries = 0;

      for (final service in services) {
        totalViews += service.views;
        totalInquiries += service.inquiries;
      }

      return {
        'services': services.length,
        'activeServices': services.where((s) => s.isActive).length,
        'portfolio': portfolio.length,
        'views': totalViews,
        'inquiries': totalInquiries,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {'services': 0, 'portfolio': 0, 'views': 0, 'inquiries': 0};
    }
  }

  /// Increment service view count
  Future<void> incrementServiceViews(String serviceId) async {
    try {
      await _firestore.collection('services').doc(serviceId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  /// Increment service inquiry count
  Future<void> incrementServiceInquiries(String serviceId) async {
    try {
      await _firestore.collection('services').doc(serviceId).update({
        'inquiries': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing inquiries: $e');
    }
  }
}
