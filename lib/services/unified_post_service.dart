import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'ai_services/gemini_service.dart';
import '../models/post_model.dart';
import '../res/config/api_config.dart';

/// Unified Post Service - Single source of truth for all post operations
///
/// Matching: relevance = max(semantic, keyword×0.70) + intentBonus(0.15) + locBonus(0.05) - lifestylePenalty
/// Threshold: final_score ≥ 0.45 to surface a match (see ApiConfig)
class UnifiedPostService {
  static final UnifiedPostService _instance = UnifiedPostService._internal();
  factory UnifiedPostService() => _instance;
  UnifiedPostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();

  // Generic transactional/marketplace words that should NOT count as domain
  // keyword evidence — they appear in virtually every post regardless of domain.
  static const Set<String> _compHitStopWords = {
    'sale', 'sell', 'selling', 'sold',
    'free', 'available', 'avail',
    'need', 'want', 'have', 'offer', 'offering', 'offers',
    'seek', 'seeking', 'find', 'looking', 'provide', 'providing',
    'give', 'giving', 'take', 'taking', 'help', 'helping',
    'hire', 'hiring', 'work', 'working',
    'good', 'best', 'near', 'like', 'this', 'that', 'some',
    'used', 'item', 'service', 'services', 'product',
    'from', 'with', 'make', 'making', 'also', 'more',
  };

  // Incompatible lifestyle-value pairs (order-independent)
  static const List<List<String>> _incompatibleValues = [
    ['vegan', 'meat_based'],
    ['vegan', 'bbq'],
    ['vegan', 'non_vegetarian'],
    ['vegetarian', 'meat_based'],
    ['vegetarian', 'bbq'],
    ['vegetarian', 'non_vegetarian'],
    ['pets', 'no_pets'],
    ['smoking', 'no_smoking'],
    ['quiet', 'loud'],
    ['night_owl', 'early_bird'],
    ['hunting', 'animal_rights'],
  ];

  /// Create a new post with automatic AI processing
  Future<Map<String, dynamic>> createPost({
    required String originalPrompt,
    Map<String, dynamic>? clarificationAnswers,
    double? price,
    double? priceMin,
    double? priceMax,
    String? currency,
    List<String>? images,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.data() ?? {};

      final postLocation = location ?? userProfile['location'];
      final postLatitude = latitude ?? userProfile['latitude']?.toDouble();
      final postLongitude = longitude ?? userProfile['longitude']?.toDouble();

      debugPrint(' Creating post: $originalPrompt');

      final intentAnalysis = await _analyzeIntent(
        originalPrompt,
        clarificationAnswers ?? {},
      );

      debugPrint(' Intent analyzed: ${intentAnalysis['primary_intent']}');

      final title = intentAnalysis['title'] ?? _generateTitle(originalPrompt);
      final description = intentAnalysis['description'] ?? originalPrompt;

      final embeddingText = _createTextForEmbedding(
        title: title,
        description: description,
        location: postLocation,
        domain: intentAnalysis['domain'],
        actionType: intentAnalysis['action_type'],
        skillLevel: intentAnalysis['skill_level'],
        exchangeModel: intentAnalysis['exchange_model'],
      );

      final embedding = await _geminiService.generateEmbedding(embeddingText);
      debugPrint(' Embedding generated: ${embedding.length} dimensions');

      final keywords = _extractKeywords('$title $description');

      String? userName = userProfile['name'] ?? userProfile['displayName'];
      if (userName == null || userName.isEmpty || userName == 'User') {
        userName = userProfile['phone'];
      }
      final userPhoto =
          userProfile['photoUrl'] ??
          userProfile['photoURL'] ??
          userProfile['profileImageUrl'];

      final post = PostModel(
        id: '',
        userId: userId,
        originalPrompt: originalPrompt,
        title: title,
        description: description,
        intentAnalysis: intentAnalysis,
        embedding: embedding,
        keywords: keywords,
        images: images,
        metadata: {
          'createdBy': 'UnifiedPostService',
          'version': '3.0',
          'embeddingModel': 'gemini-embedding',
        },
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        location: postLocation,
        latitude: postLatitude,
        longitude: postLongitude,
        price: price,
        priceMin: priceMin,
        priceMax: priceMax,
        currency: currency ?? 'USD',
        clarificationAnswers: clarificationAnswers ?? {},
        viewCount: 0,
        matchedUserIds: [],
        userName: userName,
        userPhoto: userPhoto,
      );

      _validatePost(post);

      // Include action_type at top level so Firestore can filter on it
      final postData = {
        ...post.toFirestore(),
        'action_type': post.intentAnalysis['action_type'] ?? 'neutral',
      };
      final docRef = await _firestore.collection('posts').add(postData);
      debugPrint(' Post created successfully: ${docRef.id}');

      return {
        'success': true,
        'postId': docRef.id,
        'post': post.toFirestore(),
        'message': 'Post created successfully',
      };
    } catch (e) {
      debugPrint(' Error creating post: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create post',
      };
    }
  }

