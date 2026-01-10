import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class Activity {
  final String name;

  Activity({
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      name: map['name'] ?? '',
    );
  }

  @override
  String toString() => name;
}

class ExtendedUserProfile {
  final String uid;
  final String name;
  final String? photoUrl;
  final String? city;
  final String? location;
  final double? latitude;
  final double? longitude;
  final List<String> interests;

  // New fields
  final bool verified;
  final List<String> connectionTypes;
  final List<Activity> activities;
  final String? aboutMe;
  final bool isOnline;
  final Timestamp? lastSeen;
  final int? age;
  final String? gender; // 'Male', 'Female', 'Other', 'Prefer not to say'

  // Discovery and Privacy
  final bool discoveryModeEnabled; // Controls visibility in Live Connect
  final List<String> blockedUsers;
  final List<String> connections;
  final int connectionCount;

  // Account type fields
  final AccountType accountType;
  final AccountStatus accountStatus;
  final VerificationStatus verificationStatus;
  final String? businessName; // For Professional/Business accounts
  final String? category; // Professional category or Business industry

  // Calculated field
  double? distance; // Will be calculated based on current user's location

  ExtendedUserProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.city,
    this.location,
    this.latitude,
    this.longitude,
    this.interests = const [],
    this.verified = false,
    this.connectionTypes = const [],
    this.activities = const [],
    this.aboutMe,
    this.isOnline = false,
    this.lastSeen,
    this.age,
    this.gender,
    this.discoveryModeEnabled = true,
    this.blockedUsers = const [],
    this.connections = const [],
    this.connectionCount = 0,
    this.distance,
    this.accountType = AccountType.personal,
    this.accountStatus = AccountStatus.active,
    this.verificationStatus = VerificationStatus.none,
    this.businessName,
    this.category,
  });

  // Helper getters
  bool get isProfessional => accountType == AccountType.professional;
  bool get isBusiness => accountType == AccountType.business;
  bool get isPersonal => accountType == AccountType.personal;
  bool get isVerifiedAccount => verificationStatus == VerificationStatus.verified;
  bool get isPendingVerification => verificationStatus == VerificationStatus.pending;

  factory ExtendedUserProfile.fromMap(Map<String, dynamic> map, String uid) {
    // Parse activities from map - handle both String and Map formats
    List<Activity> activities = [];
    if (map['activities'] != null) {
      final activitiesData = map['activities'] as List<dynamic>;
      activities = activitiesData.map((item) {
        // Handle both String format (legacy) and Map format (new)
        if (item is String) {
          return Activity(name: item); // Convert String to Activity
        } else if (item is Map<String, dynamic>) {
          return Activity.fromMap(item);
        } else {
          return Activity(name: 'Unknown'); // Fallback
        }
      }).toList();
    }

    // Extract business name from professional or business profile
    String? businessName;
    String? category;
    if (map['professionalProfile'] != null) {
      businessName = map['professionalProfile']['businessName'];
      category = map['professionalProfile']['category'];
    } else if (map['businessProfile'] != null) {
      businessName = map['businessProfile']['companyName'];
      category = map['businessProfile']['industry'];
    }

    // Extract verification status
    VerificationStatus verificationStatus = VerificationStatus.none;
    if (map['verification'] != null) {
      verificationStatus = VerificationStatus.fromString(map['verification']['status']);
    }

    // Get display name - fallback to phone number for phone login users
    String displayName = map['name'] ?? map['displayName'] ?? '';
    if (displayName.isEmpty || displayName == 'User' || displayName == 'Unknown') {
      displayName = map['phone'] ?? 'Unknown';
    }

    return ExtendedUserProfile(
      uid: uid,
      name: displayName,
      photoUrl: map['photoUrl'],
      city: map['city'],
      location: map['location'] ?? map['displayLocation'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      interests: List<String>.from(map['interests'] ?? []),
      verified: map['verified'] ?? false,
      connectionTypes: List<String>.from(map['connectionTypes'] ?? []),
      activities: activities,
      aboutMe: map['aboutMe'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] as Timestamp?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      discoveryModeEnabled: map['discoveryModeEnabled'] ?? true,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      connections: List<String>.from(map['connections'] ?? []),
      connectionCount: map['connectionCount'] ?? 0,
      // Account type fields
      accountType: AccountType.fromString(map['accountType']),
      accountStatus: AccountStatus.fromString(map['accountStatus']),
      verificationStatus: verificationStatus,
      businessName: businessName,
      category: category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photoUrl': photoUrl,
      'city': city,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'interests': interests,
      'verified': verified,
      'connectionTypes': connectionTypes,
      'activities': activities.map((a) => a.name).toList(), // Store as simple strings
      'aboutMe': aboutMe,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'age': age,
      'gender': gender,
      'discoveryModeEnabled': discoveryModeEnabled,
      'blockedUsers': blockedUsers,
      'connections': connections,
      'connectionCount': connectionCount,
      // Account type fields
      'accountType': accountType.name,
      'accountStatus': accountStatus.name,
    };
  }

  // Helper to get display location
  String get displayLocation {
    if (city != null && city!.isNotEmpty) {
      return city!;
    } else if (location != null && location!.isNotEmpty) {
      return location!;
    }
    return 'Location not set';
  }

  // Helper to get formatted distance
  String? get formattedDistance {
    if (distance == null) return null;
    if (distance! < 1) {
      return '${(distance! * 1000).round()} m away';
    } else {
      return '${distance!.toStringAsFixed(1)} km away';
    }
  }

  // Check if user has specific connection type
  bool hasConnectionType(String type) {
    return connectionTypes.contains(type);
  }

  // Get activity names
  List<String> get activityNames {
    return activities.map((a) => a.name).toList();
  }
}
