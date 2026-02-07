import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_category_config.dart';

/// Business profile model for business accounts
///
/// ## Field Categories:
///
/// ### Core Fields (required for all businesses)
/// - id, userId, businessName, businessType, category
/// - contact, address, hours
/// - isVerified, isActive, rating, reviewCount
/// - createdAt, updatedAt
///
/// ### Display Fields (for profile presentation)
/// - description, tagline, logo, coverImage, images
/// - services, products, socialLinks
///
/// ### Category-Specific Fields (hospitality/real estate)
/// - propertyType, totalRoomCount, checkInTime, checkOutTime, etc.
/// - These are optional and only used by specific business categories
///
/// ### Analytics Fields (computed/cached)
/// - itemCount, featuredItems, totalOrders, earnings, etc.
/// - These are denormalized for fast dashboard display
///
class BusinessModel {
  // ==================== CORE FIELDS ====================
  final String id;
  final String userId;
  final String businessName;
  final String businessType;
  final BusinessCategory? category;
  final String? subType;
  final BusinessContact contact;
  final BusinessAddress? address;
  final BusinessHours? hours;
  final bool isVerified;
  final bool isActive;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ==================== DISPLAY FIELDS ====================
  final String? description;
  final String? tagline;
  final String? logo;
  final String? coverImage;
  final List<String> images;
  final List<String> services;
  final List<String> products;
  final Map<String, String> socialLinks;

  // ==================== OPTIONAL FIELDS ====================
  final String? legalName;
  final String? industry;
  final Map<String, dynamic>? categoryData;
  final bool isOnline;
  final int followerCount;
  final String? businessId;
  final int? yearEstablished;
  final String? secondaryPhone;

  // ==================== REGION-SPECIFIC (India) ====================
  final String? gstNumber;
  final String? panNumber;
  final String? licenseNumber;

  // ==================== HOSPITALITY-SPECIFIC ====================
  final String? propertyType; // Hotel/Hostel/PG/Resort/Guesthouse
  final int? totalRoomCount;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;
  final String? propertyDescription;
  final String? nearbyLandmarks;
  final String? checkInTime; // "14:00"
  final String? checkOutTime; // "11:00"
  final String? houseRules;
  final String? cancellationPolicy;

  // ==================== ANALYTICS CACHE ====================
  final double? cachedADR;
  final double? cachedRevPAR;
  final double? cachedOccupancyRate;
  final DateTime? lastAnalyticsUpdate;

  // ==================== DASHBOARD STATS ====================
  final int itemCount;
  final List<Map<String, dynamic>> featuredItems; // Max 6 items

  // Order statistics
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int todayOrders;
  final int activeBookings;

  // Earnings
  final double totalEarnings;
  final double monthlyEarnings;
  final double todayEarnings;

  // Stats reset tracking
  final DateTime? lastDailyReset;
  final DateTime? lastMonthlyReset;

  // ==================== PAYMENT ====================
  final BankAccount? bankAccount;

