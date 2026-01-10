import 'package:cloud_firestore/cloud_firestore.dart';

/// Dynamic post model without hardcoded categories
/// AI-driven understanding of user intent
class PostModel {
  final String id;
  final String userId;
  final String originalPrompt; // User's original input
  final String title;
  final String description;
  final Map<String, dynamic> intentAnalysis; // AI's understanding of intent (replaces category/intent enums)
  final List<String>? images;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final List<double>? embedding;
  final List<String>? keywords;
  final double? similarityScore;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double? price;
  final double? priceMin;
  final double? priceMax;
  final String? currency;
  final int viewCount;
  final List<String> matchedUserIds;
  final Map<String, dynamic> clarificationAnswers;
  final String? gender;
  final String? ageRange;
  final String? condition;
  final String? brand;
  final String? userName;
  final String? userPhoto;

  PostModel({
    required this.id,
    required this.userId,
    required this.originalPrompt,
    required this.title,
    required this.description,
    required this.intentAnalysis,
    this.images,
    required this.metadata,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.embedding,
    this.keywords,
    this.similarityScore,
    this.location,
    this.latitude,
    this.longitude,
    this.price,
    this.priceMin,
    this.priceMax,
    this.currency,
    this.viewCount = 0,
    this.matchedUserIds = const [],
    required this.clarificationAnswers,
    this.gender,
    this.ageRange,
    this.condition,
    this.brand,
    this.userName,
    this.userPhoto,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      originalPrompt: data['originalPrompt'] ?? data['title'] ?? '', // Fallback for old data
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      intentAnalysis: data['intentAnalysis'] ?? {},
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      metadata: data['metadata'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      embedding: data['embedding'] != null
          ? List<double>.from(data['embedding'])
          : null,
      keywords: data['keywords'] != null
          ? List<String>.from(data['keywords'])
          : null,
      similarityScore: data['similarityScore']?.toDouble(),
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      price: data['price']?.toDouble(),
      priceMin: data['priceMin']?.toDouble(),
      priceMax: data['priceMax']?.toDouble(),
      currency: data['currency'],
      viewCount: data['viewCount'] ?? 0,
      matchedUserIds: data['matchedUserIds'] != null
          ? List<String>.from(data['matchedUserIds'])
          : [],
      clarificationAnswers: data['clarificationAnswers'] ?? {},
      gender: data['gender'],
      ageRange: data['ageRange'],
      condition: data['condition'],
      brand: data['brand'],
      userName: data['userName'],
      userPhoto: data['userPhoto'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'originalPrompt': originalPrompt,
      'title': title,
      'description': description,
      'intentAnalysis': intentAnalysis,
      'images': images,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'embedding': embedding,
      'keywords': keywords,
      'similarityScore': similarityScore,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'currency': currency,
      'viewCount': viewCount,
      'matchedUserIds': matchedUserIds,
      'clarificationAnswers': clarificationAnswers,
      'gender': gender,
      'ageRange': ageRange,
      'condition': condition,
      'brand': brand,
      'userName': userName,
      'userPhoto': userPhoto,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Get the primary intent from AI analysis
  String get primaryIntent {
    return intentAnalysis['primary_intent'] ?? originalPrompt;
  }

  /// Get action type (seeking/offering/neutral)
  String get actionType {
    return intentAnalysis['action_type'] ?? 'neutral';
  }

  /// Get extracted entities
  Map<String, dynamic> get entities {
    return intentAnalysis['entities'] ?? {};
  }

  /// Get search keywords for matching
  List<String> get searchKeywords {
    final keywords = intentAnalysis['search_keywords'];
    if (keywords is List) {
      return List<String>.from(keywords);
    }
    return originalPrompt.toLowerCase().split(' ');
  }

  /// Dynamic category display based on AI understanding
  String get categoryDisplay {
    final domain = intentAnalysis['domain'];
    if (domain != null && domain.toString().isNotEmpty) {
      return _formatForDisplay(domain.toString());
    }
    return _formatForDisplay(primaryIntent);
  }

  /// Dynamic intent display based on AI understanding
  String get intentDisplay {
    final actionType = intentAnalysis['action_type'];
    if (actionType != null && actionType.toString().isNotEmpty) {
      return _formatForDisplay(actionType.toString());
    }
    return _formatForDisplay(primaryIntent);
  }

  /// Format a string for display (capitalize first letter, replace underscores)
  String _formatForDisplay(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
  
  /// Dynamic intent matching based on AI understanding (replaces hardcoded matchesIntent)
  /// Returns true if this post could be a good match with another post
  bool matchesIntent(PostModel other) {
    final myActionType = actionType.toLowerCase();
    final otherActionType = other.actionType.toLowerCase();

    // Check for complementary action types
    if ((myActionType == 'offering' && otherActionType == 'seeking') ||
        (myActionType == 'seeking' && otherActionType == 'offering') ||
        (myActionType == 'selling' && otherActionType == 'buying') ||
        (myActionType == 'buying' && otherActionType == 'selling') ||
        (myActionType == 'giving' && otherActionType == 'requesting') ||
        (myActionType == 'requesting' && otherActionType == 'giving') ||
        (myActionType == 'lost' && otherActionType == 'found') ||
        (myActionType == 'found' && otherActionType == 'lost') ||
        (myActionType == 'hiring' && otherActionType == 'job_seeking') ||
        (myActionType == 'job_seeking' && otherActionType == 'hiring') ||
        (myActionType == 'renting' && otherActionType == 'rent_seeking') ||
        (myActionType == 'rent_seeking' && otherActionType == 'renting')) {
      return true;
    }

    // For symmetric intents (dating, friendship, meetup, etc.)
    // Match if both have the same action type
    if (myActionType == otherActionType &&
        (myActionType == 'meetup' ||
            myActionType == 'dating' ||
            myActionType == 'friendship' ||
            myActionType == 'connecting' ||
            myActionType == 'neutral')) {
      return true;
    }

    return false;
  }
  
  /// Dynamic price matching based on action types
  bool matchesPrice(PostModel other) {
    // If neither has price info, consider it a match
    if (price == null && other.price == null &&
        priceMin == null && other.priceMin == null &&
        priceMax == null && other.priceMax == null) {
      return true;
    }

    final myActionType = actionType.toLowerCase();
    final otherActionType = other.actionType.toLowerCase();

    // Check if price ranges overlap for seller/buyer scenarios
    if ((myActionType == 'selling' || myActionType == 'offering') &&
        (otherActionType == 'buying' || otherActionType == 'seeking')) {
      // Seller's price should be within buyer's range
      if (price != null && other.priceMax != null) {
        return price! <= other.priceMax!;
      }
      if (price != null && other.priceMin != null && other.priceMax != null) {
        return price! >= other.priceMin! && price! <= other.priceMax!;
      }
    }

    if ((myActionType == 'buying' || myActionType == 'seeking') &&
        (otherActionType == 'selling' || otherActionType == 'offering')) {
      // Buyer's range should include seller's price
      if (other.price != null && priceMax != null) {
        return other.price! <= priceMax!;
      }
      if (other.price != null && priceMin != null && priceMax != null) {
        return other.price! >= priceMin! && other.price! <= priceMax!;
      }
    }

    return true;
  }

  /// Check if this post needs more clarification
  bool get needsClarification {
    final clarificationsNeeded = intentAnalysis['clarifications_needed'];
    return clarificationsNeeded != null &&
        clarificationsNeeded is List &&
        clarificationsNeeded.isNotEmpty;
  }

  /// Get emotional tone for UI styling
  String get emotionalTone {
    return intentAnalysis['emotional_tone'] ?? 'casual';
  }
}