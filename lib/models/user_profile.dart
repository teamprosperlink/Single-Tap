import 'package:cloud_firestore/cloud_firestore.dart';

/// Account type enum for user accounts
enum AccountType {
  personal,
  professional,
  business;

  String get displayName {
    switch (this) {
      case AccountType.personal:
        return 'Personal Account';
      case AccountType.professional:
        return 'Professional Account';
      case AccountType.business:
        return 'Business Account';
    }
  }

  static AccountType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'professional':
      case 'professional account':
        return AccountType.professional;
      case 'business':
      case 'business account':
        return AccountType.business;
      default:
        return AccountType.personal;
    }
  }
}

/// Account status enum
enum AccountStatus {
  active,
  pendingVerification,
  suspended;

  String get displayName {
    switch (this) {
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.pendingVerification:
        return 'Pending Verification';
      case AccountStatus.suspended:
        return 'Suspended';
    }
  }

  static AccountStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending_verification':
      case 'pendingverification':
        return AccountStatus.pendingVerification;
      case 'suspended':
        return AccountStatus.suspended;
      default:
        return AccountStatus.active;
    }
  }
}

/// Verification status enum
enum VerificationStatus {
  none,
  pending,
  verified,
  rejected;

  String get displayName {
    switch (this) {
      case VerificationStatus.none:
        return 'Not Verified';
      case VerificationStatus.pending:
        return 'Pending';
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  static VerificationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.none;
    }
  }
}

/// Professional profile data for professional accounts
class ProfessionalProfile {
  final String? businessName;
  final String? category;
  final List<String> specializations;
  final double? hourlyRate;
  final String? currency;
  final int? yearsOfExperience;
  final List<String> portfolioUrls;
  final List<String> certifications;
  final List<String> servicesOffered;

  ProfessionalProfile({
    this.businessName,
    this.category,
    this.specializations = const [],
    this.hourlyRate,
    this.currency,
    this.yearsOfExperience,
    this.portfolioUrls = const [],
    this.certifications = const [],
    this.servicesOffered = const [],
  });

  factory ProfessionalProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ProfessionalProfile();
    return ProfessionalProfile(
      businessName: map['businessName'],
      category: map['category'],
      specializations: List<String>.from(map['specializations'] ?? []),
      hourlyRate: map['hourlyRate']?.toDouble(),
      currency: map['currency'],
      yearsOfExperience: map['yearsOfExperience'],
      portfolioUrls: List<String>.from(map['portfolioUrls'] ?? []),
      certifications: List<String>.from(map['certifications'] ?? []),
      servicesOffered: List<String>.from(map['servicesOffered'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'category': category,
      'specializations': specializations,
      'hourlyRate': hourlyRate,
      'currency': currency,
      'yearsOfExperience': yearsOfExperience,
      'portfolioUrls': portfolioUrls,
      'certifications': certifications,
      'servicesOffered': servicesOffered,
    };
  }
}

/// Business profile data for business accounts
class BusinessProfile {
  final String? companyName;
  final String? registrationNumber;
  final String? taxId;
  final String? industry;
  final String? companySize;
  final String? website;
  final int? foundedYear;
  final String? description;
  final List<String> teamMembers;
  final List<String> adminUsers;

  BusinessProfile({
    this.companyName,
    this.registrationNumber,
    this.taxId,
    this.industry,
    this.companySize,
    this.website,
    this.foundedYear,
    this.description,
    this.teamMembers = const [],
    this.adminUsers = const [],
  });

