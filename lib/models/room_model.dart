import 'package:cloud_firestore/cloud_firestore.dart';
import 'base/priceable_mixin.dart';
import '../utils/currency_utils.dart';

/// Room model for hospitality businesses (Hotels, Resorts, Guesthouses)
class RoomModel with Priceable {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final RoomType type;
  final List<String> images;
  final double pricePerNight;
  @override
  final String currency;

  // Priceable mixin requirements
  @override
  double get price => pricePerNight;
  @override
  double? get originalPrice => null; // Rooms don't have original price discounts
  final int capacity;
  final int bedCount;
  final BedType bedType;
  final double? roomSize; // in sq ft/m
  final List<String> amenities;
  final int totalRooms;
  final int availableRooms;
  final bool isAvailable;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.type,
    this.images = const [],
    required this.pricePerNight,
    this.currency = 'INR',
    required this.capacity,
    this.bedCount = 1,
    this.bedType = BedType.double,
    this.roomSize,
    this.amenities = const [],
    this.totalRooms = 1,
    this.availableRooms = 1,
    this.isAvailable = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel.fromMap(data, doc.id);
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) {
    return RoomModel(
      id: id,
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      type: RoomType.fromString(map['type']) ?? RoomType.standard,
      images: List<String>.from(map['images'] ?? []),
      pricePerNight: (map['pricePerNight'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'INR',
      capacity: map['capacity'] ?? 2,
      bedCount: map['bedCount'] ?? 1,
      bedType: BedType.fromString(map['bedType']) ?? BedType.double,
      roomSize: map['roomSize']?.toDouble(),
      amenities: List<String>.from(map['amenities'] ?? []),
      totalRooms: map['totalRooms'] ?? 1,
      availableRooms: map['availableRooms'] ?? 1,
      isAvailable: map['isAvailable'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
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
      'businessId': businessId,
      'name': name,
      'description': description,
      'type': type.value,
      'images': images,
      'pricePerNight': pricePerNight,
      'currency': currency,
      'capacity': capacity,
      'bedCount': bedCount,
      'bedType': bedType.value,
      'roomSize': roomSize,
      'amenities': amenities,
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
      'isAvailable': isAvailable,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RoomModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    RoomType? type,
    List<String>? images,
    double? pricePerNight,
    String? currency,
    int? capacity,
    int? bedCount,
    BedType? bedType,
    double? roomSize,
    List<String>? amenities,
    int? totalRooms,
    int? availableRooms,
    bool? isAvailable,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      images: images ?? this.images,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      currency: currency ?? this.currency,
      capacity: capacity ?? this.capacity,
      bedCount: bedCount ?? this.bedCount,
      bedType: bedType ?? this.bedType,
      roomSize: roomSize ?? this.roomSize,
      amenities: amenities ?? this.amenities,
      totalRooms: totalRooms ?? this.totalRooms,
      availableRooms: availableRooms ?? this.availableRooms,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted price with "/night" suffix (overrides Priceable.formattedPrice)
  @override
  String get formattedPrice {
    return '${Priceable.formatPrice(pricePerNight, currency)}/night';
  }

  /// Get formatted capacity
  String get formattedCapacity {
    return '$capacity ${capacity == 1 ? 'Guest' : 'Guests'}';
  }

  /// Get availability status text
  String get availabilityText {
    if (!isAvailable) return 'Not Available';
    if (availableRooms == 0) return 'Fully Booked';
    if (availableRooms == 1) return '1 room left';
    return '$availableRooms rooms available';
  }
}

/// Room types for hospitality
enum RoomType {
  standard('Standard', 'standard'),
  deluxe('Deluxe', 'deluxe'),
  suite('Suite', 'suite'),
  executive('Executive', 'executive'),
  family('Family Room', 'family'),
  dormitory('Dormitory', 'dormitory'),
  cottage('Cottage', 'cottage'),
  villa('Villa', 'villa'),
  penthouse('Penthouse', 'penthouse');

  final String displayName;
  final String value;

  const RoomType(this.displayName, this.value);

  static RoomType? fromString(String? value) {
    if (value == null) return null;
    for (final type in RoomType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Bed types
enum BedType {
  single('Single Bed', 'single'),
  double('Double Bed', 'double'),
  queen('Queen Bed', 'queen'),
  king('King Bed', 'king'),
  twin('Twin Beds', 'twin'),
  bunk('Bunk Beds', 'bunk');

  final String displayName;
  final String value;

  const BedType(this.displayName, this.value);

  static BedType? fromString(String? value) {
    if (value == null) return null;
    for (final type in BedType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Common room amenities
class RoomAmenities {
  static const List<String> all = [
    'WiFi',
    'Air Conditioning',
    'TV',
    'Mini Bar',
    'Safe',
    'Balcony',
    'Sea View',
    'Mountain View',
    'Room Service',
    'Breakfast Included',
    'Private Bathroom',
    'Bathtub',
    'Shower',
    'Hair Dryer',
    'Iron',
    'Desk',
    'Wardrobe',
    'Tea/Coffee Maker',
    'Refrigerator',
    'Microwave',
  ];
}

/// Room booking model
class RoomBookingModel {
  final String id;
  final String roomId;
  final String businessId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? roomName; // Denormalized for display
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final int rooms;
  final double totalAmount;
  final String currency;
  final BookingStatus status;
  final String? specialRequests;
  final DateTime createdAt;

  RoomBookingModel({
    required this.id,
    required this.roomId,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.roomName,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    this.rooms = 1,
    required this.totalAmount,
    this.currency = 'INR',
    this.status = BookingStatus.pending,
    this.specialRequests,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convenience getters for bookings_tab compatibility
  String get guestName => customerName;
  String? get guestPhone => customerPhone;
  String? get notes => specialRequests;

  /// Get formatted total
  String get formattedTotal => CurrencyUtils.format(totalAmount, currency);

  factory RoomBookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomBookingModel(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      businessId: data['businessId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerEmail: data['customerEmail'],
      roomName: data['roomName'],
      checkIn: (data['checkIn'] as Timestamp).toDate(),
      checkOut: (data['checkOut'] as Timestamp).toDate(),
      guests: data['guests'] ?? 1,
      rooms: data['rooms'] ?? 1,
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'INR',
      status: BookingStatus.fromString(data['status']) ?? BookingStatus.pending,
      specialRequests: data['specialRequests'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'guests': guests,
      'rooms': rooms,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status.value,
      'specialRequests': specialRequests,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get number of nights
  int get nights => checkOut.difference(checkIn).inDays;

  /// Get formatted date range
  String get dateRange {
    return '${_formatDate(checkIn)} - ${_formatDate(checkOut)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Booking status
enum BookingStatus {
  pending('Pending', 'pending'),
  confirmed('Confirmed', 'confirmed'),
  checkedIn('Checked In', 'checked_in'),
  checkedOut('Checked Out', 'checked_out'),
  cancelled('Cancelled', 'cancelled'),
  noShow('No Show', 'no_show');

  final String displayName;
  final String value;

  const BookingStatus(this.displayName, this.value);

  static BookingStatus? fromString(String? value) {
    if (value == null) return null;
    for (final status in BookingStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
