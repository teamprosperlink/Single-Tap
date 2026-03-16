import 'dart:convert';
import 'package:flutter/foundation.dart';

ProductModels productModelsFromJson(String str) =>
    ProductModels.fromJson(json.decode(str));

String productModelsToJson(ProductModels data) =>
    json.encode(data.toJson());

// ══════════════════════════════════════════════════════════════
//  Response Envelope — /search-and-match
// ══════════════════════════════════════════════════════════════

class ProductModels {
  String status;
  String listingId;
  List<String> matchIds;
  String queryText;
  QueryJson? queryJson;
  bool hasMatches;
  int matchCount;
  List<MatchedListing> matchedListings;
  bool similarMatchingEnabled;
  int similarCount;
  List<MatchedListing> similarListings;
  String message;

  ProductModels({
    required this.status,
    required this.listingId,
    required this.matchIds,
    required this.queryText,
    this.queryJson,
    required this.hasMatches,
    required this.matchCount,
    required this.matchedListings,
    required this.similarMatchingEnabled,
    required this.similarCount,
    required this.similarListings,
    required this.message,
  });

  factory ProductModels.fromJson(Map<String, dynamic> json) => ProductModels(
        status: json['status'] ?? '',
        listingId: json['listing_id'] ?? '',
        matchIds: json['match_ids'] != null
            ? List<String>.from(
                json['match_ids'].map((x) => x.toString()))
            : [],
        queryText: json['query_text'] ?? '',
        queryJson: _tryParseQueryJson(json['query_json']),
        hasMatches: json['has_matches'] ?? false,
        matchCount: (json['match_count'] as num?)?.toInt() ?? 0,
        matchedListings: json['matched_listings'] != null
            ? (json['matched_listings'] as List)
                .map((x) {
                  try {
                    return MatchedListing.fromJson(
                        Map<String, dynamic>.from(x as Map));
                  } catch (e) {
                    debugPrint('ProductModels: skipping bad matched_listing: $e');
                    return null;
                  }
                })
                .whereType<MatchedListing>()
                .toList()
            : [],
        similarMatchingEnabled:
            json['similar_matching_enabled'] ?? false,
        similarCount: (json['similar_count'] as num?)?.toInt() ?? 0,
        similarListings: json['similar_listings'] != null
            ? (json['similar_listings'] as List)
                .map((x) {
                  try {
                    return MatchedListing.fromJson(
                        Map<String, dynamic>.from(x as Map));
                  } catch (e) {
                    debugPrint('ProductModels: skipping bad similar_listing: $e');
                    return null;
                  }
                })
                .whereType<MatchedListing>()
                .toList()
            : [],
        message: json['message'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'listing_id': listingId,
        'match_ids': matchIds,
        'query_text': queryText,
        'query_json': queryJson?.toJson(),
        'has_matches': hasMatches,
        'match_count': matchCount,
        'matched_listings':
            matchedListings.map((x) => x.toJson()).toList(),
        'similar_matching_enabled': similarMatchingEnabled,
        'similar_count': similarCount,
        'similar_listings':
            similarListings.map((x) => x.toJson()).toList(),
        'message': message,
      };

  /// Safely parse QueryJson — never let it crash the entire model parsing.
  static QueryJson? _tryParseQueryJson(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    try {
      return QueryJson.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('ProductModels: queryJson parse failed (non-fatal): $e');
      return null;
    }
  }

  /// Clean brand name: remove corporate suffixes and title-case.
  static String cleanBrand(String raw) {
    if (raw.isEmpty) return raw;
    var cleaned = raw
        .replaceAll(
          RegExp(
            r'\b(inc\.?|ltd\.?|llc\.?|corp\.?|co\.?|pvt\.?|private\.?|limited\.?|corporation\.?|company\.?)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'[.,]+$'), '').trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) =>
            '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Convert API response to card list format used by home screen UI.
  List<Map<String, dynamic>> toCardList() {
    final cards = <Map<String, dynamic>>[];
    final allListings = [...matchedListings, ...similarListings];
    debugPrint(
        'ProductModels.toCardList: total=${allListings.length} '
        '(matched=${matchedListings.length}, similar=${similarListings.length})');

    for (int i = 0; i < allListings.length; i++) {
      final listing = allListings[i];
      final data = listing.data;
      debugPrint(
          'ProductModels [$i]: listingId=${listing.listingId}, '
          'userId=${listing.userId}, intent=${data.intent}, '
          'subintent=${data.subintent}');

      // Detect mutual/connect format: items empty but self/other has data
      final isMutualConnect = data.items.isEmpty &&
          (data.other?.categorical.isNotEmpty == true ||
              data.selfData?.categorical.isNotEmpty == true);

      String name = '';
      String brand = '';
      String model = '';
      String condition = '';
      String quality = '';
      String priceStr = '';
      String itemType = '';
      String variant = '';
      String subVariant = '';
      String color = '';
      String budgetStr = '';
      String storage = '';

      if (isMutualConnect) {
        // ── MUTUAL / CONNECT FORMAT ──
        final otherCat = data.other?.categorical ?? {};
        final selfCat = data.selfData?.categorical ?? {};

        name = data.subintent.isNotEmpty
            ? data.subintent
            : data.intent;

        final details = <String>[];
        if (otherCat['gender'] != null) {
          details.add(otherCat['gender'].toString());
        }
        final otherMin = data.other?.min ?? {};
        final otherMax = data.other?.max ?? {};
        if (otherMin['age'] != null && otherMax['age'] != null) {
          details.add('${otherMin['age']}-${otherMax['age']} yrs');
        }
        if (otherCat['diet'] != null) {
          details.add(otherCat['diet'].toString());
        }
        if (details.isNotEmpty) condition = details.join(' · ');

        debugPrint(
            'ProductModels card (mutual): selfCat=$selfCat, '
            'otherCat=$otherCat, '
            'smartMessage=${listing.smartMessage}, '
            'recommendation=${listing.recommendation}');
      } else {
        // ── PRODUCT / SERVICE FORMAT ──
        if (data.items.isNotEmpty) {
          final item = data.items.first;
          final cat = item.categorical;
          brand = cat['brand']?.toString() ?? '';
          model = cat['model']?.toString() ?? '';
          condition = cat['condition']?.toString() ?? '';
          quality = cat['quality']?.toString() ?? '';
          variant = cat['variant']?.toString() ?? '';
          subVariant = cat['sub_variant']?.toString() ?? '';
          color = cat['color']?.toString() ?? '';
          itemType = item.type;

          // Budget from range
          final rangeBudget = item.range['budget'];
          if (rangeBudget is List && rangeBudget.isNotEmpty) {
            final budgetVal = rangeBudget.first;
            if (budgetVal is num && budgetVal > 0) {
              budgetStr = '₹${budgetVal.toInt()}';
            }
          }

          // Storage from range
          final rangeStorage = item.range['storage'];
          if (rangeStorage is List && rangeStorage.isNotEmpty) {
            final storageVal = rangeStorage.first;
            if (storageVal is num && storageVal > 0) {
              storage = '${storageVal.toInt()} GB';
            }
          }

          // Price: max.price > min.price > budget > max.salary > min.salary
          final maxPrice = item.max['price'];
          final minPrice = item.min['price'];
          final maxSalary = item.max['salary'];
          final minSalary = item.min['salary'];

          if (maxPrice != null && maxPrice is num && maxPrice > 0) {
            priceStr = '₹$maxPrice';
          } else if (minPrice != null &&
              minPrice is num &&
              minPrice > 0) {
            priceStr = '₹$minPrice';
          } else if (budgetStr.isNotEmpty) {
            priceStr = budgetStr;
          } else if (maxSalary != null &&
              maxSalary is num &&
              maxSalary > 0) {
            priceStr = '₹$maxSalary';
          } else if (minSalary != null &&
              minSalary is num &&
              minSalary > 0) {
            priceStr = '₹$minSalary';
          }
        }

        // Override with bonus attributes (dynamic keys)
        final bonus = listing.bonusAttributes;
        if (bonus.isNotEmpty) {
          final bBrand =
              bonus['brand'] ?? bonus['items[0].brand'];
          final bCondition =
              bonus['condition'] ?? bonus['items[0].condition'];
          final bQuality =
              bonus['quality'] ?? bonus['items[0].quality'];
          final bPrice =
              bonus['price'] ?? bonus['items[0].price'];
          final bModel =
              bonus['model'] ?? bonus['items[0].model'];
          final bVariant =
              bonus['variant'] ?? bonus['items[0].variant'];
          final bSubVariant =
              bonus['sub_variant'] ?? bonus['items[0].sub_variant'];
          final bColor =
              bonus['color'] ?? bonus['items[0].color'];
          final bBudget =
              bonus['budget'] ?? bonus['items[0].budget'];
          final bStorage =
              bonus['storage'] ?? bonus['items[0].storage'];

          if (bBrand != null) brand = bBrand.toString();
          if (bCondition != null) condition = bCondition.toString();
          if (bQuality != null) quality = bQuality.toString();
          if (bPrice != null) priceStr = '₹$bPrice';
          if (bModel != null) model = bModel.toString();
          if (bVariant != null) variant = bVariant.toString();
          if (bSubVariant != null) subVariant = bSubVariant.toString();
          if (bColor != null) color = bColor.toString();
          if (bBudget != null && bBudget is num && bBudget > 0) {
            budgetStr = '₹${bBudget.toInt()}';
            if (priceStr.isEmpty) priceStr = budgetStr;
          }
          if (bStorage != null && bStorage is num && bStorage > 0) {
            storage = '${bStorage.toInt()} GB';
          }
        }

        // Clean brand name
        brand = cleanBrand(brand);

        // Build display name: model > brand > name > item_type > subintent > intent
        final catName = data.items.isNotEmpty
            ? (data.items.first.categorical['name']?.toString() ??
                '')
            : '';
        if (data.items.isNotEmpty) itemType = data.items.first.type;

        name = model.isNotEmpty
            ? (brand.isNotEmpty ? '$brand $model' : model)
            : (brand.isNotEmpty
                ? brand
                : (catName.isNotEmpty
                    ? catName
                    : (itemType.isNotEmpty
                        ? itemType
                        : (data.subintent.isNotEmpty
                            ? data.subintent
                            : data.intent))));

        debugPrint(
            'ProductModels card (product/service): intent=${data.intent}, '
            'subintent=${data.subintent}, catName=$catName, '
            'itemType=$itemType, brand=$brand, model=$model, '
            'domain=${data.domain}, price=$priceStr, name=$name');
      }

      // ── LOCATION ──
      String locationStr = '';
      Map<String, dynamic>? rawLocation;
      if (data.location is Map) {
        final locMap =
            Map<String, dynamic>.from(data.location as Map);
        locationStr = locMap['name']?.toString() ??
            locMap['canonical_name']?.toString() ?? '';
        // Coordinates: direct or nested under 'coordinates'
        if (locMap['coordinates'] is Map) {
          final coords = Map<String, dynamic>.from(
              locMap['coordinates'] as Map);
          rawLocation = {
            'lat': coords['lat'],
            'lng': coords['lng'],
          };
        } else if (locMap['lat'] != null && locMap['lng'] != null) {
          rawLocation = {
            'lat': locMap['lat'],
            'lng': locMap['lng']
          };
        }
        // Route mode fallback
        if (locationStr.isEmpty) {
          final origin = locMap['origin']?.toString() ?? '';
          final destination =
              locMap['destination']?.toString() ?? '';
          if (origin.isNotEmpty && destination.isNotEmpty) {
            locationStr = '$origin → $destination';
          }
        }
      } else if (data.location is String) {
        locationStr = data.location as String;
      }

      // Category from domain
      final category =
          data.domain.isNotEmpty ? data.domain.first : '';

      // Score
      final scorePercent =
          (listing.similarityScore * 100).toStringAsFixed(0);
      final rating =
          (listing.similarityScore * 5).toStringAsFixed(1);

      // Smart message
      final smartMessage = listing.smartMessage ?? '';

      // Use listing reasoning if available, fallback to queryJson
      final listingReasoning = data.reasoning.isNotEmpty
          ? data.reasoning
          : (queryJson?.reasoning ?? '');

      cards.add({
        'name': name,
        'model': model,
        'brand': brand,
        'budget': budgetStr,
        'category': category,
        'price': priceStr,
        'location': locationStr,
        'rating': rating,
        'image': listing.images.isNotEmpty
            ? listing.images.first
            : '',
        'images': listing.images,
        'match_type': listing.matchType,
        'match_score': '$scorePercent%',
        'condition': condition,
        'quality': quality,
        'variant': variant,
        'sub_variant': subVariant,
        'color': color,
        'storage': storage,
        'intent': data.intent,
        'subintent': data.subintent,
        'smart_message': smartMessage,
        'listing_id': listing.listingId,
        'user_id': listing.userId,
        '_raw_location': rawLocation,
        'place_metadata': data.placeMetadata,
        'item_type': itemType,
        'domain': data.domain,
        'targetsubintent': data.targetsubintent,
        'similarity_score': listing.similarityScore,
        'reasoning': listingReasoning,
        'recommendation': listing.recommendation ?? '',
        'bonus_attributes': listing.bonusAttributes,
        'satisfied_constraints': listing.satisfiedConstraints
                ?.map((c) => c.toJson())
                .toList() ??
            [],
        'unsatisfied_constraints': listing.unsatisfiedConstraints
                ?.map((c) => c.toJson())
                .toList() ??
            [],
        'relation': listing.relation ?? '',
        'data_category': data.category,
      });
    }

    return cards;
  }
}

// ══════════════════════════════════════════════════════════════
//  MatchedListing — both exact and similar matches
// ══════════════════════════════════════════════════════════════

class MatchedListing {
  String listingId;
  String userId;
  ListingData data;
  String matchType;
  double similarityScore;
  Map<String, dynamic> bonusAttributes;
  List<String> images;
  // Similar variant fields
  String? relation;
  List<MatchConstraint>? satisfiedConstraints;
  List<MatchConstraint>? unsatisfiedConstraints;
  String? smartMessage;
  String? recommendation;

  MatchedListing({
    required this.listingId,
    required this.userId,
    required this.data,
    required this.matchType,
    required this.similarityScore,
    this.bonusAttributes = const {},
    this.images = const [],
    this.relation,
    this.satisfiedConstraints,
    this.unsatisfiedConstraints,
    this.smartMessage,
    this.recommendation,
  });

  factory MatchedListing.fromJson(Map<String, dynamic> json) {
    final dataMap =
        Map<String, dynamic>.from(json['data'] ?? {});

    // Resolve images from multiple possible keys
    List<String>? resolvedImages;
    for (final key in [
      'images',
      'image_urls',
      'photos',
      'thumbnails'
    ]) {
      final val = json[key] ?? dataMap[key];
      if (val is List && val.isNotEmpty) {
        resolvedImages =
            List<String>.from(val.map((e) => e.toString()));
        break;
      }
    }
    if (resolvedImages == null || resolvedImages.isEmpty) {
      for (final key in [
        'image',
        'image_url',
        'photo',
        'thumbnail',
        'photo_url',
        'thumbnail_url'
      ]) {
        final val =
            (json[key] ?? dataMap[key])?.toString() ?? '';
        if (val.isNotEmpty && val.startsWith('http')) {
          resolvedImages = [val];
          break;
        }
      }
    }

    // Parse satisfied constraints
    List<MatchConstraint>? satisfied;
    if (json['satisfied_constraints'] is List) {
      satisfied = (json['satisfied_constraints'] as List)
          .whereType<Map>()
          .map((x) => MatchConstraint.fromJson(
              Map<String, dynamic>.from(x)))
          .toList();
    }

    // Parse unsatisfied constraints
    List<MatchConstraint>? unsatisfied;
    if (json['unsatisfied_constraints'] is List) {
      unsatisfied = (json['unsatisfied_constraints'] as List)
          .whereType<Map>()
          .map((x) => MatchConstraint.fromJson(
              Map<String, dynamic>.from(x)))
          .toList();
    }

    // Bonus attributes as dynamic map
    Map<String, dynamic> bonus = {};
    if (json['bonus_attributes'] is Map) {
      bonus = Map<String, dynamic>.from(
          json['bonus_attributes'] as Map);
    }

    debugPrint(
        'MatchedListing.fromJson: listing_id=${json["listing_id"]}, '
        'images_resolved=${resolvedImages?.length ?? 0}, '
        'satisfied=${satisfied?.length ?? 0}, '
        'unsatisfied=${unsatisfied?.length ?? 0}, '
        'smart_message=${json["smart_message"]}, '
        'keys=${json.keys.toList()}');

    return MatchedListing(
      listingId: json['listing_id'] ?? '',
      userId: json['user_id'] ?? '',
      data: ListingData.fromJson(dataMap),
      matchType: json['match_type'] ?? '',
      similarityScore:
          (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      bonusAttributes: bonus,
      images: resolvedImages ?? [],
      relation: json['relation']?.toString(),
      satisfiedConstraints: satisfied,
      unsatisfiedConstraints: unsatisfied,
      smartMessage: json['smart_message']?.toString(),
      recommendation: json['recommendation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'user_id': userId,
        'data': data.toJson(),
        'match_type': matchType,
        'similarity_score': similarityScore,
        if (bonusAttributes.isNotEmpty)
          'bonus_attributes': bonusAttributes,
        if (relation != null) 'relation': relation,
        if (satisfiedConstraints != null)
          'satisfied_constraints':
              satisfiedConstraints!.map((c) => c.toJson()).toList(),
        if (unsatisfiedConstraints != null)
          'unsatisfied_constraints':
              unsatisfiedConstraints!.map((c) => c.toJson()).toList(),
        if (smartMessage != null) 'smart_message': smartMessage,
        if (recommendation != null)
          'recommendation': recommendation,
      };
}

// ══════════════════════════════════════════════════════════════
//  MatchConstraint — satisfied / unsatisfied constraint entry
// ══════════════════════════════════════════════════════════════

class MatchConstraint {
  String field;
  String path;
  String type;
  String required;
  String actual;
  bool passed;
  String? deviation;
  String? direction;

  MatchConstraint({
    required this.field,
    this.path = '',
    this.type = '',
    required this.required,
    required this.actual,
    required this.passed,
    this.deviation,
    this.direction,
  });

  factory MatchConstraint.fromJson(Map<String, dynamic> json) =>
      MatchConstraint(
        field: json['field']?.toString() ?? json['key']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        required: json['required']?.toString() ?? '',
        actual: json['actual']?.toString() ?? json['candidate']?.toString() ?? '',
        passed: json['passed'] ?? false,
        deviation: json['deviation']?.toString(),
        direction: json['direction']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'field': field,
        'path': path,
        'type': type,
        'required': required,
        'actual': actual,
        'passed': passed,
        if (deviation != null) 'deviation': deviation,
        if (direction != null) 'direction': direction,
      };
}

// ══════════════════════════════════════════════════════════════
//  ListingData — the `data` object inside matched/similar listing
// ══════════════════════════════════════════════════════════════

class ListingData {
  String intent;
  String subintent;
  List<String> domain;
  List<String> category;
  List<DataItem> items;
  List<dynamic> itemexclusions;
  SelfOther? other;
  Map<String, dynamic> otherexclusions;
  SelfOther? selfData;
  Map<String, dynamic> selfexclusions;
  dynamic location;
  String locationmode;
  List<dynamic> locationexclusions;
  String reasoning;
  Map<String, dynamic>? placeMetadata;
  String targetsubintent;

  ListingData({
    required this.intent,
    required this.subintent,
    required this.domain,
    required this.category,
    required this.items,
    required this.itemexclusions,
    this.other,
    this.otherexclusions = const {},
    this.selfData,
    this.selfexclusions = const {},
    this.location,
    required this.locationmode,
    required this.locationexclusions,
    this.reasoning = '',
    this.placeMetadata,
    this.targetsubintent = '',
  });

  factory ListingData.fromJson(Map<String, dynamic> json) =>
      ListingData(
        intent: json['intent']?.toString() ?? '',
        subintent: json['subintent']?.toString() ?? '',
        domain: json['domain'] is List
            ? List<String>.from(
                (json['domain'] as List).map((x) => x.toString()))
            : json['domain'] is String
                ? [json['domain'] as String]
                : [],
        category: json['category'] is List
            ? List<String>.from(
                (json['category'] as List).map((x) => x.toString()))
            : json['category'] is String
                ? [json['category'] as String]
                : [],
        items: json['items'] is List
            ? List<DataItem>.from(
                (json['items'] as List)
                    .map((x) {
                      try {
                        return DataItem.fromJson(x is Map
                            ? Map<String, dynamic>.from(x)
                            : {});
                      } catch (e) {
                        debugPrint(
                            'ListingData.fromJson: skipping invalid item: $e');
                        return null;
                      }
                    })
                    .where((x) => x != null)
                    .cast<DataItem>())
            : [],
        itemexclusions: json['itemexclusions'] is List
            ? List<dynamic>.from(json['itemexclusions'] as List)
            : [],
        other: json['other'] != null && json['other'] is Map
            ? SelfOther.fromJson(
                Map<String, dynamic>.from(json['other'] as Map))
            : null,
        otherexclusions: json['otherexclusions'] is Map
            ? Map<String, dynamic>.from(
                json['otherexclusions'] as Map)
            : {},
        selfData: json['self'] != null && json['self'] is Map
            ? SelfOther.fromJson(
                Map<String, dynamic>.from(json['self'] as Map))
            : null,
        selfexclusions: json['selfexclusions'] is Map
            ? Map<String, dynamic>.from(
                json['selfexclusions'] as Map)
            : {},
        location: json['location'],
        locationmode: json['locationmode']?.toString() ?? '',
        locationexclusions: json['locationexclusions'] is List
            ? List<dynamic>.from(json['locationexclusions'] as List)
            : [],
        reasoning: json['reasoning']?.toString() ?? '',
        placeMetadata: json['place_metadata'] is Map
            ? Map<String, dynamic>.from(json['place_metadata'] as Map)
            : null,
        targetsubintent: json['targetsubintent']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'subintent': subintent,
        'domain': domain,
        'category': category,
        'items': items.map((x) => x.toJson()).toList(),
        'itemexclusions': itemexclusions,
        'other': other?.toJson(),
        'otherexclusions': otherexclusions,
        'self': selfData?.toJson(),
        'selfexclusions': selfexclusions,
        'location': location,
        'locationmode': locationmode,
        'locationexclusions': locationexclusions,
        'reasoning': reasoning,
        if (placeMetadata != null) 'place_metadata': placeMetadata,
        'targetsubintent': targetsubintent,
      };
}

// ══════════════════════════════════════════════════════════════
//  DataItem — item inside listing data (all maps are dynamic)
// ══════════════════════════════════════════════════════════════

class DataItem {
  String type;
  Map<String, dynamic> categorical;
  Map<String, dynamic> min;
  Map<String, dynamic> max;
  Map<String, dynamic> range;

  DataItem({
    required this.type,
    this.categorical = const {},
    this.min = const {},
    this.max = const {},
    this.range = const {},
  });

  factory DataItem.fromJson(Map<String, dynamic> json) =>
      DataItem(
        type: json['type'] ?? '',
        categorical: json['categorical'] is Map
            ? Map<String, dynamic>.from(
                json['categorical'] as Map)
            : {},
        min: json['min'] is Map
            ? Map<String, dynamic>.from(json['min'] as Map)
            : {},
        max: json['max'] is Map
            ? Map<String, dynamic>.from(json['max'] as Map)
            : {},
        range: json['range'] is Map
            ? Map<String, dynamic>.from(json['range'] as Map)
            : {},
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'categorical': categorical,
        'min': min,
        'max': max,
        'range': range,
      };
}

// ══════════════════════════════════════════════════════════════
//  SelfOther — self / other inside listing data (dynamic maps)
// ══════════════════════════════════════════════════════════════

class SelfOther {
  Map<String, dynamic> categorical;
  Map<String, dynamic> min;
  Map<String, dynamic> max;
  Map<String, dynamic> range;

  SelfOther({
    this.categorical = const {},
    this.min = const {},
    this.max = const {},
    this.range = const {},
  });

  factory SelfOther.fromJson(Map<String, dynamic> json) =>
      SelfOther(
        categorical: json['categorical'] is Map
            ? Map<String, dynamic>.from(
                json['categorical'] as Map)
            : {},
        min: json['min'] is Map
            ? Map<String, dynamic>.from(json['min'] as Map)
            : {},
        max: json['max'] is Map
            ? Map<String, dynamic>.from(json['max'] as Map)
            : {},
        range: json['range'] is Map
            ? Map<String, dynamic>.from(json['range'] as Map)
            : {},
      );

  Map<String, dynamic> toJson() => {
        'categorical': categorical,
        'min': min,
        'max': max,
        'range': range,
      };
}

// ══════════════════════════════════════════════════════════════
//  QueryJson — parsed structure of the user's query
// ══════════════════════════════════════════════════════════════

class QueryJson {
  String intent;
  String subintent;
  List<String> domain;
  String primaryMutualCategory;
  List<QueryItem> items;
  List<dynamic> itemExclusions;
  Map<String, dynamic> otherPartyPreferences;
  Map<String, dynamic> otherPartyExclusions;
  Map<String, dynamic> selfAttributes;
  Map<String, dynamic> selfExclusions;
  Map<String, dynamic> targetLocation;
  String locationMatchMode;
  List<dynamic> locationExclusions;
  String targetSubintent;
  String reasoning;

  QueryJson({
    required this.intent,
    required this.subintent,
    required this.domain,
    this.primaryMutualCategory = '',
    required this.items,
    required this.itemExclusions,
    this.otherPartyPreferences = const {},
    this.otherPartyExclusions = const {},
    this.selfAttributes = const {},
    this.selfExclusions = const {},
    this.targetLocation = const {},
    required this.locationMatchMode,
    required this.locationExclusions,
    this.targetSubintent = '',
    required this.reasoning,
  });

  factory QueryJson.fromJson(Map<String, dynamic> json) =>
      QueryJson(
        intent: json['intent']?.toString() ?? '',
        subintent: json['subintent']?.toString() ?? '',
        domain: json['domain'] is List
            ? List<String>.from(
                (json['domain'] as List).map((x) => x.toString()))
            : json['domain'] is String
                ? [json['domain'] as String]
                : [],
        primaryMutualCategory:
            json['primary_mutual_category'] is List
                ? (json['primary_mutual_category'] as List).join(', ')
                : json['primary_mutual_category']?.toString() ?? '',
        items: json['items'] is List
            ? List<QueryItem>.from(
                (json['items'] as List)
                    .map((x) {
                      try {
                        return QueryItem.fromJson(x is Map
                            ? Map<String, dynamic>.from(x)
                            : {});
                      } catch (e) {
                        return null;
                      }
                    })
                    .where((x) => x != null)
                    .cast<QueryItem>())
            : [],
        itemExclusions: json['item_exclusions'] is List
            ? List<dynamic>.from(json['item_exclusions'] as List)
            : [],
        otherPartyPreferences:
            json['other_party_preferences'] is Map
                ? Map<String, dynamic>.from(
                    json['other_party_preferences'] as Map)
                : {},
        otherPartyExclusions:
            json['other_party_exclusions'] is Map
                ? Map<String, dynamic>.from(
                    json['other_party_exclusions'] as Map)
                : {},
        selfAttributes: json['self_attributes'] is Map
            ? Map<String, dynamic>.from(
                json['self_attributes'] as Map)
            : {},
        selfExclusions: json['self_exclusions'] is Map
            ? Map<String, dynamic>.from(
                json['self_exclusions'] as Map)
            : {},
        targetLocation: json['target_location'] is Map
            ? Map<String, dynamic>.from(
                json['target_location'] as Map)
            : {},
        locationMatchMode: json['location_match_mode']?.toString() ?? '',
        locationExclusions: json['location_exclusions'] is List
            ? List<dynamic>.from(json['location_exclusions'] as List)
            : [],
        targetSubintent: json['target_subintent']?.toString() ?? '',
        reasoning: json['reasoning']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'subintent': subintent,
        'domain': domain,
        'primary_mutual_category': primaryMutualCategory,
        'items': items.map((x) => x.toJson()).toList(),
        'item_exclusions': itemExclusions,
        'other_party_preferences': otherPartyPreferences,
        'other_party_exclusions': otherPartyExclusions,
        'self_attributes': selfAttributes,
        'self_exclusions': selfExclusions,
        'target_location': targetLocation,
        'location_match_mode': locationMatchMode,
        'location_exclusions': locationExclusions,
        'target_subintent': targetSubintent,
        'reasoning': reasoning,
      };
}

// ══════════════════════════════════════════════════════════════
//  QueryItem — item inside query_json (all maps are dynamic)
// ══════════════════════════════════════════════════════════════

class QueryItem {
  String type;
  Map<String, dynamic> categorical;
  Map<String, dynamic> max;
  Map<String, dynamic> min;
  Map<String, dynamic> range;

  QueryItem({
    required this.type,
    this.categorical = const {},
    this.max = const {},
    this.min = const {},
    this.range = const {},
  });

  factory QueryItem.fromJson(Map<String, dynamic> json) =>
      QueryItem(
        type: json['type'] ?? '',
        categorical: json['categorical'] is Map
            ? Map<String, dynamic>.from(
                json['categorical'] as Map)
            : {},
        max: json['max'] is Map
            ? Map<String, dynamic>.from(json['max'] as Map)
            : {},
        min: json['min'] is Map
            ? Map<String, dynamic>.from(json['min'] as Map)
            : {},
        range: json['range'] is Map
            ? Map<String, dynamic>.from(json['range'] as Map)
            : {},
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'categorical': categorical,
        'max': max,
        'min': min,
        'range': range,
      };
}
