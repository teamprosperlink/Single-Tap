import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton service to cache the current logged-in user's profile data
/// This prevents repeated Firestore/Auth calls for the same user's data
class CurrentUserCache {
  static final CurrentUserCache _instance = CurrentUserCache._internal();
  factory CurrentUserCache() => _instance;
  CurrentUserCache._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached user data
  Map<String, dynamic>? _cachedProfile;
  String? _cachedUserId;
  DateTime? _lastFetchTime;
  bool _isLoading = false;

  // Stream controller for profile updates
  final StreamController<Map<String, dynamic>?> _profileStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();

  // Listeners
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  /// Stream of profile updates - listen to this for real-time updates
  Stream<Map<String, dynamic>?> get profileStream =>
      _profileStreamController.stream;

  /// Get cached user ID
  String? get userId => _cachedUserId ?? _auth.currentUser?.uid;

  /// Get cached profile (instant, no async)
  Map<String, dynamic>? get profile => _cachedProfile;

  /// Get cached photo URL (instant, no async)
  String? get photoUrl => _cachedProfile?['photoUrl'];

  /// Get cached name (instant, no async)
  String get name => _cachedProfile?['name'] ?? _auth.currentUser?.displayName ?? 'User';

  /// Get cached email
  String? get email => _cachedProfile?['email'] ?? _auth.currentUser?.email;

  /// Check if profile is loaded
  bool get isLoaded => _cachedProfile != null;

  /// Check if cache is fresh (less than 5 minutes old)
  bool get isFresh {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 5);
  }

  /// Initialize cache for the current user
  /// Call this after user logs in
  Future<void> initialize() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('CurrentUserCache: No user logged in');
      return;
    }

    // If already initialized for this user and fresh, skip
    if (_cachedUserId == currentUserId && isFresh) {
      debugPrint('CurrentUserCache: Already initialized and fresh');
      return;
    }

    await _loadProfile(currentUserId);
    _setupRealtimeListener(currentUserId);
  }

  /// Load profile from Firestore
  Future<void> _loadProfile(String userId) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      debugPrint('CurrentUserCache: Loading profile for $userId');

      // First, set basic info from Firebase Auth for immediate use
      final authUser = _auth.currentUser;
      if (authUser != null && _cachedProfile == null) {
        _cachedProfile = {
          'name': authUser.displayName ?? 'User',
          'email': authUser.email,
          'photoUrl': authUser.photoURL,
          'uid': userId,
        };
        _cachedUserId = userId;
        _profileStreamController.add(_cachedProfile);
      }

      // Then fetch full profile from Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _cachedProfile = doc.data();
        _cachedProfile?['uid'] = userId;
        _cachedUserId = userId;
        _lastFetchTime = DateTime.now();
        _profileStreamController.add(_cachedProfile);
        debugPrint('CurrentUserCache: Profile loaded successfully');
      }
    } catch (e) {
      debugPrint('CurrentUserCache: Error loading profile: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Setup real-time listener for profile changes
  void _setupRealtimeListener(String userId) {
    // Cancel existing subscription
    _firestoreSubscription?.cancel();

    // Listen for profile updates
    _firestoreSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _cachedProfile = snapshot.data();
        _cachedProfile?['uid'] = userId;
        _lastFetchTime = DateTime.now();
        _profileStreamController.add(_cachedProfile);
        debugPrint('CurrentUserCache: Profile updated from Firestore');
      }
    }, onError: (e) {
      debugPrint('CurrentUserCache: Listener error: $e');
    });
  }

  /// Update specific profile fields (after user edits profile)
  /// This updates the cache immediately without waiting for Firestore
  void updateProfile(Map<String, dynamic> updates) {
    if (_cachedProfile != null) {
      _cachedProfile = {..._cachedProfile!, ...updates};
      _lastFetchTime = DateTime.now();
      _profileStreamController.add(_cachedProfile);
      debugPrint('CurrentUserCache: Profile cache updated locally');
    }
  }

  /// Update photo URL specifically (after user changes photo)
  void updatePhotoUrl(String? newPhotoUrl) {
    if (_cachedProfile != null) {
      _cachedProfile!['photoUrl'] = newPhotoUrl;
      _lastFetchTime = DateTime.now();
      _profileStreamController.add(_cachedProfile);
      debugPrint('CurrentUserCache: Photo URL updated: $newPhotoUrl');
    }
  }

  /// Force refresh the cache from Firestore
  Future<void> refresh() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      _lastFetchTime = null; // Force refresh
      await _loadProfile(currentUserId);
    }
  }

  /// Clear cache (call on logout)
  void clear() {
    debugPrint('CurrentUserCache: Clearing cache');
    _cachedProfile = null;
    _cachedUserId = null;
    _lastFetchTime = null;
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _profileStreamController.add(null);
  }

  /// Dispose resources
  void dispose() {
    _firestoreSubscription?.cancel();
    _profileStreamController.close();
  }

  /// Get a specific field from cached profile
  T? getField<T>(String field) {
    return _cachedProfile?[field] as T?;
  }

  /// Check if user has a specific field
  bool hasField(String field) {
    return _cachedProfile?.containsKey(field) ?? false;
  }
}
