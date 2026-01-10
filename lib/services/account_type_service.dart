import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Service for managing account types and related features
class AccountTypeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final AccountTypeService _instance = AccountTypeService._internal();
  factory AccountTypeService() => _instance;
  AccountTypeService._internal();

  /// Get current user's account type
  Future<AccountType> getCurrentAccountType() async {
    final user = _auth.currentUser;
    if (user == null) return AccountType.personal;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return AccountType.personal;

      final data = doc.data()!;
      return AccountType.fromString(data['accountType']);
    } catch (e) {
      debugPrint('Error getting account type: $e');
      return AccountType.personal;
    }
  }

  /// Get account type for a specific user
  Future<AccountType> getUserAccountType(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return AccountType.personal;

      final data = doc.data()!;
      return AccountType.fromString(data['accountType']);
    } catch (e) {
      debugPrint('Error getting user account type: $e');
      return AccountType.personal;
    }
  }

  /// Get verification status for current user
  Future<VerificationStatus> getCurrentVerificationStatus() async {
    final user = _auth.currentUser;
    if (user == null) return VerificationStatus.none;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return VerificationStatus.none;

      final data = doc.data()!;
      if (data['verification'] == null) return VerificationStatus.none;
      return VerificationStatus.fromString(data['verification']['status']);
    } catch (e) {
      debugPrint('Error getting verification status: $e');
      return VerificationStatus.none;
    }
  }

  /// Upgrade account to a different type
  Future<bool> upgradeAccountType(AccountType newType) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final needsVerification = newType != AccountType.personal;

      await _firestore.collection('users').doc(user.uid).update({
        'accountType': newType.name,
        'accountStatus': needsVerification ? 'pendingVerification' : 'active',
        'verification': {
          'status': needsVerification ? 'pending' : 'none',
        },
      });

      return true;
    } catch (e) {
      debugPrint('Error upgrading account type: $e');
      return false;
    }
  }

  /// Update professional profile
  Future<bool> updateProfessionalProfile(ProfessionalProfile profile) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'professionalProfile': profile.toMap(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating professional profile: $e');
      return false;
    }
  }

  /// Update business profile
  Future<bool> updateBusinessProfile(BusinessProfile profile) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'businessProfile': profile.toMap(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating business profile: $e');
      return false;
    }
  }

  /// Check if a feature is available for an account type
  bool isFeatureAvailable(String feature, AccountType accountType) {
    final features = getAccountFeatures(accountType);
    return features[feature] ?? false;
  }

  /// Get all features available for an account type
  Map<String, dynamic> getAccountFeatures(AccountType accountType) {
    switch (accountType) {
      case AccountType.personal:
        return {
          'canBuySell': true,
          'maxPostsPerDay': 5,
          'canChat': true,
          'canLiveConnect': true,
          'verifiedBadge': false,
          'portfolio': false,
          'serviceListings': false,
          'reviewsReceived': false,
          'teamMembers': false,
          'maxTeamMembers': 0,
          'analytics': false,
          'prioritySupport': false,
          'promotedListings': false,
          'bulkUpload': false,
        };

      case AccountType.professional:
        return {
          'canBuySell': true,
          'maxPostsPerDay': 20,
          'canChat': true,
          'canLiveConnect': true,
          'verifiedBadge': true,
          'portfolio': true,
          'serviceListings': true,
          'reviewsReceived': true,
          'teamMembers': false,
          'maxTeamMembers': 0,
          'analytics': true,
          'analyticsLevel': 'basic',
          'prioritySupport': false,
          'promotedListings': true,
          'bulkUpload': false,
        };

      case AccountType.business:
        return {
          'canBuySell': true,
          'maxPostsPerDay': -1, // Unlimited
          'canChat': true,
          'canLiveConnect': true,
          'verifiedBadge': true,
          'portfolio': true,
          'serviceListings': true,
          'reviewsReceived': true,
          'teamMembers': true,
          'maxTeamMembers': 10,
          'analytics': true,
          'analyticsLevel': 'advanced',
          'prioritySupport': true,
          'promotedListings': true,
          'bulkUpload': true,
        };
    }
  }

  /// Get the daily post limit for an account type
  int getPostLimit(AccountType accountType) {
    final features = getAccountFeatures(accountType);
    return features['maxPostsPerDay'] ?? 5;
  }

  /// Check if user can create more posts today
  Future<bool> canCreatePost() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final accountType = await getCurrentAccountType();
      final limit = getPostLimit(accountType);

      // Unlimited posts for business accounts
      if (limit == -1) return true;

      // Count posts created today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      return postsQuery.docs.length < limit;
    } catch (e) {
      debugPrint('Error checking post limit: $e');
      return true; // Allow by default on error
    }
  }

  /// Get remaining posts for today
  Future<int> getRemainingPostsToday() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final accountType = await getCurrentAccountType();
      final limit = getPostLimit(accountType);

      // Unlimited posts for business accounts
      if (limit == -1) return -1;

      // Count posts created today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      return (limit - postsQuery.docs.length).clamp(0, limit);
    } catch (e) {
      debugPrint('Error getting remaining posts: $e');
      return 5; // Default limit on error
    }
  }

  /// Stream user's account type changes
  Stream<AccountType> watchAccountType(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return AccountType.personal;
          final data = doc.data()!;
          return AccountType.fromString(data['accountType']);
        });
  }

  /// Stream user's verification status changes
  Stream<VerificationStatus> watchVerificationStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return VerificationStatus.none;
          final data = doc.data()!;
          if (data['verification'] == null) return VerificationStatus.none;
          return VerificationStatus.fromString(data['verification']['status']);
        });
  }

  /// Get display information for account type (for UI)
  Map<String, dynamic> getAccountTypeInfo(AccountType accountType) {
    switch (accountType) {
      case AccountType.personal:
        return {
          'name': 'Personal Account',
          'description': 'For individual buyers and sellers',
          'icon': 'person',
          'color': 0xFF2196F3, // Blue
          'badgeColor': 0xFF2196F3,
        };

      case AccountType.professional:
        return {
          'name': 'Professional Account',
          'description': 'For freelancers and service providers',
          'icon': 'badge',
          'color': 0xFF9C27B0, // Purple
          'badgeColor': 0xFF9C27B0,
        };

      case AccountType.business:
        return {
          'name': 'Business Account',
          'description': 'For businesses and organizations',
          'icon': 'business',
          'color': 0xFFFF9800, // Orange/Gold
          'badgeColor': 0xFFFFB300,
        };
    }
  }
}