  /// Analyze user intent with AI — extracts all fields needed for matching
  Future<Map<String, dynamic>> _analyzeIntent(
    String userInput,
    Map<String, dynamic> clarificationAnswers,
  ) async {
    try {
      final prompt = '''
Analyze this user request and extract structured intent for a two-sided matching app:
"$userInput"

${clarificationAnswers.isNotEmpty ? 'User provided clarifications: $clarificationAnswers' : ''}

Return ONLY valid JSON (no markdown, no backticks):
{
  "primary_intent": "what user wants in plain terms",
  "action_type": "offering/seeking/neutral",
  "is_symmetric": false,
  "skill_level": "beginner/intermediate/advanced/expert/any",
  "exchange_model": "free/paid/barter/equity/flexible/unspecified",
  "service_type": "in_person/community/professional/digital",
  "value_profile": [],
  "domain": "marketplace/social/jobs/housing/services/education/fitness/etc",
  "title": "short title (max 50 chars)",
  "description": "detailed description",
  "entities": {"item": "main item/service", "category": "category"},
  "complementary_intents": ["phrases describing the ideal matching person"],
  "search_keywords": ["keyword1", "keyword2"],
  "confidence": 0.9
}

Field rules:
- action_type: "offering" (providing/selling/teaching/renting out), "seeking" (needing/buying/learning/renting), "neutral" (unclear)
- is_symmetric: true ONLY when both sides want the SAME thing (gym partner, chess partner, travel buddy, study group, co-founder, running partner, language exchange partner, book club member, hiking buddy, carpool partner). false for all offer/need pairs.
- skill_level: expertise level involved. "any" if not specified.
- exchange_model: "free" (no cost), "paid" (money expected), "barter" (trade skills/items), "equity" (ownership share), "flexible" (open to options), "unspecified" (not mentioned)
- service_type: "in_person" (plumber/cleaner/tutor at home/local meetup), "community" (gym partner/book club/local social), "professional" (developer/lawyer/accountant — can be remote), "digital" (online tutor/remote VA/software — fully remote)
- value_profile: lifestyle/value tags ONLY if clearly stated. Choose from: ["vegan","vegetarian","meat_based","bbq","non_vegetarian","pets","no_pets","smoking","no_smoking","quiet","loud","night_owl","early_bird","hunting","animal_rights"]. Empty array if none apply.
- complementary_intents: THE MOST IMPORTANT FIELD. For is_symmetric=false, describe what the OPPOSITE side would say. For is_symmetric=true, describe the SAME intent from another person's perspective. Write 3-5 varied, natural-sounding phrases. Include domain-specific terms.

=== EXAMPLES (24) ===

--- Buyer/Seller (classic two-sided) ---
1. "selling my iPhone 14 Pro" → action_type:"offering", is_symmetric:false, exchange_model:"paid", domain:"marketplace", complementary_intents:["looking to buy iPhone 14 Pro","want to purchase iPhone 14","need secondhand iPhone"]
2. "want to buy a used laptop" → action_type:"seeking", is_symmetric:false, exchange_model:"paid", domain:"marketplace", complementary_intents:["selling used laptop","laptop for sale","secondhand laptop available"]
3. "selling homemade cakes and pastries" → action_type:"offering", is_symmetric:false, exchange_model:"paid", domain:"food", complementary_intents:["want to order homemade cake","looking for custom pastries","need birthday cake"]

--- Indirect Complementary (problem ↔ solution) ---
4. "my sink is leaking badly" → action_type:"seeking", is_symmetric:false, service_type:"in_person", domain:"services", complementary_intents:["licensed plumber available","plumbing repair service","plumber for hire","fix leaking pipes"]
5. "experienced plumber, available for jobs" → action_type:"offering", is_symmetric:false, service_type:"in_person", domain:"services", complementary_intents:["need plumber urgently","leaking pipe","toilet not working","bathroom renovation help"]
6. "my car won't start, need help" → action_type:"seeking", is_symmetric:false, service_type:"in_person", domain:"automotive", complementary_intents:["mobile mechanic available","car repair service","auto electrician for hire","roadside assistance"]

--- Symmetric (both sides want the same) ---
7. "looking for a running partner" → action_type:"seeking", is_symmetric:true, service_type:"community", domain:"fitness", complementary_intents:["want a running partner","looking for jogging buddy","morning run companion"]
8. "need a gym workout buddy" → action_type:"seeking", is_symmetric:true, service_type:"community", domain:"fitness", complementary_intents:["looking for gym partner","want workout buddy","fitness accountability partner"]
9. "looking for chess partner to play weekly" → action_type:"seeking", is_symmetric:true, service_type:"community", domain:"social", complementary_intents:["want chess partner","looking for someone to play chess","weekly chess opponent"]
10. "seeking co-founder for AI startup" → action_type:"seeking", is_symmetric:true, exchange_model:"equity", service_type:"professional", domain:"jobs", complementary_intents:["looking for co-founder","want to join AI startup","seeking startup partner"]

--- Barter / Exchange ---
11. "I teach Hindi, want to learn English" → action_type:"offering", is_symmetric:false, exchange_model:"barter", service_type:"community", domain:"education", complementary_intents:["I teach English want to learn Hindi","English speaker learning Hindi","English-Hindi language exchange"]
12. "can do web design in exchange for photography" → action_type:"offering", is_symmetric:false, exchange_model:"barter", service_type:"professional", domain:"services", complementary_intents:["photographer willing to trade for web design","need website will trade photography","photographer seeking web designer for barter"]

--- Professional Services ---
13. "freelance web developer taking projects" → action_type:"offering", service_type:"professional", exchange_model:"paid", domain:"services", complementary_intents:["need website built","hire web developer","looking for freelance developer","web app project needs developer"]
14. "need advanced PhD-level statistics tutor" → action_type:"seeking", skill_level:"expert", service_type:"professional", exchange_model:"paid", domain:"education", complementary_intents:["expert statistics tutor PhD level","advanced stats coaching available","statistics professor offering tutoring"]
15. "online English tutor for kids" → action_type:"offering", service_type:"digital", domain:"education", complementary_intents:["need English tutor for child","online kids tutor wanted","English lessons for my daughter"]

--- Housing ---
16. "room available in 2BHK apartment" → action_type:"offering", service_type:"in_person", exchange_model:"paid", domain:"housing", complementary_intents:["looking for room to rent","need flatmate","searching for shared apartment","room needed near city"]
17. "looking for a flatmate, non-smoker preferred" → action_type:"seeking", service_type:"in_person", exchange_model:"paid", domain:"housing", value_profile:["no_smoking"], complementary_intents:["room available non-smoking flat","flatmate wanted","apartment share available"]

--- Lifestyle Values ---
18. "vegan chef offering plant-based cooking classes" → action_type:"offering", service_type:"in_person", value_profile:["vegan"], domain:"education", complementary_intents:["want to learn vegan cooking","plant-based cooking student","vegan cooking class near me"]
19. "need someone to teach me BBQ and grilling" → action_type:"seeking", service_type:"in_person", value_profile:["meat_based","bbq"], domain:"education", complementary_intents:["BBQ instructor available","teach grilling techniques","pitmaster offering classes"]

--- Community / Social ---
20. "starting a weekend hiking group" → action_type:"offering", is_symmetric:true, service_type:"community", exchange_model:"free", domain:"fitness", complementary_intents:["want to join hiking group","looking for hiking buddies","weekend hiking partner"]
21. "looking for a book club to join" → action_type:"seeking", is_symmetric:true, service_type:"community", exchange_model:"free", domain:"social", complementary_intents:["book club looking for members","join our reading group","book discussion group open"]

--- Same-side note: two sellers should NOT match ---
22. "selling acoustic guitar, barely used" → action_type:"offering", is_symmetric:false, exchange_model:"paid", domain:"marketplace", complementary_intents:["want to buy acoustic guitar","looking for secondhand guitar","need beginner guitar"]

--- Digital / Remote ---
23. "offering virtual assistant services remotely" → action_type:"offering", service_type:"digital", exchange_model:"paid", domain:"services", complementary_intents:["need virtual assistant","looking for remote VA","hire someone for admin tasks remotely"]

--- Lost & Found ---
24. "lost golden retriever near downtown" → action_type:"seeking", is_symmetric:false, domain:"community", complementary_intents:["found golden retriever downtown","found dog near downtown","stray golden retriever found"]
''';

      final response = await _geminiService.generateContent(prompt);

      if (response != null && response.isNotEmpty) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
        if (jsonMatch != null) {
          return _parseIntentJson(jsonMatch.group(0)!);
        }
      }

      return _createFallbackIntent(userInput);
    } catch (e) {
      debugPrint('   Error analyzing intent: $e');
      return _createFallbackIntent(userInput);
    }
  }

  /// Parse intent JSON from AI response
  Map<String, dynamic> _parseIntentJson(String jsonStr) {
    try {
      final cleaned = jsonStr
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      return {
        'primary_intent': decoded['primary_intent'] ?? 'general',
        'action_type': decoded['action_type'] ?? 'neutral',
        'is_symmetric': decoded['is_symmetric'] ?? false,
        'skill_level': decoded['skill_level'] ?? 'any',
        'exchange_model': decoded['exchange_model'] ?? 'unspecified',
        'service_type': decoded['service_type'] ?? 'professional',
        'value_profile': List<String>.from(decoded['value_profile'] ?? []),
        'domain': decoded['domain'] ?? 'general',
        'title': decoded['title'],
        'description': decoded['description'],
        'entities': decoded['entities'] ?? {},
        'complementary_intents':
            List<String>.from(decoded['complementary_intents'] ?? []),
        'search_keywords':
            List<String>.from(decoded['search_keywords'] ?? []),
        'confidence': (decoded['confidence'] as num?)?.toDouble() ?? 0.8,
      };
    } catch (e) {
      debugPrint('   Error parsing intent JSON: $e');
      return _createFallbackIntent(jsonStr);
    }
  }

  /// Fallback intent when AI fails
  Map<String, dynamic> _createFallbackIntent(String userInput) {
    return {
      'primary_intent': userInput,
      'action_type': 'neutral',
      'is_symmetric': false,
      'skill_level': 'any',
      'exchange_model': 'unspecified',
      'service_type': 'professional',
      'value_profile': <String>[],
      'domain': 'general',
      'title': userInput.length > 50 ? '${userInput.substring(0, 47)}...' : userInput,
      'description': userInput,
      'entities': {},
      'complementary_intents': <String>[],
      'search_keywords': userInput.toLowerCase().split(' '),
      'confidence': 0.5,
    };
  }

  String _generateTitle(String prompt) {
    if (prompt.length <= 50) return prompt;
    return '${prompt.substring(0, 47)}...';
  }

  /// Create text for embedding — richer text = better vector differentiation
  String _createTextForEmbedding({
    required String title,
    required String description,
    String? location,
    String? domain,
    String? actionType,
    String? skillLevel,
    String? exchangeModel,
  }) {
    final parts = <String>[title, description];
    if (location != null && location.isNotEmpty) parts.add('Location: $location');
    if (domain != null && domain.isNotEmpty) parts.add('Domain: $domain');
    if (actionType != null && actionType.isNotEmpty) parts.add('Action: $actionType');
    if (skillLevel != null && skillLevel.isNotEmpty && skillLevel != 'any') {
      parts.add('Level: $skillLevel');
    }
    if (exchangeModel != null &&
        exchangeModel.isNotEmpty &&
        exchangeModel != 'unspecified') {
      parts.add('Exchange: $exchangeModel');
    }
    return parts.join(' ');
  }

  /// Extract keywords from text
  List<String> _extractKeywords(String text) {
    const stopWords = {
      'the','a','an','is','are','was','were','be','been','being','have','has',
      'had','do','does','did','will','would','could','should','may','might',
      'must','shall','can','need','dare','ought','used','to','of','in','for',
      'on','with','at','by','from','as','into','through','during','before',
      'after','above','below','between','under','again','further','then','once',
      'and','but','or','nor','so','yet','both','either','neither','not','only',
      'own','same','than','too','very','just','i','me','my','myself','we','our',
      'ours','you','your','he','him','his','she','her','it','its','they','them',
      'their','what','which','who','whom','this','that','these','those','am',
      // Intent-direction words — describe the side (offer/seek), not the subject.
      // Keeping these causes "selling X" and "selling Y" to share a keyword,
      // making the keyword fallback fire on unrelated domain pairs.
      'sell','selling','sold','buy','buying','bought','want','wanting','wanted',
      'look','looking','looked','find','finding','found','search','searching',
      'seek','seeking','offer','offering','offered','provide','providing',
      'give','giving','get','getting','hire','hiring','rent','renting',
      'needing','require','requiring','request','requesting',
      'available','help','helping',
      // AI-generated description words — appear in every post's auto-description
      // and cause false keyword overlap between completely unrelated posts.
      'user','users','person','someone','individual','people',
      'wants','needs','possesses','indicates','suggesting',
      'currency','units','approximately','regarding','currently',
      'also','more','about',
    };
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet()
        .take(20)
        .toList();
  }

  void _validatePost(PostModel post) {
    if (post.userId.isEmpty) throw Exception('Post must have userId');
    if (post.originalPrompt.isEmpty) throw Exception('Post must have originalPrompt');
    if (post.embedding == null || post.embedding!.isEmpty) {
      throw Exception('Post must have embedding');
    }
    if (post.title.isEmpty) throw Exception('Post must have title');
  }

  // ── Scoring helpers ──────────────────────────────────────────────────────

  /// Haversine distance in km between two lat/lon points
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  /// Location score 0.0–1.0 based on service_type and distance
  /// Returns 0.5 (neutral) if either post has no coordinates
  double _locationScore(PostModel src, PostModel cnd) {
    final srcLat = src.latitude;
    final srcLon = src.longitude;
    final cndLat = cnd.latitude;
    final cndLon = cnd.longitude;

    // Determine service type — use source; if digital, skip location entirely
    final serviceType =
        (src.intentAnalysis['service_type'] ??
                cnd.intentAnalysis['service_type'] ??
                'professional')
            .toString()
            .toLowerCase();

    if (serviceType == 'digital') return 1.0; // location irrelevant

    if (srcLat == null || srcLon == null || cndLat == null || cndLon == null) {
      return 0.65; // favour match when coords unknown — don't penalise missing GPS
    }

    final distKm = _haversineKm(srcLat, srcLon, cndLat, cndLon);

    // Wide radii for early-stage app with few users.
    // Tighten these once the user base grows.
    double innerKm;
    double outerKm;
    switch (serviceType) {
      case 'in_person':
        innerKm = 50.0;
        outerKm = 500.0;
      case 'community':
        innerKm = 100.0;
        outerKm = 500.0;
      case 'professional':
      default:
        innerKm = 200.0;
        outerKm = 500.0;
    }

    if (distKm <= innerKm) return 1.0;
    if (distKm >= outerKm) return 0.0;
    // Linear decay in the band
    return 1.0 - (distKm - innerKm) / (outerKm - innerKm);
  }

  /// Lifestyle/value incompatibility penalty — 0.0 (ok) or 0.15 (clash)
  double _lifestylePenalty(PostModel src, PostModel cnd) {
    final srcVals =
        List<String>.from(src.intentAnalysis['value_profile'] ?? []);
    final cndVals =
        List<String>.from(cnd.intentAnalysis['value_profile'] ?? []);

    if (srcVals.isEmpty || cndVals.isEmpty) return 0.0;

    for (final pair in _incompatibleValues) {
      final a = pair[0];
      final b = pair[1];
      if ((srcVals.contains(a) && cndVals.contains(b)) ||
          (srcVals.contains(b) && cndVals.contains(a))) {
        return 0.15;
      }
    }
    return 0.0;
  }

  /// Normalize action-type synonyms into canonical sides for same-side blocking.
  String _canonicalSide(String action) {
    const offerSide = {
      'offering', 'selling', 'sell', 'sold', 'giving', 'give',
      'providing', 'provide', 'renting', 'rent', 'hiring', 'hire',
    };
    const seekSide = {
      'seeking', 'buying', 'buy', 'bought', 'looking', 'look',
      'wanting', 'want', 'requesting', 'request', 'rent_seeking', 'job_seeking',
      'finding', 'find', 'searching', 'search',
    };
    if (offerSide.contains(action)) return 'offer';
    if (seekSide.contains(action)) return 'seek';
    return action;
  }

  /// Infer the side of a post — uses action_type first, falls back to scanning
  /// the original prompt text. Handles old posts that have action_type "neutral".
  String inferSide(PostModel post) {
    final action = (post.intentAnalysis['action_type'] ?? 'neutral')
        .toString()
        .toLowerCase();
    final side = _canonicalSide(action);
    if (side == 'offer' || side == 'seek') return side;

    // action_type was neutral/unrecognised — scan the actual post text
    final text = '${post.originalPrompt} ${post.title}'.toLowerCase();

    // Check offer phrases first (order matters — "selling" before "looking")
    const offerPhrases = [
      'selling', 'i sell', 'for sale', 'offering', 'i offer',
      'providing', 'i provide', 'teaching', 'i teach', 'i tutor',
      'available for', 'renting out', 'i am a ', 'i am an ', 'freelance',
      'i can ', 'i have a ', 'i have an ',
    ];
    for (final p in offerPhrases) {
      if (text.contains(p)) return 'offer';
    }

    // Then check seek phrases — covers "i am looking X" (no "for")
    const seekPhrases = [
      'looking for', 'i am looking', 'am looking', 'looking to',
      'i need', 'i want', 'searching for', 'buying', 'seeking',
      'need a ', 'need an ', 'want a ', 'want an ', 'want to buy',
      'want to find', 'find a ', 'hire a ', 'need someone',
      'where can i', 'anyone selling', 'anyone have',
    ];
    for (final p in seekPhrases) {
      if (text.contains(p)) return 'seek';
    }

    // Last-resort: "I am [profession]" without article (e.g., "I am plumber")
    final iAmMatch = RegExp(r'\bi am (\w+)').firstMatch(text);
    if (iAmMatch != null) {
      final word = iAmMatch.group(1)!;
      // Exclude seeking-type words that follow "I am"
      const seekingWords = {
        'looking', 'searching', 'seeking', 'trying', 'wanting',
        'interested', 'new', 'based', 'located', 'here', 'ready',
      };
      if (!seekingWords.contains(word)) return 'offer';
    }

    return 'neutral';
  }

  // ── Business profile → searchable post ──────────────────────────────────

  /// Create or update a searchable post from a business profile + catalog.
  /// Uses a deterministic doc ID (`business_{userId}`) so re-syncs overwrite.
  Future<void> syncBusinessPost(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) return;
      if (userData['accountType'] != 'business') return;

      final bp = userData['businessProfile'] as Map<String, dynamic>?;
      if (bp == null) return;

      final businessName = bp['businessName'] as String? ?? '';
      if (businessName.isEmpty) return;

      final description = bp['description'] as String? ?? '';
      final softLabel = bp['softLabel'] as String? ?? '';
      final address = bp['address'] as String? ?? '';

      // Get available catalog items
      final catalogSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('catalog')
          .where('isAvailable', isEqualTo: true)
          .limit(50)
          .get();

      final catalogNames = <String>[];
      for (final doc in catalogSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        if (name.isNotEmpty) catalogNames.add(name);
      }
      final catalogSummary = catalogNames.join(', ');

      // Build rich text for embedding
      final embeddingParts = <String>[businessName];
      if (softLabel.isNotEmpty) embeddingParts.add(softLabel);
      if (description.isNotEmpty) embeddingParts.add(description);
      if (catalogSummary.isNotEmpty) {
        embeddingParts.add('Services and Products: $catalogSummary');
      }
      final promptText = embeddingParts.join('. ');

      final embeddingText = _createTextForEmbedding(
        title: businessName,
        description: '$description $catalogSummary',
        location: userData['location'] ?? address,
        domain: 'services',
        actionType: 'offering',
      );

      final embedding = await _geminiService.generateEmbedding(embeddingText);
      final keywords = _extractKeywords(
        '$businessName $softLabel $description $catalogSummary',
      );

      final userPhoto = userData['photoUrl'] ??
          userData['photoURL'] ??
          userData['profileImageUrl'];

      // Title shown in "Posted:" section — use label or catalog, not the
      // business name (business name already shows in the name badge).
      final postTitle = softLabel.isNotEmpty
          ? softLabel
          : catalogSummary.isNotEmpty
              ? 'Offering: $catalogSummary'
              : businessName;

      final postDescription = description.isNotEmpty
          ? description
          : catalogSummary.isNotEmpty
              ? catalogSummary
              : 'Business services';

      final postData = {
        'userId': userId,
        'originalPrompt': promptText,
        'title': postTitle,
        'description': postDescription,
        'intentAnalysis': {
          'primary_intent': 'Business offering $softLabel services/products',
          'action_type': 'offering',
          'domain': softLabel.isNotEmpty ? softLabel.toLowerCase() : 'services',
          'service_type': 'in_person',
          'is_symmetric': false,
          'exchange_model': 'paid',
          'complementary_intents': [
            'looking for $softLabel',
            'need $softLabel services',
            if (catalogNames.isNotEmpty) 'looking for ${catalogNames.first}',
          ],
          'search_keywords': keywords,
        },
        'embedding': embedding,
        'keywords': keywords,
        'metadata': {
          'createdBy': 'BusinessProfileSync',
          'version': '2.0',
          'isBusinessPost': true,
          'businessName': businessName,
          'softLabel': softLabel,
          'catalogItemCount': catalogSnap.docs.length,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'isActive': true,
        'location': userData['location'] ?? address,
        'latitude': userData['latitude'],
        'longitude': userData['longitude'],
        'viewCount': 0,
        'matchedUserIds': [],
        'clarificationAnswers': {},
        'userName': businessName,
        'userPhoto': userPhoto,
        'action_type': 'offering',
      };

      await _firestore
          .collection('posts')
          .doc('business_$userId')
          .set(postData);

      debugPrint(
        ' Business post synced for $businessName (${catalogNames.length} catalog items)',
      );
    } catch (e) {
      debugPrint('Error syncing business post: $e');
    }
  }

  /// Re-sync the current user's business post if it was created with an older
  /// version (stale embeddings / missing domain). Called on business hub load.
  Future<void> resyncIfStale(String userId) async {
    try {
      final doc = await _firestore.collection('posts').doc('business_$userId').get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final version = metadata?['version'] as String?;
      if (version != '2.0') {
        debugPrint('Business post stale (version=$version), re-syncing...');
        await syncBusinessPost(userId);
      }
    } catch (e) {
      debugPrint('Error checking business post staleness: $e');
    }
  }

  // ── Find matches ─────────────────────────────────────────────────────────

  /// Find matching posts — dual-signal approach:
  ///   Signal 1: Semantic embedding similarity (when Gemini works)
  ///   Signal 2: Keyword overlap (always works, no API needed)
  ///   relevance = max(signal1, signal2) → picks whichever is stronger
  ///   Only hard filter: same-side block (both seeking or both offering)
  Future<List<PostModel>> findMatches(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final sourcePost = PostModel.fromFirestore(postDoc);
      final sourceEmbedding = sourcePost.embedding ?? [];

      if (sourceEmbedding.isEmpty) {
        debugPrint('Source post has no embedding, regenerating...');
        final embeddingText = _createTextForEmbedding(
          title: sourcePost.title,
          description: sourcePost.description,
          location: sourcePost.location,
        );
        final newEmbedding = await _geminiService.generateEmbedding(embeddingText);
        await postDoc.reference.update({
          'embedding': newEmbedding,
          'embeddingUpdatedAt': FieldValue.serverTimestamp(),
        });
        return findMatches(postId);
      }

      debugPrint('Finding matches for: ${sourcePost.title}');

      // Search embedding: use complementary phrases when available
      final complementaryIntents = List<String>.from(
        sourcePost.intentAnalysis['complementary_intents'] ?? [],
      );
      // Build search text before any async work
      final String searchText;
      if (complementaryIntents.isNotEmpty) {
        searchText =
            '${complementaryIntents.join('. ')} ${sourcePost.searchKeywords.join(' ')}';
        debugPrint('[Path A] complementary: $searchText');
      } else {
        searchText = '${sourcePost.title} ${sourcePost.description} '
            '${sourcePost.searchKeywords.join(' ')}';
        debugPrint('[Path B] fallback: $searchText');
      }

      // Parallel: generate embedding while Firestore fetches candidates
      final fetchResults = await Future.wait<dynamic>([
        _geminiService.generateEmbedding(searchText),
        _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(ApiConfig.matchQueryLimit)
            .get(),
      ]);
      final searchEmbedding = fetchResults[0] as List<double>;
      final querySnapshot =
          fetchResults[1] as QuerySnapshot<Map<String, dynamic>>;

      final List<PostModel> matches = [];
      final sourceSide = inferSide(sourcePost);
      final sourceSymmetric =
          sourcePost.intentAnalysis['is_symmetric'] == true;
      final sourceKw = Set<String>.from(sourcePost.keywords ?? []);

      debugPrint('=== MATCH DEBUG ===');
      debugPrint('Source: "${sourcePost.title}" side=$sourceSide '
          'kw=$sourceKw userId=${sourcePost.userId}');
      debugPrint('Total docs: ${querySnapshot.docs.length}');

      int skipUser = 0, skipEmbed = 0, skipLowRel = 0;
      int skipSameSide = 0, skipExchange = 0, skipThreshold = 0;

      for (final doc in querySnapshot.docs) {
        if (doc.data()['userId'] == sourcePost.userId) {
          skipUser++;
          continue;
        }
        final candidate = PostModel.fromFirestore(doc);
        final candidateEmbedding = candidate.embedding ?? [];
        if (candidateEmbedding.isEmpty) { skipEmbed++; continue; }

        // ── Signal 1: Semantic similarity ──────────────────────────────
        final semSim = _geminiService.calculateSimilarity(
          searchEmbedding, candidateEmbedding,
        );

        // ── Signal 2: Keyword overlap ──────────────────────────────────
        final candidateKw = Set<String>.from(candidate.keywords ?? []);
        final shared = sourceKw.intersection(candidateKw);
        int compHits = 0;
        for (final ci in complementaryIntents) {
          for (final word in ci.toLowerCase().split(' ')) {
            if (word.length > 3 &&
                !_compHitStopWords.contains(word) &&
                candidateKw.contains(word)) {
              compHits++;
              break;
            }
          }
        }
        final totalKwHits = shared.length + compHits;
        // 1 hit = 0.50, 2 hits = 0.75, 3+ = 1.0
        final kwScore = totalKwHits <= 0
            ? 0.0
            : totalKwHits == 1
                ? 0.50
                : totalKwHits == 2
                    ? 0.75
                    : 1.0;

        // Relevance = best of semantic OR keyword signal
        final relevance = max(semSim, kwScore * ApiConfig.matchKeywordDamping);

        // Pre-filter: neither signal shows relevance
        if (relevance < ApiConfig.matchPreFilterThreshold) {
          skipLowRel++;
          continue;
        }

        // Keyword gate: without keyword evidence the semantic embedding alone is
        // not specific enough — it confuses cross-category items (watch vs monitor,
        // Ferrari vs water bottle). Require either direct keyword overlap, a
        // domain-specific compHit, or near-identical semantic similarity (≥0.85).
        if (shared.isEmpty && compHits == 0 && semSim < 0.80) {
          skipLowRel++;
          continue;
        }

        // ── Domain mismatch detection ──────────────────────────────────
        final sourceDomain = (sourcePost.intentAnalysis['domain'] ?? '')
            .toString().toLowerCase();
        final candidateDomain = (candidate.intentAnalysis['domain'] ?? '')
            .toString().toLowerCase();
        final bothSpecificDomains = sourceDomain.isNotEmpty &&
            candidateDomain.isNotEmpty &&
            sourceDomain != 'services' && candidateDomain != 'services' &&
            sourceDomain != 'general' && candidateDomain != 'general';
        final domainMismatch = bothSpecificDomains &&
            sourceDomain != candidateDomain;

        // Hard block: different specific domains + no keyword evidence
        if (domainMismatch && shared.isEmpty && compHits == 0) {
          skipLowRel++;
          continue;
        }

        // ── Same-side block ────────────────────────────────────────────
        final candidateSide = inferSide(candidate);
        final candidateSymmetric =
            candidate.intentAnalysis['is_symmetric'] == true;
        if (sourceSide == candidateSide &&
            sourceSide != 'neutral' &&
            !(sourceSymmetric && candidateSymmetric)) {
          skipSameSide++;
          continue;
        }

        // ── Exchange block ─────────────────────────────────────────────
        final srcEx = (sourcePost.intentAnalysis['exchange_model'] ??
                'unspecified')
            .toString();
        final cndEx = (candidate.intentAnalysis['exchange_model'] ??
                'unspecified')
            .toString();
        if ((srcEx == 'free' && cndEx == 'paid') ||
            (srcEx == 'paid' && cndEx == 'free') ||
            (srcEx == 'equity' && cndEx == 'paid')) {
          skipExchange++;
          continue;
        }

        // ── Intent complement bonus ────────────────────────────────────
        // Only award bonus when there's solid evidence of domain relevance
        // (good semantic sim OR keyword overlap). Prevents cross-domain
        // false positives like plumbing → roommate.
        final complementary =
            (sourceSide == 'offer' && candidateSide == 'seek') ||
            (sourceSide == 'seek' && candidateSide == 'offer') ||
            (sourceSymmetric && candidateSymmetric) ||
            sourceSide == 'neutral' ||
            candidateSide == 'neutral';
        final hasEvidence = semSim >= 0.70 || (kwScore > 0 && semSim >= 0.55);
        final intentBonus =
            complementary && hasEvidence ? ApiConfig.matchIntentBonus : 0.0;

        // ── Location bonus (small — just for ranking) ──────────────────
        final locBonus = _locationScore(sourcePost, candidate) * ApiConfig.matchLocationWeight;

        // ── Lifestyle penalty ──────────────────────────────────────────
        final penalty = _lifestylePenalty(sourcePost, candidate);

        // ── Domain mismatch penalty ─────────────────────────────────
        final domainPenalty = (domainMismatch && kwScore == 0)
            ? ApiConfig.matchDomainMismatchPenalty : 0.0;

        // ── Final score ────────────────────────────────────────────────
        final finalScore =
            (relevance + intentBonus + locBonus - penalty - domainPenalty).clamp(0.0, 1.0);

        if (finalScore < ApiConfig.matchFinalThreshold) {
          skipThreshold++;
          continue;
        }

        matches.add(candidate.copyWith(similarityScore: finalScore));
        debugPrint('  MATCHED: "${candidate.title}" score=${finalScore.toStringAsFixed(2)} '
            '(sem=${semSim.toStringAsFixed(2)} kw=${kwScore.toStringAsFixed(2)} '
            'domain=$candidateDomain domPenalty=${domainPenalty.toStringAsFixed(2)})');
      }

      debugPrint('=== STATS: user=$skipUser embed=$skipEmbed '
          'lowRel=$skipLowRel sameSide=$skipSameSide '
          'exchange=$skipExchange threshold=$skipThreshold '
          'MATCHED=${matches.length} ===');

      matches.sort(
        (a, b) =>
            (b.similarityScore ?? 0).compareTo(a.similarityScore ?? 0),
      );

      debugPrint('Total matches: ${matches.length}');
      return matches.take(ApiConfig.matchMaxResults).toList();
    } catch (e) {
      debugPrint('Error finding matches: $e');
      return [];
    }
  }

  // ── Reusable scoring ─────────────────────────────────────────────────

  /// Score a single candidate against a source post. Returns null if the
  /// candidate should be filtered out (same-side, exchange block, below threshold).
  /// Public so RealtimeMatchingService and VoiceAssistantService can reuse it.
  double? scoreCandidate({
    required PostModel sourcePost,
    required PostModel candidate,
    required List<double> searchEmbedding,
    required String sourceSide,
    required bool sourceSymmetric,
    required Set<String> sourceKw,
    required List<String> complementaryIntents,
  }) {
    final candidateEmbedding = candidate.embedding ?? [];
    if (candidateEmbedding.isEmpty) return null;

    // Signal 1: Semantic similarity
    final semSim = _geminiService.calculateSimilarity(
      searchEmbedding,
      candidateEmbedding,
    );

    // Signal 2: Keyword overlap
    final candidateKw = Set<String>.from(candidate.keywords ?? []);
    final shared = sourceKw.intersection(candidateKw);
    int compHits = 0;
    for (final ci in complementaryIntents) {
      for (final word in ci.toLowerCase().split(' ')) {
        if (word.length > 3 &&
            !_compHitStopWords.contains(word) &&
            candidateKw.contains(word)) {
          compHits++;
          break;
        }
      }
    }
    final totalKwHits = shared.length + compHits;
    final kwScore = totalKwHits <= 0
        ? 0.0
        : totalKwHits == 1
            ? 0.50
            : totalKwHits == 2
                ? 0.75
                : 1.0;

    final relevance = max(semSim, kwScore * ApiConfig.matchKeywordDamping);
    if (relevance < ApiConfig.matchPreFilterThreshold) return null;

    // Keyword gate: no domain-specific keyword evidence + weak semantic = skip
    if (shared.isEmpty && compHits == 0 && semSim < 0.85) return null;

    // Same-side block
    final candidateSide = inferSide(candidate);
    final candidateSymmetric =
        candidate.intentAnalysis['is_symmetric'] == true;
    if (sourceSide == candidateSide &&
        sourceSide != 'neutral' &&
        !(sourceSymmetric && candidateSymmetric)) {
      return null;
    }

    // Exchange model block
    final srcEx =
        (sourcePost.intentAnalysis['exchange_model'] ?? 'unspecified')
            .toString();
    final cndEx =
        (candidate.intentAnalysis['exchange_model'] ?? 'unspecified')
            .toString();
    if ((srcEx == 'free' && cndEx == 'paid') ||
        (srcEx == 'paid' && cndEx == 'free') ||
        (srcEx == 'equity' && cndEx == 'paid')) {
      return null;
    }

    // Intent complement bonus — gated on evidence to block cross-domain noise
    final complementary =
        (sourceSide == 'offer' && candidateSide == 'seek') ||
            (sourceSide == 'seek' && candidateSide == 'offer') ||
            (sourceSymmetric && candidateSymmetric) ||
            sourceSide == 'neutral' ||
            candidateSide == 'neutral';
    final hasEvidence = semSim >= 0.65 || (kwScore > 0 && semSim >= 0.55);
    final intentBonus =
        complementary && hasEvidence ? ApiConfig.matchIntentBonus : 0.0;

    // Location bonus
    final locBonus =
        _locationScore(sourcePost, candidate) * ApiConfig.matchLocationWeight;

    // Lifestyle penalty
    final penalty = _lifestylePenalty(sourcePost, candidate);

    final finalScore =
        (relevance + intentBonus + locBonus - penalty).clamp(0.0, 1.0);
    if (finalScore < ApiConfig.matchFinalThreshold) return null;

    return finalScore;
  }

  /// Find matches for a given PostModel directly (no Firestore fetch needed).
  /// Used by RealtimeMatchingService and VoiceAssistantService.
  Future<List<PostModel>> findMatchesForPost(PostModel sourcePost) async {
    try {
      final sourceEmbedding = sourcePost.embedding ?? [];
      if (sourceEmbedding.isEmpty) return [];

      final complementaryIntents = List<String>.from(
        sourcePost.intentAnalysis['complementary_intents'] ?? [],
      );
      List<double> searchEmbedding;
      if (complementaryIntents.isNotEmpty) {
        final searchText =
            '${complementaryIntents.join('. ')} ${sourcePost.searchKeywords.join(' ')}';
        searchEmbedding = await _geminiService.generateEmbedding(searchText);
      } else {
        final fallbackText = '${sourcePost.title} ${sourcePost.description} '
            '${sourcePost.searchKeywords.join(' ')}';
        searchEmbedding = await _geminiService.generateEmbedding(fallbackText);
      }

      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .limit(ApiConfig.matchQueryLimit)
          .get();

      final List<PostModel> matches = [];
      final sourceSide = inferSide(sourcePost);
      final sourceSymmetric =
          sourcePost.intentAnalysis['is_symmetric'] == true;
      final sourceKw = Set<String>.from(sourcePost.keywords ?? []);

      for (final doc in querySnapshot.docs) {
        if (doc.data()['userId'] == sourcePost.userId) continue;
        final candidate = PostModel.fromFirestore(doc);

        final score = scoreCandidate(
          sourcePost: sourcePost,
          candidate: candidate,
          searchEmbedding: searchEmbedding,
          sourceSide: sourceSide,
          sourceSymmetric: sourceSymmetric,
          sourceKw: sourceKw,
          complementaryIntents: complementaryIntents,
        );

        if (score == null) continue;
        matches.add(candidate.copyWith(similarityScore: score));
      }

      matches.sort((a, b) =>
          (b.similarityScore ?? 0).compareTo(a.similarityScore ?? 0));
      return matches.take(ApiConfig.matchMaxResults).toList();
    } catch (e) {
      debugPrint('Error in findMatchesForPost: $e');
      return [];
    }
  }

  /// Get user's active posts
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('  Error getting user posts: $e');
      return [];
    }
  }

  Future<bool> deactivatePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('  Error deactivating post: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      return true;
    } catch (e) {
      debugPrint('  Error deleting post: $e');
      return false;
    }
  }

  Stream<List<PostModel>> streamUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PostModel.fromFirestore(d)).toList());
  }

  Future<void> incrementViewCount(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('   Error incrementing view count: $e');
    }
  }

  Future<void> addMatchedUser(String postId, String matchedUserId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'matchedUserIds': FieldValue.arrayUnion([matchedUserId]),
      });
    } catch (e) {
      debugPrint('   Error adding matched user: $e');
    }
  }
}

