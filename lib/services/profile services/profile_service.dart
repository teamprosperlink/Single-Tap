import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../res/utils/photo_url_helper.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's profile with photo
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // Create profile if it doesn't exist
        await createUserProfile(user);
        return await getCurrentUserProfile();
      }

      final data = doc.data();
      if (data != null && data['photoUrl'] != null) {
        // Fix Google photo URL if needed
        data['photoUrl'] = PhotoUrlHelper.getHighQualityGooglePhoto(
          data['photoUrl'],
        );
      }

      return data;
    } catch (e) {
      debugPrint('Error getting current user profile: $e');
      return null;
    }
  }

  // Create initial user profile
  Future<void> createUserProfile(User user) async {
    try {
      final existingDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!existingDoc.exists) {
        // Fix Google photo URL if present
        String? photoUrl = user.photoURL;
        photoUrl = PhotoUrlHelper.getHighQualityGooglePhoto(photoUrl);

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'photoUrl': photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }

  // Update user profile photo
  Future<String?> updateProfilePhoto({
    required String userId,
    Uint8List? imageBytes,
    String? imageUrl,
  }) async {
    try {
      String? photoUrl = imageUrl;

      // Upload image if bytes provided
      if (imageBytes != null) {
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('profiles/$userId/$fileName');

        final uploadTask = await ref.putData(
          imageBytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'userId': userId},
          ),
        );

        photoUrl = await uploadTask.ref.getDownloadURL();
      }

      // Update Firestore
      if (photoUrl != null) {
        await _firestore.collection('users').doc(userId).update({
          'photoUrl': photoUrl,
          'lastSeen': FieldValue.serverTimestamp(),
        });

        // Also update Firebase Auth profile
        final user = _auth.currentUser;
        if (user != null && user.uid == userId) {
          try {
            await user.updatePhotoURL(photoUrl);
            await user.reload();
          } catch (e) {
            debugPrint('Error updating auth photo URL: $e');
          }
        }
      }

      return photoUrl;
    } catch (e) {
      debugPrint('Error updating profile photo: $e');
      return null;
    }
  }

  // Get user profile by ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Ensure profile exists and is up to date
  Future<void> ensureProfileExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await createUserProfile(user);
      } else {
        // Update last seen
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
              'lastSeen': FieldValue.serverTimestamp(),
              'isOnline': true,
            })
            .catchError((e) {
              debugPrint('Error updating last seen: $e');
            });
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
    }
  }

  // Stream user profile changes
  Stream<DocumentSnapshot> streamUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
