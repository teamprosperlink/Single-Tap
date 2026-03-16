import 'dart:convert';

CreatePostModel createPostModelFromJson(String str) =>
    CreatePostModel.fromJson(json.decode(str));

String createPostModelToJson(CreatePostModel data) =>
    json.encode(data.toJson());

class CreatePostModel {
  String status;
  String listingId;
  String userId;
  String query;
  ExtractedJson? extractedJson;
  String intent;
  dynamic matchId;
  List<String> images;
  String message;

  CreatePostModel({
    required this.status,
    required this.listingId,
    required this.userId,
    required this.query,
    this.extractedJson,
    required this.intent,
    this.matchId,
    required this.images,
    required this.message,
  });

  factory CreatePostModel.fromJson(Map<String, dynamic> json) =>
      CreatePostModel(
        status: json["status"] ?? '',
        listingId: json["listing_id"] ?? '',
        userId: json["user_id"] ?? '',
        query: json["query"] ?? '',
        extractedJson: json["extracted_json"] != null
            ? ExtractedJson.fromJson(json["extracted_json"])
            : null,
        intent: json["intent"] ?? '',
        matchId: json["match_id"],
        images: json["images"] != null
            ? (json["images"] as List).where((e) => e != null).map((e) => e.toString()).toList()
            : <String>[],
        message: json["message"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "listing_id": listingId,
        "user_id": userId,
        "query": query,
        "extracted_json": extractedJson?.toJson(),
        "intent": intent,
        "match_id": matchId,
        "images": images,
        "message": message,
      };
}

class ExtractedJson {
  String intent;
  String subintent;
  List<String> domain;
  List<Item> items;
  List<dynamic> itemExclusions;
  OtherPartyPreferences? otherPartyPreferences;
  OtherPartyPreferences? selfAttributes;
  OtherPartyPreferences? targetLocation;
  String locationMatchMode;
  List<dynamic> locationExclusions;
  String reasoning;

  ExtractedJson({
    required this.intent,
    required this.subintent,
    required this.domain,
    required this.items,
    required this.itemExclusions,
    this.otherPartyPreferences,
    this.selfAttributes,
    this.targetLocation,
    required this.locationMatchMode,
    required this.locationExclusions,
    required this.reasoning,
  });

  factory ExtractedJson.fromJson(Map<String, dynamic> json) => ExtractedJson(
        intent: json["intent"] ?? '',
        subintent: json["subintent"] ?? '',
        domain: json["domain"] != null
            ? List<String>.from(json["domain"])
            : [],
        items: json["items"] != null
            ? List<Item>.from(
                (json["items"] as List).map((x) => Item.fromJson(x)))
            : [],
        itemExclusions: json["item_exclusions"] != null
            ? List<dynamic>.from(json["item_exclusions"])
            : [],
        otherPartyPreferences: json["other_party_preferences"] != null
            ? OtherPartyPreferences.fromJson(json["other_party_preferences"])
            : null,
        selfAttributes: json["self_attributes"] != null
            ? OtherPartyPreferences.fromJson(json["self_attributes"])
            : null,
        targetLocation: json["target_location"] != null
            ? OtherPartyPreferences.fromJson(json["target_location"])
            : null,
        locationMatchMode: json["location_match_mode"] ?? '',
        locationExclusions: json["location_exclusions"] != null
            ? List<dynamic>.from(json["location_exclusions"])
            : [],
        reasoning: json["reasoning"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "intent": intent,
        "subintent": subintent,
        "domain": List<dynamic>.from(domain),
        "items": List<dynamic>.from(items.map((x) => x.toJson())),
        "item_exclusions": List<dynamic>.from(itemExclusions),
        "other_party_preferences": otherPartyPreferences?.toJson(),
        "self_attributes": selfAttributes?.toJson(),
        "target_location": targetLocation?.toJson(),
        "location_match_mode": locationMatchMode,
        "location_exclusions": List<dynamic>.from(locationExclusions),
        "reasoning": reasoning,
      };
}

class Item {
  String type;

  Item({
    required this.type,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        type: json["type"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "type": type,
      };
}

class OtherPartyPreferences {
  OtherPartyPreferences();

  factory OtherPartyPreferences.fromJson(Map<String, dynamic> json) =>
      OtherPartyPreferences();

  Map<String, dynamic> toJson() => {};
}
