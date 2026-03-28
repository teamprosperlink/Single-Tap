import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════
//  NearbyModel — fully dynamic, no hardcoded enums
// ══════════════════════════════════════════════════════════════

class NearbyModel {
  String status;
  int totalCount;
  int radiusKm;
  NearbyUserLocation userLocation;
  List<NearbyListing> buy;
  List<NearbyListing> sell;
  List<NearbyListing> seek;
  List<NearbyListing> provide;

  NearbyModel({
    required this.status,
    required this.totalCount,
    required this.radiusKm,
    required this.userLocation,
    required this.buy,
    required this.sell,
    required this.seek,
    required this.provide,
  });

  factory NearbyModel.fromJson(Map<String, dynamic> json) {
    return NearbyModel(
      status: json['status']?.toString() ?? '',
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      radiusKm: (json['radius_km'] as num?)?.toInt() ?? 0,
      userLocation: json['user_location'] is Map
          ? NearbyUserLocation.fromJson(
              Map<String, dynamic>.from(json['user_location'] as Map))
          : NearbyUserLocation(lat: 0, lng: 0),
      buy: _parseListings(json['buy']),
      sell: _parseListings(json['sell']),
      seek: _parseListings(json['seek']),
      provide: _parseListings(json['provide']),
    );
  }

  static List<NearbyListing> _parseListings(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((x) {
      try {
        return NearbyListing.fromJson(
            x is Map ? Map<String, dynamic>.from(x) : {});
      } catch (e) {
        debugPrint('NearbyModel: skipping bad listing: $e');
        return null;
      }
    }).whereType<NearbyListing>().toList();
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'total_count': totalCount,
        'radius_km': radiusKm,
        'user_location': userLocation.toJson(),
        'buy': buy.map((x) => x.toJson()).toList(),
        'sell': sell.map((x) => x.toJson()).toList(),
        'seek': seek.map((x) => x.toJson()).toList(),
        'provide': provide.map((x) => x.toJson()).toList(),
      };

  /// Convert all listings into flat card maps for UI rendering.
  List<Map<String, dynamic>> toFlatCards() {
    final cards = <Map<String, dynamic>>[];

    void addCards(List<NearbyListing> listings, String feedCategory) {
      for (final listing in listings) {
        try {
          cards.add(listing.toCard(feedCategory));
        } catch (e) {
          debugPrint('NearbyModel.toFlatCards: skipping card: $e');
        }
      }
    }

    addCards(buy, 'buy');
    addCards(sell, 'sell');
    addCards(seek, 'seek');
    addCards(provide, 'provide');

    debugPrint('NearbyModel.toFlatCards: ${cards.length} cards '
        '(buy=${buy.length}, sell=${sell.length}, seek=${seek.length}, provide=${provide.length})');
    return cards;
  }
}

// ══════════════════════════════════════════════════════════════
//  NearbyListing — a single listing in any category
// ══════════════════════════════════════════════════════════════

class NearbyListing {
  String listingId;
  String userId;
  num distanceKm;
  Map<String, dynamic> data; // raw data map — fully dynamic
  DateTime? createdAt;
  List<String> images;
  // Top-level listing fields (from Firestore post document, outside 'data')
  double? latitude;
  double? longitude;
  String? locationName;

  NearbyListing({
    required this.listingId,
    required this.userId,
    required this.distanceKm,
    required this.data,
    this.createdAt,
    this.images = const [],
    this.latitude,
    this.longitude,
    this.locationName,
  });

