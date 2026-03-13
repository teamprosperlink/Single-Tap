import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/catalog_item.dart';
import 'unified_post_service.dart';

class CatalogService {
  static final CatalogService _instance = CatalogService._internal();
  factory CatalogService() => _instance;
  CatalogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxItems = 100;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _catalogRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('catalog');

  // ── Read ──

  Future<List<CatalogItem>> getCatalog(String userId, {int limit = 100}) async {
    try {
      final snap = await _catalogRef(userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting catalog: $e');
      return [];
    }
  }

  Stream<List<CatalogItem>> streamCatalog(String userId) {
    return _catalogRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(maxItems)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CatalogItem.fromFirestore(doc)).toList())
        .handleError((error) {
          debugPrint('Error streaming catalog: $error');
        });
  }

  Future<List<CatalogItem>> getAvailableItems(String userId, {int limit = 50}) async {
    try {
      final snap = await _catalogRef(userId)
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => CatalogItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting available items: $e');
      return [];
    }
  }

  Future<CatalogItem?> getItem(String userId, String itemId) async {
    try {
      final doc = await _catalogRef(userId).doc(itemId).get();
      if (!doc.exists) return null;
      return CatalogItem.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting catalog item: $e');
      return null;
    }
  }

  // ── Write ──

  Future<String?> addItem(CatalogItem item) async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    try {
      // Check item limit — don't block add if count query fails
      try {
        final count = await _catalogRef(item.userId).count().get();
        if ((count.count ?? 0) >= maxItems) {
          debugPrint('Catalog limit reached ($maxItems items)');
          return null;
        }
      } catch (e) {
        debugPrint('Count check failed (proceeding with add): $e');
      }
      final docRef = await _catalogRef(item.userId).add(item.toMap());

      // Re-sync business post so new catalog item is matchable
      unawaited(UnifiedPostService().syncBusinessPost(item.userId));

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding catalog item: $e');
      rethrow;
    }
  }

  Future<bool> updateItem(
      String userId, String itemId, Map<String, dynamic> data) async {
    if (_currentUserId == null) return false;
    try {
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _catalogRef(userId).doc(itemId).update(data);

      // Re-sync business post so updated catalog item is matchable
      unawaited(UnifiedPostService().syncBusinessPost(userId));

      return true;
    } catch (e) {
      debugPrint('Error updating catalog item: $e');
      return false;
    }
  }

  Future<bool> deleteItem(String userId, String itemId) async {
    if (_currentUserId == null) return false;
    try {
      // Delete image from storage if exists
      final doc = await _catalogRef(userId).doc(itemId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final imageUrl = data?['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await _storage.refFromURL(imageUrl).delete();
          } catch (e) {
            debugPrint('Error deleting catalog image: $e');
          }
        }
      }
      await _catalogRef(userId).doc(itemId).delete();

      // Re-sync business post after catalog change
      unawaited(UnifiedPostService().syncBusinessPost(userId));

      return true;
    } catch (e) {
      debugPrint('Error deleting catalog item: $e');
      return false;
    }
  }

  Future<bool> toggleAvailability(
      String userId, String itemId, bool isAvailable) async {
    return updateItem(userId, itemId, {'isAvailable': isAvailable});
  }

  // ── Image Upload ──

  Future<String?> uploadCatalogImage(File imageFile, String userId) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref =
          _storage.ref().child('catalog_images/$userId/$fileName');
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading catalog image: $e');
      return null;
    }
  }

  Future<String> uploadCoverImage(File imageFile, String userId) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
    final ref =
        _storage.ref().child('business_covers/$userId/$fileName');
    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ── Stats ──

  Future<void> incrementItemView(String userId, String itemId) async {
    try {
      await _catalogRef(userId).doc(itemId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing item view: $e');
    }
  }

  Future<void> incrementBusinessStat(String userId, String field) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'businessProfile.$field': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing business stat: $e');
    }
  }

  Future<int> getItemCount(String userId) async {
    try {
      final count = await _catalogRef(userId).count().get();
      return count.count ?? 0;
    } catch (e) {
      debugPrint('Error getting item count: $e');
      return 0;
    }
  }

  // ── Profile View Logging ──

  Future<void> logProfileView({
    required String profileOwnerId,
    required String viewerId,
    required String viewerName,
    String? viewerPhotoUrl,
  }) async {
    // Don't log self-views
    if (profileOwnerId == viewerId) return;
    try {
      await _firestore
          .collection('users')
          .doc(profileOwnerId)
          .collection('profileViews')
          .add({
        'viewerId': viewerId,
        'viewerName': viewerName,
        'viewerPhotoUrl': viewerPhotoUrl,
        'viewedAt': FieldValue.serverTimestamp(),
      });
      // Also increment the counter
      await incrementBusinessStat(profileOwnerId, 'profileViews');
    } catch (e) {
      debugPrint('Error logging profile view: $e');
    }
  }
}
