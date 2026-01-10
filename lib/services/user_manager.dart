import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'profile services/photo_cache_service.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();

  User? get currentUser => _auth.currentUser;

  // User profile cache
  Map<String, dynamic>? _cachedProfile;
  final StreamController<Map<String, dynamic>?> _profileController =
      StreamController<Map<String, dynamic>?>.broadcast();

  Stream<Map<String, dynamic>?> get profileStream => _profileController.stream;
  Map<String, dynamic>? get cachedProfile => _cachedProfile;

  // Initialize and listen to auth changes
  void initialize() {
    // Listen to auth changes - don't try to access Firestore immediately
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // Add a small delay to ensure Firestore auth is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _ensureUserProfile(user);
        });
      } else {
        _cachedProfile = null;
        _profileController.add(null);
      }
    });
  }

  // Ensure user profile exists and is up to date
  Future<void> _ensureUserProfile(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Create new profile
        await _createUserProfile(user);
      } else {
        // Update last seen
        await docRef.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });

        // Load profile to cache
        await loadUserProfile(user.uid);
      }
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
    }
  }

  // Create user profile from Auth data
  Future<void> _createUserProfile(User user) async {
    try {
      // Get the best available photo URL
      String? photoUrl = user.photoURL;

      // If it's a Google photo, ensure it's high quality
      if (photoUrl!.contains('googleusercontent.com')) {
        // Remove size parameters and set to higher quality
        final baseUrl = photoUrl.split('=')[0];
        photoUrl = '$baseUrl=s400-c'; // 400x400 cropped
      }

      final profileData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'photoUrl': photoUrl,
        'provider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
        'emailVerified': user.emailVerified,
      };

      await _firestore.collection('users').doc(user.uid).set(profileData);

      // Load to cache
      _cachedProfile = profileData;
      _cachedProfile!['createdAt'] = DateTime.now();
      _cachedProfile!['lastSeen'] = DateTime.now();
      _profileController.add(_cachedProfile);

      debugPrint('Created user profile for ${user.email}');
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }

  // Load user profile to cache
  Future<Map<String, dynamic>?> loadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        _cachedProfile = doc.data();

        // Fix Google photo URL if needed
        if (_cachedProfile?['photoUrl'] != null &&
            _cachedProfile!['photoUrl'].contains('googleusercontent.com')) {
          final photoUrl = _cachedProfile!['photoUrl'] as String;
          if (!photoUrl.contains('=s400')) {
            final baseUrl = photoUrl.split('=')[0];
            _cachedProfile!['photoUrl'] = '$baseUrl=s400-c';
          }
        }

        _profileController.add(_cachedProfile);
        return _cachedProfile;
      }

      return null;
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final user = currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update(updates);

      // Update cache
      if (_cachedProfile != null) {
        _cachedProfile!.addAll(updates);
        _profileController.add(_cachedProfile);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  // Get any user's profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Check cache first
      final cachedPhotoUrl = _photoCache.getCachedPhotoUrl(userId);

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;

        // Use cached photo if available
        if (cachedPhotoUrl != null) {
          data['photoUrl'] = cachedPhotoUrl;
        } else {
          // Fix Google photo URL if needed
          if (data['photoUrl'] != null &&
              data['photoUrl'].contains('googleusercontent.com')) {
            final photoUrl = data['photoUrl'] as String;
            if (!photoUrl.contains('=s400')) {
              final baseUrl = photoUrl.split('=')[0];
              data['photoUrl'] = '$baseUrl=s400-c';
            }
          }

          // Cache the photo URL
          if (data['photoUrl'] != null) {
            _photoCache.cachePhotoUrl(userId, data['photoUrl']);
          }
        }

        return data;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Sign out and clear cache
  Future<void> signOut() async {
    try {
      // Update online status (with timeout to prevent hanging)
      final user = currentUser;
      if (user != null) {
        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('   Failed to update online status: $e');
        }
      }

      // Clear all caches
      _cachedProfile = null;
      _profileController.add(null);
      _photoCache.clearAllCache();

      debugPrint('✓ UserManager: Session cleared');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  void dispose() {
    _profileController.close();
  }
}