  factory NearbyListing.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    // Capture top-level location fields (Firestore post fields outside 'data')
    double? lat = (json['latitude'] as num?)?.toDouble()
        ?? (json['lat'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble()
        ?? (json['lng'] as num?)?.toDouble();
    String? locName;
    final rawLocation = json['location'];
    if (rawLocation is String && rawLocation.isNotEmpty) {
      locName = rawLocation;
    } else if (rawLocation is Map) {
      locName = (rawLocation['canonical_name'] ?? rawLocation['name']
          ?? rawLocation['city'] ?? '').toString().trim();
      lat ??= (rawLocation['lat'] as num?)?.toDouble();
      lng ??= (rawLocation['lng'] as num?)?.toDouble();
    }

    // Resolve images
    List<String> imgs = [];
    for (final key in ['images', 'image_urls', 'photos']) {
      final val = json[key] ?? dataMap[key];
      if (val is List && val.isNotEmpty) {
        imgs = List<String>.from(val.map((e) => e.toString()));
        break;
      }
    }
    if (imgs.isEmpty) {
      for (final key in ['image', 'image_url', 'photo']) {
        final val = (json[key] ?? dataMap[key])?.toString() ?? '';
        if (val.isNotEmpty && val.startsWith('http')) {
          imgs = [val];
          break;
        }
      }
    }

    DateTime? created;
    try {
      if (json['created_at'] != null) {
        created = DateTime.parse(json['created_at'].toString());
      }
    } catch (_) {}

    return NearbyListing(
      listingId: json['listing_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      distanceKm: (json['distance_km'] as num?) ?? 0,
      data: dataMap,
      createdAt: created,
      images: imgs,
      latitude: lat,
      longitude: lng,
      locationName: locName != null && locName.isNotEmpty ? locName : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'user_id': userId,
        'distance_km': distanceKm,
        'data': data,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  /// Convert to flat card map for UI.
  Map<String, dynamic> toCard(String feedCategory) {
    final intent = data['intent']?.toString() ?? '';
    final subintent = data['subintent']?.toString() ?? '';
    final domain = data['domain'] is List
        ? List<String>.from(
            (data['domain'] as List).map((x) => x.toString()))
        : <String>[];
    final category = data['category'] is List
        ? List<String>.from(
            (data['category'] as List).map((x) => x.toString()))
        : <String>[];
    // Extract location name — handle Map or String
    String location = '';
    final rawLoc = data['location'];
    if (rawLoc is Map) {
      location = (rawLoc['canonical_name'] ?? rawLoc['name'] ?? rawLoc['city'] ?? '').toString().trim();
    } else if (rawLoc is String && rawLoc.isNotEmpty) {
      location = rawLoc.trim();
    }
    if (location.isEmpty) {
      final targetLoc = data['target_location'];
      if (targetLoc is Map) {
        location = (targetLoc['canonical_name'] ?? targetLoc['name'] ?? targetLoc['city'] ?? '').toString().trim();
      } else if (targetLoc is String && targetLoc.isNotEmpty) {
        location = targetLoc.trim();
      }
    }
    // Fallback: use top-level listing location name (from Firestore post)
    if (location.isEmpty && locationName != null) {
      location = locationName!;
    }
    final reasoning = data['reasoning']?.toString() ?? '';
    final targetsubintent = data['targetsubintent']?.toString() ?? '';

    // Extract from items[0] if available
    String brand = '';
    String model = '';
    String itemType = '';
    String priceStr = '';
    String condition = '';

    final items = data['items'];
    if (items is List && items.isNotEmpty) {
      final item = items.first is Map
          ? Map<String, dynamic>.from(items.first as Map)
          : <String, dynamic>{};
      final cat = item['categorical'] is Map
          ? Map<String, dynamic>.from(item['categorical'] as Map)
          : <String, dynamic>{};
      final maxMap = item['max'] is Map
          ? Map<String, dynamic>.from(item['max'] as Map)
          : <String, dynamic>{};
      final minMap = item['min'] is Map
          ? Map<String, dynamic>.from(item['min'] as Map)
          : <String, dynamic>{};

      brand = cat['brand']?.toString() ?? '';
      model = cat['model']?.toString() ?? '';
      condition = cat['condition']?.toString() ?? '';
      itemType = item['type']?.toString() ?? '';

      // Price: max.budget > max.price > range.budget > min.budget > salary
      final rangeMap = item['range'] is Map
          ? Map<String, dynamic>.from(item['range'] as Map)
          : <String, dynamic>{};
      final maxBudget = maxMap['budget'];
      final maxPrice = maxMap['price'];
      final minBudget = minMap['budget'];
      final maxSalary = maxMap['salary'];
      final minSalary = minMap['salary'];
      final rangeBudget = rangeMap['budget'];

      if (maxBudget != null && maxBudget is num && maxBudget > 0) {
        priceStr = '${maxBudget.toInt()}';
      } else if (maxPrice != null && maxPrice is num && maxPrice > 0) {
        priceStr = '${maxPrice.toInt()}';
      } else if (rangeBudget is List && rangeBudget.isNotEmpty) {
        final val = rangeBudget.first;
        if (val is num && val > 0) priceStr = '${val.toInt()}';
      } else if (minBudget != null && minBudget is num && minBudget > 0) {
        priceStr = '${minBudget.toInt()}';
      } else if (maxSalary != null && maxSalary is num && maxSalary > 0) {
        priceStr = '${maxSalary.toInt()}';
      } else if (minSalary != null && minSalary is num && minSalary > 0) {
        priceStr = '${minSalary.toInt()}';
      }
    }

    // Fallback: check top-level data fields for budget/price
    if (priceStr.isEmpty) {
      for (final key in ['budget', 'price', 'cost', 'amount']) {
        final val = data[key];
        if (val is num && val > 0) {
          priceStr = '${val.toInt()}';
          break;
        } else if (val is String && val.isNotEmpty) {
          // Strip currency symbols and parse
          final cleaned = val.replaceAll(RegExp(r'[₹$€£,\s]'), '');
          final parsed = num.tryParse(cleaned);
          if (parsed != null && parsed > 0) {
            priceStr = '${parsed.toInt()}';
            break;
          }
        }
      }
    }

    // Fallback: check data.other for budget/price
    if (priceStr.isEmpty) {
      final other = data['other'];
      if (other is Map) {
        final rng = other['range'];
        if (rng is Map) {
          for (final key in ['budget', 'price', 'cost']) {
            final val = rng[key];
            if (val is List && val.isNotEmpty) {
              final first = val.first;
              if (first is num && first > 0) {
                priceStr = '${first.toInt()}';
                break;
              }
            } else if (val is num && val > 0) {
              priceStr = '${val.toInt()}';
              break;
            }
          }
        }
        if (priceStr.isEmpty) {
          final cat = other['categorical'];
          if (cat is Map) {
            for (final key in ['budget', 'price']) {
              final val = cat[key];
              if (val is num && val > 0) {
                priceStr = '${val.toInt()}';
                break;
              } else if (val is String && val.isNotEmpty) {
                final cleaned = val.replaceAll(RegExp(r'[₹$€£,\s]'), '');
                final parsed = num.tryParse(cleaned);
                if (parsed != null && parsed > 0) {
                  priceStr = '${parsed.toInt()}';
                  break;
                }
              }
            }
          }
        }
      }
    }

    // Clean brand
    if (brand.isNotEmpty) {
      brand = brand
          .replaceAll(
            RegExp(
              r'\b(inc\.?|ltd\.?|llc\.?|corp\.?|co\.?|pvt\.?|private\.?|limited\.?)\b',
              caseSensitive: false,
            ),
            '',
          )
          .trim()
          .replaceAll(RegExp(r'[.,]+$'), '')
          .trim();
    }

    // Build title: model > brand > itemType > subintent > intent
    String title = '';
    if (model.isNotEmpty) {
      title = brand.isNotEmpty ? '$brand $model' : model;
    } else if (brand.isNotEmpty) {
      title = brand;
    } else if (itemType.isNotEmpty) {
      title = itemType;
    } else if (subintent.isNotEmpty) {
      title = subintent;
    } else {
      title = intent;
    }

    // Determine postType
    final isService = intent.toLowerCase() == 'service' ||
        feedCategory == 'seek' ||
        feedCategory == 'provide';
    final postType = isService ? 'Services' : 'Products';

    // Extract flat lat/lng — try data.location map, then data.target_location,
    // then top-level listing fields (from Firestore post document)
    double? postLat;
    double? postLng;
    final locMap = data['location'];
    if (locMap is Map) {
      postLat = (locMap['lat'] as num?)?.toDouble();
      postLng = (locMap['lng'] as num?)?.toDouble();
    }
    final tgtLocMap = data['target_location'];
    if ((postLat == null || postLng == null) && tgtLocMap is Map) {
      postLat ??= (tgtLocMap['lat'] as num?)?.toDouble();
      postLng ??= (tgtLocMap['lng'] as num?)?.toDouble();
    }
    // Fallback: top-level listing lat/lng (Firestore post fields)
    postLat ??= latitude;
    postLng ??= longitude;

    // Pre-format distance text from API value
    final String distanceText = distanceKm > 0
        ? (distanceKm < 1
            ? '${(distanceKm * 1000).round()} m'
            : '${distanceKm.toStringAsFixed(1)} km')
        : '';

    return {
      'listing_id': listingId,
      'user_id': userId,
      'distance_km': distanceKm,
      'distanceText': distanceText,
      'latitude': postLat,
      'longitude': postLng,
      'title': title,
      'brand': brand,
      'model': model,
      'price': priceStr.isNotEmpty ? num.tryParse(priceStr) ?? priceStr : '',
      'location': location,
      'target_location': data['target_location'],
      '_raw_location': data['location'],
      '_raw_target_location': data['target_location'],
      'domain': domain,
      'category': category,
      'intent': intent,
      'subintent': subintent,
      'targetsubintent': targetsubintent,
      'item_type': itemType,
      'condition': condition,
      'reasoning': reasoning,
      'feedCategory': feedCategory,
      'postType': postType,
      'images': images,
      'imageUrl': images.isNotEmpty ? images.first : '',
      'originalPrompt': title,
      'created_at': createdAt?.toIso8601String() ?? '',
    };
  }
}

// ══════════════════════════════════════════════════════════════
//  NearbyUserLocation
// ══════════════════════════════════════════════════════════════

class NearbyUserLocation {
  double lat;
  double lng;

  NearbyUserLocation({required this.lat, required this.lng});

  factory NearbyUserLocation.fromJson(Map<String, dynamic> json) =>
      NearbyUserLocation(
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
