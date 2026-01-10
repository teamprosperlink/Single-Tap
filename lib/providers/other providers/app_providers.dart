import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connectivity_service.dart';
import '../../models/user_profile.dart';

/// AUTH STATE PROVIDER

/// Streams the current Firebase auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provides the current user ID (or null if not logged in)
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((user) => user?.uid).value;
});

/// CURRENT USER PROFILE PROVIDER

/// Fetches the current user's profile from Firestore
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!doc.exists) return null;

    return UserProfile.fromFirestore(doc);
  } catch (e) {
    return null;
  }
});

/// Streams the current user's profile for real-time updates
final currentUserProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return UserProfile.fromFirestore(doc);
      });
});

/// CONNECTIVITY PROVIDER

/// Streams the network connectivity status
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService().connectionChange;
});

/// Provides current connection status (sync)
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.whenData((isOnline) => isOnline).value ?? true;
});

/// USER ONLINE STATUS PROVIDER

/// Streams a specific user's online status
final userOnlineStatusProvider = StreamProvider.family<bool, String>((
  ref,
  userId,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return false;
        final data = doc.data();
        return data?['isOnline'] ?? false;
      });
});

/// USER PROFILE BY ID PROVIDER

/// Fetches any user's profile by their ID
final userProfileByIdProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!doc.exists) return null;

    return UserProfile.fromFirestore(doc);
  } catch (e) {
    return null;
  }
});

/// Streams any user's profile by their ID
final userProfileStreamByIdProvider =
    StreamProvider.family<UserProfile?, String>((ref, userId) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            return UserProfile.fromFirestore(doc);
          });
    });

/// FIREBASE INSTANCES (for dependency injection)

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
