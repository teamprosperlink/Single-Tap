import 'package:cloud_firestore/cloud_firestore.dart';

/// Business profile model for business accounts
class BusinessModel {
  final String id;
  final String userId;
  final String businessName;
  final String? legalName;
  final String businessType;
  final String? industry;
  final String? description;
  final String? tagline;
  final String? logo;
  final String? coverImage;
  final BusinessContact contact;
  final BusinessAddress? address;
  final BusinessHours? hours;
  final List<String> images;
  final List<String> services;
  final List<String> products;
  final Map<String, String> socialLinks;
  final bool isVerified;
  final bool isActive;
  final bool isOnline;
  final double rating;
  final int reviewCount;
  final int followerCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Business ID (auto-generated)
  final String? businessId;

  // Additional info
  final int? yearEstablished;
  final String? secondaryPhone;
  final String? gstNumber;
  final String? licenseNumber;

  // Order statistics
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int todayOrders;

  // Earnings
  final double totalEarnings;
  final double monthlyEarnings;
  final double todayEarnings;

  // Bank details
  final BankAccount? bankAccount;

  BusinessModel({
    required this.id,
    required this.userId,
    required this.businessName,
    this.legalName,
    required this.businessType,
    this.industry,
    this.description,
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
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.todayOrders = 0,
    this.totalEarnings = 0.0,
    this.monthlyEarnings = 0.0,
    this.todayEarnings = 0.0,
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
      totalOrders: map['totalOrders'] ?? 0,
      pendingOrders: map['pendingOrders'] ?? 0,
      completedOrders: map['completedOrders'] ?? 0,
      cancelledOrders: map['cancelledOrders'] ?? 0,
      todayOrders: map['todayOrders'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      monthlyEarnings: (map['monthlyEarnings'] ?? 0).toDouble(),
      todayEarnings: (map['todayEarnings'] ?? 0).toDouble(),
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
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'todayOrders': todayOrders,
      'totalEarnings': totalEarnings,
      'monthlyEarnings': monthlyEarnings,
      'todayEarnings': todayEarnings,
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
    int? totalOrders,
    int? pendingOrders,
    int? completedOrders,
    int? cancelledOrders,
    int? todayOrders,
    double? totalEarnings,
    double? monthlyEarnings,
    double? todayEarnings,
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
      totalOrders: totalOrders ?? this.totalOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      todayOrders: todayOrders ?? this.todayOrders,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      monthlyEarnings: monthlyEarnings ?? this.monthlyEarnings,
      todayEarnings: todayEarnings ?? this.todayEarnings,
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
  final String? swiftCode;
  final String? upiId;
  final bool isVerified;

  BankAccount({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
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
    String? swiftCode,
    String? upiId,
    bool? isVerified,
  }) {
    return BankAccount(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
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
