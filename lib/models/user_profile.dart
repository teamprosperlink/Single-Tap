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

/// Business hours for a single day
class DayHours {
  final String? open;
  final String? close;
  final bool isClosed;

  DayHours({this.open, this.close, this.isClosed = false});

  factory DayHours.fromMap(Map<String, dynamic> map) {
    return DayHours(
      open: map['open'],
      close: map['close'],
      isClosed: map['isClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'open': open, 'close': close, 'isClosed': isClosed};
  }

  String get formatted {
    if (isClosed) return 'Closed';
    if (open == null || close == null) return 'Not set';
    return '$open - $close';
  }
}

/// Weekly business hours with open/closed calculation
class BusinessHours {
  final Map<String, DayHours> schedule;
  final String? timezone;

  BusinessHours({required this.schedule, this.timezone});

  factory BusinessHours.fromMap(Map<String, dynamic> map) {
    final scheduleMap = <String, DayHours>{};
    final scheduleData = map['schedule'] as Map<String, dynamic>? ?? {};
    scheduleData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        scheduleMap[key] = DayHours.fromMap(value);
      }
    });
    return BusinessHours(schedule: scheduleMap, timezone: map['timezone']);
  }

  Map<String, dynamic> toMap() {
    return {
      'schedule': schedule.map((key, value) => MapEntry(key, value.toMap())),
      'timezone': timezone,
    };
  }

  bool get isCurrentlyOpen {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final dayHours = schedule[dayName];
    if (dayHours == null || dayHours.isClosed) return false;
    final currentMinutes = now.hour * 60 + now.minute;
    final openMinutes = _parseTime(dayHours.open);
    final closeMinutes = _parseTime(dayHours.close);
    if (openMinutes == null || closeMinutes == null) return false;
    return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  }

  String get todayHours {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final dayHours = schedule[dayName];
    if (dayHours == null) return 'Not set';
    return dayHours.formatted;
  }

  String _getDayName(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday',
    ];
    return days[weekday - 1];
  }

  int? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  static BusinessHours defaultHours() {
    return BusinessHours(
      schedule: {
        'monday': DayHours(open: '09:00', close: '18:00'),
        'tuesday': DayHours(open: '09:00', close: '18:00'),
        'wednesday': DayHours(open: '09:00', close: '18:00'),
        'thursday': DayHours(open: '09:00', close: '18:00'),
        'friday': DayHours(open: '09:00', close: '18:00'),
        'saturday': DayHours(open: '10:00', close: '16:00'),
        'sunday': DayHours(isClosed: true),
      },
    );
  }
}

/// Simplified business profile (WhatsApp Business style)
class BusinessProfile {
  final String? businessName;
  final String? description;
  final String? softLabel;
  final String? contactPhone;
  final String? contactEmail;
  final String? website;
  final String? address;
  final BusinessHours? hours;
  final int profileViews;
  final int catalogViews;
  final int enquiryCount;
  final DateTime? businessEnabledAt;
  final String? coverImageUrl;
  final bool isLive;
  final double averageRating;
  final int totalReviews;
  final Map<String, String>? socialLinks;
  final List<String> businessTypes; // products, services, bookings, events

  BusinessProfile({
    this.businessName,
    this.description,
    this.softLabel,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.address,
    this.hours,
    this.profileViews = 0,
    this.catalogViews = 0,
    this.enquiryCount = 0,
    this.businessEnabledAt,
    this.coverImageUrl,
    this.isLive = false,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.socialLinks,
    this.businessTypes = const [],
  });

  bool get isCurrentlyOpen => hours?.isCurrentlyOpen ?? false;

  factory BusinessProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BusinessProfile();
    return BusinessProfile(
      businessName: map['businessName'] ?? map['companyName'],
      description: map['description'],
      softLabel: map['softLabel'] ?? map['industry'],
      contactPhone: map['contactPhone'],
      contactEmail: map['contactEmail'],
      website: map['website'],
      address: map['address'],
      hours: map['hours'] != null
          ? BusinessHours.fromMap(map['hours'])
          : null,
      profileViews: map['profileViews'] ?? 0,
      catalogViews: map['catalogViews'] ?? 0,
      enquiryCount: map['enquiryCount'] ?? 0,
      businessEnabledAt: map['businessEnabledAt'] != null
          ? (map['businessEnabledAt'] as Timestamp).toDate()
          : null,
      coverImageUrl: map['coverImageUrl'],
      isLive: map['isLive'] ?? false,
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      socialLinks: map['socialLinks'] != null
          ? Map<String, String>.from(map['socialLinks'])
          : null,
      businessTypes: List<String>.from(map['businessTypes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'description': description,
      'softLabel': softLabel,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'website': website,
      'address': address,
      'hours': hours?.toMap(),
      'profileViews': profileViews,
      'catalogViews': catalogViews,
      'enquiryCount': enquiryCount,
      'businessEnabledAt': businessEnabledAt != null
          ? Timestamp.fromDate(businessEnabledAt!)
          : null,
      'coverImageUrl': coverImageUrl,
      'isLive': isLive,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'socialLinks': socialLinks,
      'businessTypes': businessTypes,
    };
  }

  BusinessProfile copyWith({
    String? businessName,
    String? description,
    String? softLabel,
    String? contactPhone,
    String? contactEmail,
    String? website,
    String? address,
    BusinessHours? hours,
    int? profileViews,
    int? catalogViews,
    int? enquiryCount,
    DateTime? businessEnabledAt,
    String? coverImageUrl,
    bool? isLive,
    double? averageRating,
    int? totalReviews,
    Map<String, String>? socialLinks,
    List<String>? businessTypes,
  }) {
    return BusinessProfile(
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      softLabel: softLabel ?? this.softLabel,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      address: address ?? this.address,
      hours: hours ?? this.hours,
      profileViews: profileViews ?? this.profileViews,
      catalogViews: catalogViews ?? this.catalogViews,
      enquiryCount: enquiryCount ?? this.enquiryCount,
      businessEnabledAt: businessEnabledAt ?? this.businessEnabledAt,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isLive: isLive ?? this.isLive,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      socialLinks: socialLinks ?? this.socialLinks,
      businessTypes: businessTypes ?? this.businessTypes,
    );
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