/// Extension to add copyWith method to PostModel
extension PostModelExtension on PostModel {
  PostModel copyWith({
    String? id,
    String? userId,
    String? originalPrompt,
    String? title,
    String? description,
    Map<String, dynamic>? intentAnalysis,
    List<String>? images,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    List<double>? embedding,
    List<String>? keywords,
    double? similarityScore,
    String? location,
    double? latitude,
    double? longitude,
    double? price,
    double? priceMin,
    double? priceMax,
    String? currency,
    int? viewCount,
    List<String>? matchedUserIds,
    Map<String, dynamic>? clarificationAnswers,
    String? gender,
    String? ageRange,
    String? condition,
    String? brand,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      title: title ?? this.title,
      description: description ?? this.description,
      intentAnalysis: intentAnalysis ?? this.intentAnalysis,
      images: images ?? this.images,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      embedding: embedding ?? this.embedding,
      keywords: keywords ?? this.keywords,
      similarityScore: similarityScore ?? this.similarityScore,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      price: price ?? this.price,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      currency: currency ?? this.currency,
      viewCount: viewCount ?? this.viewCount,
      matchedUserIds: matchedUserIds ?? this.matchedUserIds,
      clarificationAnswers: clarificationAnswers ?? this.clarificationAnswers,
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
    );
  }
}