  factory BusinessProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BusinessProfile();
    return BusinessProfile(
      companyName: map['companyName'],
      registrationNumber: map['registrationNumber'],
      taxId: map['taxId'],
      industry: map['industry'],
      companySize: map['companySize'],
      website: map['website'],
      foundedYear: map['foundedYear'],
      description: map['description'],
      teamMembers: List<String>.from(map['teamMembers'] ?? []),
      adminUsers: List<String>.from(map['adminUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'registrationNumber': registrationNumber,
      'taxId': taxId,
      'industry': industry,
      'companySize': companySize,
      'website': website,
      'foundedYear': foundedYear,
      'description': description,
      'teamMembers': teamMembers,
      'adminUsers': adminUsers,
    };
  }
}

/// Verification data
class VerificationData {
  final VerificationStatus status;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  VerificationData({
    this.status = VerificationStatus.none,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory VerificationData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return VerificationData();
    return VerificationData(
      status: VerificationStatus.fromString(map['status']),
      verifiedAt: map['verifiedAt'] != null
          ? (map['verifiedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }
}

class UserProfile {
  final String uid;
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? phone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final bool isVerified;
  final bool showOnlineStatus;
  final String bio;
  final List<String> interests;
  final String? fcmToken;
  final Map<String, dynamic>? additionalInfo;

  // Account type fields
  final AccountType accountType;
  final AccountStatus accountStatus;
  final ProfessionalProfile? professionalProfile;
  final BusinessProfile? businessProfile;
  final VerificationData verification;

  // Add photoUrl getter for backward compatibility
  String? get photoUrl => profileImageUrl;

  // Helper getters
  bool get isProfessional => accountType == AccountType.professional;
  bool get isBusiness => accountType == AccountType.business;
  bool get isPersonal => accountType == AccountType.personal;
  bool get isVerifiedAccount => verification.status == VerificationStatus.verified;
  bool get isPendingVerification => verification.status == VerificationStatus.pending;

  UserProfile({
    required this.uid,
    String? id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.phone,
    this.location,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.isVerified = false,
    this.showOnlineStatus = true,
    this.bio = '',
    this.interests = const [],
    this.fcmToken,
    this.additionalInfo,
    this.accountType = AccountType.personal,
    this.accountStatus = AccountStatus.active,
    this.professionalProfile,
    this.businessProfile,
    VerificationData? verification,
  }) : id = id ?? uid,
       verification = verification ?? VerificationData();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // Get display name - fallback to phone number for phone login users
    String displayName = data['name'] ?? data['displayName'] ?? '';
    if (displayName.isEmpty || displayName == 'User') {
      displayName = data['phone'] ?? '';
    }
    return UserProfile(
      uid: doc.id,
      id: doc.id,
      name: displayName,
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'],
      phone: data['phone'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      bio: data['bio'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      additionalInfo: data['additionalInfo'],
      // Account type fields
      accountType: AccountType.fromString(data['accountType']),
      accountStatus: AccountStatus.fromString(data['accountStatus']),
      professionalProfile: data['professionalProfile'] != null
          ? ProfessionalProfile.fromMap(data['professionalProfile'])
          : null,
      businessProfile: data['businessProfile'] != null
          ? BusinessProfile.fromMap(data['businessProfile'])
          : null,
      verification: VerificationData.fromMap(data['verification']),
    );
  }

  static UserProfile fromMap(Map<String, dynamic> data, String userId) {
    // Get display name - fallback to phone number for phone login users
    String displayName = data['name'] ?? data['displayName'] ?? '';
    if (displayName.isEmpty || displayName == 'User') {
      displayName = data['phone'] ?? '';
    }
    return UserProfile(
      uid: userId,
      id: userId,
      name: displayName,
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'],
      phone: data['phone'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      bio: data['bio'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      additionalInfo: data['additionalInfo'],
      // Account type fields
      accountType: AccountType.fromString(data['accountType']),
      accountStatus: AccountStatus.fromString(data['accountStatus']),
      professionalProfile: data['professionalProfile'] != null
          ? ProfessionalProfile.fromMap(data['professionalProfile'])
          : null,
      businessProfile: data['businessProfile'] != null
          ? BusinessProfile.fromMap(data['businessProfile'])
          : null,
      verification: VerificationData.fromMap(data['verification']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'photoUrl': profileImageUrl, // Also save as photoUrl for compatibility
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'isVerified': isVerified,
      'showOnlineStatus': showOnlineStatus,
      'bio': bio,
      'interests': interests,
      'fcmToken': fcmToken,
      'additionalInfo': additionalInfo,
      // Account type fields
      'accountType': accountType.name,
      'accountStatus': accountStatus.name,
      if (professionalProfile != null)
        'professionalProfile': professionalProfile!.toMap(),
      if (businessProfile != null)
        'businessProfile': businessProfile!.toMap(),
      'verification': verification.toMap(),
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? id,
    String? name,
    String? email,
    String? profileImageUrl,
    String? phone,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
    bool? isVerified,
    bool? showOnlineStatus,
    String? bio,
    List<String>? interests,
    String? fcmToken,
    Map<String, dynamic>? additionalInfo,
    AccountType? accountType,
    AccountStatus? accountStatus,
    ProfessionalProfile? professionalProfile,
    BusinessProfile? businessProfile,
    VerificationData? verification,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      fcmToken: fcmToken ?? this.fcmToken,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      accountType: accountType ?? this.accountType,
      accountStatus: accountStatus ?? this.accountStatus,
      professionalProfile: professionalProfile ?? this.professionalProfile,
      businessProfile: businessProfile ?? this.businessProfile,
      verification: verification ?? this.verification,
    );
  }
}