  BusinessModel({
    required this.id,
    required this.userId,
    required this.businessName,
    this.legalName,
    required this.businessType,
    this.industry,
    this.description,
    this.category,
    this.subType,
    this.categoryData,
    this.tagline,
    this.logo,
    this.coverImage,
    required this.contact,
    this.address,
    this.hours,
    this.images = const [],
    this.services = const [],
    this.products = const [],
    this.socialLinks = const {},
    this.isVerified = false,
    this.isActive = true,
    this.isOnline = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.followerCount = 0,
    this.businessId,
    this.yearEstablished,
    this.secondaryPhone,
    this.gstNumber,
    this.licenseNumber,
    this.panNumber,
    this.propertyType,
    this.totalRoomCount,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
    this.propertyDescription,
    this.nearbyLandmarks,
    this.checkInTime,
    this.checkOutTime,
    this.houseRules,
    this.cancellationPolicy,
    this.cachedADR,
    this.cachedRevPAR,
    this.cachedOccupancyRate,
    this.lastAnalyticsUpdate,
    this.itemCount = 0,
    this.featuredItems = const [],
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.todayOrders = 0,
    this.activeBookings = 0,
    this.totalEarnings = 0.0,
    this.monthlyEarnings = 0.0,
    this.todayEarnings = 0.0,
    this.lastDailyReset,
    this.lastMonthlyReset,
    this.bankAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory BusinessModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessModel.fromMap(data, doc.id);
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map, String id) {
    return BusinessModel(
      id: id,
      userId: map['userId'] ?? '',
      businessName: map['businessName'] ?? '',
      legalName: map['legalName'],
      businessType: map['businessType'] ?? 'Other',
      industry: map['industry'],
      description: map['description'],
      category: BusinessCategoryExtension.fromString(map['category']),
      subType: map['subType'],
      categoryData: map['categoryData'] != null
          ? Map<String, dynamic>.from(map['categoryData'])
          : null,
      tagline: map['tagline'],
      logo: map['logo'],
      coverImage: map['coverImage'],
      contact: BusinessContact.fromMap(map['contact'] ?? {}),
      address: map['address'] != null
          ? BusinessAddress.fromMap(map['address'])
          : null,
      hours: map['hours'] != null ? BusinessHours.fromMap(map['hours']) : null,
      images: List<String>.from(map['images'] ?? []),
      services: List<String>.from(map['services'] ?? []),
      products: List<String>.from(map['products'] ?? []),
      socialLinks: Map<String, String>.from(map['socialLinks'] ?? {}),
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
      isOnline: map['isOnline'] ?? false,
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      followerCount: map['followerCount'] ?? 0,
      businessId: map['businessId'],
      yearEstablished: map['yearEstablished'],
      secondaryPhone: map['secondaryPhone'],
      gstNumber: map['gstNumber'],
      licenseNumber: map['licenseNumber'],
      panNumber: map['panNumber'],
      propertyType: map['propertyType'],
      totalRoomCount: map['totalRoomCount'],
      ownerName: map['ownerName'],
      ownerPhone: map['ownerPhone'],
      ownerEmail: map['ownerEmail'],
      propertyDescription: map['propertyDescription'],
      nearbyLandmarks: map['nearbyLandmarks'],
      checkInTime: map['checkInTime'],
      checkOutTime: map['checkOutTime'],
      houseRules: map['houseRules'],
      cancellationPolicy: map['cancellationPolicy'],
      cachedADR: map['cachedADR']?.toDouble(),
      cachedRevPAR: map['cachedRevPAR']?.toDouble(),
      cachedOccupancyRate: map['cachedOccupancyRate']?.toDouble(),
      lastAnalyticsUpdate: map['lastAnalyticsUpdate'] != null
          ? (map['lastAnalyticsUpdate'] as Timestamp).toDate()
          : null,
      itemCount: map['itemCount'] ?? 0,
      featuredItems: (map['featuredItems'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      totalOrders: map['totalOrders'] ?? 0,
      pendingOrders: map['pendingOrders'] ?? 0,
      completedOrders: map['completedOrders'] ?? 0,
      cancelledOrders: map['cancelledOrders'] ?? 0,
      todayOrders: map['todayOrders'] ?? 0,
      activeBookings: map['activeBookings'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      monthlyEarnings: (map['monthlyEarnings'] ?? 0).toDouble(),
      todayEarnings: (map['todayEarnings'] ?? 0).toDouble(),
      lastDailyReset: map['lastDailyReset'] != null
          ? (map['lastDailyReset'] as Timestamp).toDate()
          : null,
      lastMonthlyReset: map['lastMonthlyReset'] != null
          ? (map['lastMonthlyReset'] as Timestamp).toDate()
          : null,
      bankAccount: map['bankAccount'] != null
          ? BankAccount.fromMap(map['bankAccount'])
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessName': businessName,
      'legalName': legalName,
      'businessType': businessType,
      'industry': industry,
      'description': description,
      'category': category?.id,
      'subType': subType,
      'categoryData': categoryData,
      'tagline': tagline,
      'logo': logo,
      'coverImage': coverImage,
      'contact': contact.toMap(),
      'address': address?.toMap(),
      'hours': hours?.toMap(),
      'images': images,
      'services': services,
      'products': products,
      'socialLinks': socialLinks,
      'isVerified': isVerified,
      'isActive': isActive,
      'isOnline': isOnline,
      'rating': rating,
      'reviewCount': reviewCount,
      'followerCount': followerCount,
      'businessId': businessId,
      'yearEstablished': yearEstablished,
      'secondaryPhone': secondaryPhone,
      'gstNumber': gstNumber,
      'licenseNumber': licenseNumber,
      'panNumber': panNumber,
      'propertyType': propertyType,
      'totalRoomCount': totalRoomCount,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
      'propertyDescription': propertyDescription,
      'nearbyLandmarks': nearbyLandmarks,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'houseRules': houseRules,
      'cancellationPolicy': cancellationPolicy,
      'cachedADR': cachedADR,
      'cachedRevPAR': cachedRevPAR,
      'cachedOccupancyRate': cachedOccupancyRate,
      'lastAnalyticsUpdate': lastAnalyticsUpdate != null ? Timestamp.fromDate(lastAnalyticsUpdate!) : null,
      'itemCount': itemCount,
      'featuredItems': featuredItems,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'todayOrders': todayOrders,
      'activeBookings': activeBookings,
      'totalEarnings': totalEarnings,
      'monthlyEarnings': monthlyEarnings,
      'todayEarnings': todayEarnings,
      'lastDailyReset': lastDailyReset != null ? Timestamp.fromDate(lastDailyReset!) : null,
      'lastMonthlyReset': lastMonthlyReset != null ? Timestamp.fromDate(lastMonthlyReset!) : null,
      'bankAccount': bankAccount?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BusinessModel copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? legalName,
    String? businessType,
    String? industry,
    String? description,
    BusinessCategory? category,
    String? subType,
    Map<String, dynamic>? categoryData,
    String? tagline,
    String? logo,
    String? coverImage,
    BusinessContact? contact,
    BusinessAddress? address,
    BusinessHours? hours,
    List<String>? images,
    List<String>? services,
    List<String>? products,
    Map<String, String>? socialLinks,
    bool? isVerified,
    bool? isActive,
    bool? isOnline,
    double? rating,
    int? reviewCount,
    int? followerCount,
    String? businessId,
    int? yearEstablished,
    String? secondaryPhone,
    String? gstNumber,
    String? licenseNumber,
    String? panNumber,
    String? propertyType,
    int? totalRoomCount,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    String? propertyDescription,
    String? nearbyLandmarks,
    String? checkInTime,
    String? checkOutTime,
    String? houseRules,
    String? cancellationPolicy,
    double? cachedADR,
    double? cachedRevPAR,
    double? cachedOccupancyRate,
    DateTime? lastAnalyticsUpdate,
    int? itemCount,
    List<Map<String, dynamic>>? featuredItems,
    int? totalOrders,
    int? pendingOrders,
    int? completedOrders,
    int? cancelledOrders,
    int? todayOrders,
    int? activeBookings,
    double? totalEarnings,
    double? monthlyEarnings,
    double? todayEarnings,
    DateTime? lastDailyReset,
    DateTime? lastMonthlyReset,
    BankAccount? bankAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      legalName: legalName ?? this.legalName,
      businessType: businessType ?? this.businessType,
      industry: industry ?? this.industry,
      description: description ?? this.description,
      category: category ?? this.category,
      subType: subType ?? this.subType,
      categoryData: categoryData ?? this.categoryData,
      tagline: tagline ?? this.tagline,
      logo: logo ?? this.logo,
      coverImage: coverImage ?? this.coverImage,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      hours: hours ?? this.hours,
      images: images ?? this.images,
      services: services ?? this.services,
      products: products ?? this.products,
      socialLinks: socialLinks ?? this.socialLinks,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      followerCount: followerCount ?? this.followerCount,
      businessId: businessId ?? this.businessId,
      yearEstablished: yearEstablished ?? this.yearEstablished,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      gstNumber: gstNumber ?? this.gstNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      panNumber: panNumber ?? this.panNumber,
      propertyType: propertyType ?? this.propertyType,
      totalRoomCount: totalRoomCount ?? this.totalRoomCount,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      propertyDescription: propertyDescription ?? this.propertyDescription,
      nearbyLandmarks: nearbyLandmarks ?? this.nearbyLandmarks,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      houseRules: houseRules ?? this.houseRules,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      cachedADR: cachedADR ?? this.cachedADR,
      cachedRevPAR: cachedRevPAR ?? this.cachedRevPAR,
      cachedOccupancyRate: cachedOccupancyRate ?? this.cachedOccupancyRate,
      lastAnalyticsUpdate: lastAnalyticsUpdate ?? this.lastAnalyticsUpdate,
      itemCount: itemCount ?? this.itemCount,
      featuredItems: featuredItems ?? this.featuredItems,
      totalOrders: totalOrders ?? this.totalOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      todayOrders: todayOrders ?? this.todayOrders,
      activeBookings: activeBookings ?? this.activeBookings,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      monthlyEarnings: monthlyEarnings ?? this.monthlyEarnings,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      lastDailyReset: lastDailyReset ?? this.lastDailyReset,
      lastMonthlyReset: lastMonthlyReset ?? this.lastMonthlyReset,
      bankAccount: bankAccount ?? this.bankAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted rating string
  String get formattedRating => rating.toStringAsFixed(1);

  /// Check if business has complete profile
  bool get isProfileComplete =>
      businessName.isNotEmpty &&
      description != null &&
      description!.isNotEmpty &&
      contact.phone != null;

  /// Check if daily stats need to be reset (fallback if Cloud Function hasn't run)
  bool get needsDailyReset {
    if (lastDailyReset == null) return true;
    final now = DateTime.now();
    final lastReset = lastDailyReset!;
    // Check if last reset was before today (midnight)
    final todayMidnight = DateTime(now.year, now.month, now.day);
    return lastReset.isBefore(todayMidnight);
  }

  /// Check if monthly stats need to be reset (fallback if Cloud Function hasn't run)
  bool get needsMonthlyReset {
    if (lastMonthlyReset == null) return true;
    final now = DateTime.now();
    final lastReset = lastMonthlyReset!;
    // Check if last reset was before this month's first day
    final thisMonthFirst = DateTime(now.year, now.month, 1);
    return lastReset.isBefore(thisMonthFirst);
  }

  /// Get effective today's orders (returns 0 if daily reset is needed)
  int get effectiveTodayOrders => needsDailyReset ? 0 : todayOrders;

  /// Get effective today's earnings (returns 0 if daily reset is needed)
  double get effectiveTodayEarnings => needsDailyReset ? 0.0 : todayEarnings;

  /// Get effective monthly earnings (returns 0 if monthly reset is needed)
  double get effectiveMonthlyEarnings => needsMonthlyReset ? 0.0 : monthlyEarnings;
}

/// Business contact information
class BusinessContact {
  final String? phone;
  final String? email;
  final String? website;
  final String? whatsapp;

  BusinessContact({
    this.phone,
    this.email,
    this.website,
    this.whatsapp,
  });

  factory BusinessContact.fromMap(Map<String, dynamic> map) {
    return BusinessContact(
      phone: map['phone'],
      email: map['email'],
      website: map['website'],
      whatsapp: map['whatsapp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'email': email,
      'website': website,
      'whatsapp': whatsapp,
    };
  }

  BusinessContact copyWith({
    String? phone,
    String? email,
    String? website,
    String? whatsapp,
  }) {
    return BusinessContact(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }
}

/// Business address
class BusinessAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  BusinessAddress({
    this.street,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory BusinessAddress.fromMap(Map<String, dynamic> map) {
    return BusinessAddress(
      street: map['street'],
      city: map['city'],
      state: map['state'],
      country: map['country'],
      postalCode: map['postalCode'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Get formatted address string
  String get formattedAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  /// Check if has location coordinates
  bool get hasCoordinates => latitude != null && longitude != null;
}

/// Business operating hours
class BusinessHours {
  final Map<String, DayHours> schedule;
  final String? timezone;

  BusinessHours({
    required this.schedule,
    this.timezone,
  });

  factory BusinessHours.fromMap(Map<String, dynamic> map) {
    final scheduleMap = <String, DayHours>{};
    final scheduleData = map['schedule'] as Map<String, dynamic>? ?? {};

    scheduleData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        scheduleMap[key] = DayHours.fromMap(value);
      }
    });

    return BusinessHours(
      schedule: scheduleMap,
      timezone: map['timezone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schedule': schedule.map((key, value) => MapEntry(key, value.toMap())),
      'timezone': timezone,
    };
  }

  /// Check if currently open
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

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
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

  /// Get default business hours
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

/// Hours for a single day
class DayHours {
  final String? open;
  final String? close;
  final bool isClosed;

  DayHours({
    this.open,
    this.close,
    this.isClosed = false,
  });

  factory DayHours.fromMap(Map<String, dynamic> map) {
    return DayHours(
      open: map['open'],
      close: map['close'],
      isClosed: map['isClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'open': open,
      'close': close,
      'isClosed': isClosed,
    };
  }

  /// Get formatted hours string
  String get formatted {
    if (isClosed) return 'Closed';
    if (open == null || close == null) return 'Not set';
    return '$open - $close';
  }
}

/// Business types
class BusinessTypes {
  static const List<String> all = [
    'Retail Store',
    'Restaurant & Cafe',
    'Professional Services',
    'Healthcare',
    'Beauty & Wellness',
    'Fitness & Sports',
    'Education & Training',
    'Technology & IT',
    'Manufacturing',
    'Construction',
    'Real Estate',
    'Transportation & Logistics',
    'Entertainment & Media',
    'Hospitality & Tourism',
    'Financial Services',
    'Non-Profit Organization',
    'Home Services',
    'Automotive',
    'Agriculture',
    'Other',
  ];

  static String getIcon(String type) {
    const icons = {
      'Retail Store': '🏪',
      'Restaurant & Cafe': '🍽️',
      'Professional Services': '💼',
      'Healthcare': '🏥',
      'Beauty & Wellness': '💆',
      'Fitness & Sports': '🏋️',
      'Education & Training': '🎓',
      'Technology & IT': '💻',
      'Manufacturing': '🏭',
      'Construction': '🏗️',
      'Real Estate': '🏠',
      'Transportation & Logistics': '🚚',
      'Entertainment & Media': '🎬',
      'Hospitality & Tourism': '🏨',
      'Financial Services': '🏦',
      'Non-Profit Organization': '🤝',
      'Home Services': '🔧',
      'Automotive': '🚗',
      'Agriculture': '🌾',
      'Other': '🏢',
    };
    return icons[type] ?? '🏢';
  }
}

/// Industry categories
class Industries {
  static const Map<String, List<String>> byBusinessType = {
    'Retail Store': [
      'Clothing & Fashion',
      'Electronics',
      'Grocery & Supermarket',
      'Furniture & Home Decor',
      'Jewelry & Accessories',
      'Books & Stationery',
      'Sports & Outdoors',
      'Pet Supplies',
      'Toys & Games',
      'General Retail',
    ],
    'Restaurant & Cafe': [
      'Fine Dining',
      'Casual Dining',
      'Fast Food',
      'Cafe & Coffee Shop',
      'Bakery',
      'Bar & Pub',
      'Food Truck',
      'Catering',
      'Cloud Kitchen',
    ],
    'Professional Services': [
      'Legal Services',
      'Accounting & Tax',
      'Consulting',
      'Marketing & Advertising',
      'HR & Recruitment',
      'Business Consulting',
      'Insurance',
      'Architecture & Design',
    ],
    'Healthcare': [
      'Hospital & Clinic',
      'Dental Care',
      'Eye Care',
      'Mental Health',
      'Pharmacy',
      'Veterinary',
      'Physical Therapy',
      'Alternative Medicine',
    ],
    'Beauty & Wellness': [
      'Salon & Spa',
      'Barbershop',
      'Nail Salon',
      'Skincare',
      'Massage Therapy',
      'Tattoo & Piercing',
      'Cosmetics',
    ],
    'Technology & IT': [
      'Software Development',
      'IT Services',
      'Web Design',
      'Mobile Apps',
      'Data Analytics',
      'Cybersecurity',
      'Cloud Services',
      'AI & Machine Learning',
    ],
  };

  static List<String> getForType(String? type) {
    if (type == null) return [];
    return byBusinessType[type] ?? [];
  }
}

/// Product/Service listing model
class BusinessListing {
  final String id;
  final String businessId;
  final String type; // 'product' or 'service'
  final String name;
  final String? description;
  final double? price;
  final String? currency;
  final List<String> images;
  final bool isAvailable;
  final DateTime createdAt;

  BusinessListing({
    required this.id,
    required this.businessId,
    required this.type,
    required this.name,
    this.description,
    this.price,
    this.currency = 'USD',
    this.images = const [],
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BusinessListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessListing(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      type: data['type'] ?? 'product',
      name: data['name'] ?? '',
      description: data['description'],
      price: data['price']?.toDouble(),
      currency: data['currency'] ?? 'USD',
      images: List<String>.from(data['images'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'type': type,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'images': images,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get formattedPrice {
    if (price == null) return 'Contact for price';
    final symbol = currency == 'USD' ? '\$' : currency;
    return '$symbol${price!.toStringAsFixed(2)}';
  }
}

/// Business review model
class BusinessReview {
  final String id;
  final String businessId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final double rating;
  final String? comment;
  final List<String> images;
  final DateTime createdAt;
  final String? reply;
  final DateTime? replyAt;

  BusinessReview({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    this.comment,
    this.images = const [],
    required this.createdAt,
    this.reply,
    this.replyAt,
  });

  factory BusinessReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessReview(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhoto: data['userPhoto'],
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'],
      images: List<String>.from(data['images'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reply: data['reply'],
      replyAt: data['replyAt'] != null
          ? (data['replyAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'reply': reply,
      'replyAt': replyAt != null ? Timestamp.fromDate(replyAt!) : null,
    };
  }
}

/// Bank account details for business payments
class BankAccount {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? branchName;
  final String? swiftCode;
  final String? upiId;
  final bool isVerified;

  BankAccount({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.branchName,
    this.swiftCode,
    this.upiId,
    this.isVerified = false,
  });

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      accountHolderName: map['accountHolderName'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      branchName: map['branchName'],
      swiftCode: map['swiftCode'],
      upiId: map['upiId'],
      isVerified: map['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'branchName': branchName,
      'swiftCode': swiftCode,
      'upiId': upiId,
      'isVerified': isVerified,
    };
  }

  BankAccount copyWith({
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? branchName,
    String? swiftCode,
    String? upiId,
    bool? isVerified,
  }) {
    return BankAccount(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branchName: branchName ?? this.branchName,
      swiftCode: swiftCode ?? this.swiftCode,
      upiId: upiId ?? this.upiId,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Get masked account number for display (e.g., ****1234)
  String get maskedAccountNumber {
    if (accountNumber.length < 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }
}
