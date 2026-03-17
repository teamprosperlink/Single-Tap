import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/product_models.dart';
import '../models/create_post_model.dart';
import '../res/config/app_assets.dart';
import '../res/utils/api_error_handler.dart';

class ProductApiService {
  // Singleton — keeps warmup, keep-alive timer, and cache alive across screens
  static final ProductApiService _instance = ProductApiService._internal();
  factory ProductApiService() => _instance;
  ProductApiService._internal();

  String? _cachedToken;
  DateTime? _tokenExpiry;
  String? _cachedUuid;
  bool _isWarmedUp = false;
  Timer? _keepAliveTimer;
  DateTime? _lastWarmUp;
  Future<void>? _warmUpFuture;

  // Cache disabled — always fetch fresh real-time results

  // Backend quota tracking — avoid hammering a quota-exceeded backend
  bool _backendQuotaExceeded = false;
  DateTime? _quotaExceededAt;

  /// No-op — cache disabled, always fresh results.
  void resetCache() {}

  /// Get Firebase auth token — force refresh if expired
  Future<String?> _getAuthToken({bool forceRefresh = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      if (forceRefresh ||
          _cachedToken == null ||
          _tokenExpiry == null ||
          DateTime.now().isAfter(_tokenExpiry!)) {
        _cachedToken = await user.getIdToken(true);
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        debugPrint('ProductAPI: token refreshed (force=$forceRefresh)');
      }

      return _cachedToken;
    } catch (e) {
      debugPrint('ProductApiService: Token error - $e');
      return null;
    }
  }

  /// Convert Firebase UID to deterministic UUID v5
  String get _userUuid {
    if (_cachedUuid != null) return _cachedUuid!;
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) return '';
    _cachedUuid =
        const Uuid().v5(Namespace.url.value, 'singletap:$firebaseUid');
    return _cachedUuid!;
  }

  /// Wake up the Render backend so it's ready when user searches.
  Future<void> warmUp() async {
    if (_isWarmedUp &&
        _lastWarmUp != null &&
        DateTime.now().difference(_lastWarmUp!) <
            const Duration(minutes: 4)) {
      return; 
    }
    _lastWarmUp = DateTime.now();

    final sw = Stopwatch()..start();
    final healthUrl =
        AppAssets.productApiUrl.replaceAll('/search-and-match', '/health');

    _warmUpFuture = http
        .get(Uri.parse(healthUrl), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30))
        .then((_) {
      _isWarmedUp = true;
      debugPrint(
          'ProductAPI: health warmup done in ${sw.elapsedMilliseconds}ms');
    }).catchError((e) {
      _isWarmedUp = true;
      debugPrint('ProductAPI: health warmup sent (${e.runtimeType})');
    });

    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _pingBackend();
    });
  }

  void _pingBackend() {
    http
        .get(
          Uri.parse(AppAssets.productApiUrl
              .replaceAll('/search-and-match', '/health')),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30))
        .ignore();

    _lastWarmUp = DateTime.now();
    debugPrint('ProductAPI: keep-alive health ping sent');
  }

  /// Common POST call — returns cards only
  Future<List<Map<String, dynamic>>> _callApi(String query, {bool bidirectionalMatching = true, double? lat, double? lng}) async {
    final result = await _callApiFull(query, bidirectionalMatching: bidirectionalMatching, lat: lat, lng: lng);
    return result['products'] as List<Map<String, dynamic>>;
  }

  /// Full API call to /search-and-match — returns both products and message.
  Future<Map<String, dynamic>> _callApiFull(String query, {bool bidirectionalMatching = true, double? lat, double? lng}) async {
    if (_backendQuotaExceeded && _quotaExceededAt != null) {
      final elapsed = DateTime.now().difference(_quotaExceededAt!);
      if (elapsed < const Duration(minutes: 10)) {
        debugPrint(
            'ProductAPI: Skipping call — backend quota exceeded ${elapsed.inMinutes}m ago');
        return {
          'products': <Map<String, dynamic>>[],
          'message': 'AI search is temporarily unavailable (quota exceeded). Showing nearby listings instead.',
          '_error': true,
        };
      }
      _backendQuotaExceeded = false;
      _quotaExceededAt = null;
      debugPrint('ProductAPI: Quota cooldown passed — retrying');
    }

    final sw = Stopwatch()..start();
    final userUuid = _userUuid;
    if (userUuid.isEmpty) {
      debugPrint('ProductApiService: No authenticated user');
      return {'products': <Map<String, dynamic>>[], 'message': '', '_error': true};
    }

    final token = await _getAuthToken();
    debugPrint('ProductAPI: [${sw.elapsedMilliseconds}ms] auth token ready');

    final uri = Uri.parse(AppAssets.productApiUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final bodyMap = {
      'query': query,
      'user_id': userUuid,
      'bidirectional_matching': true,
      'lat': lat ?? 0,
      'lng': lng ?? 0,
    };
    final body = json.encode(bodyMap);
    debugPrint('ProductAPI: REQUEST body=$body');

    late http.Response response;
    const apiTimeout = Duration(seconds: 120);
    const maxRetries = 2; // Retry up to 2 times (3 attempts total) for cold-start resilience
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        response = await http
            .post(uri, headers: headers, body: body)
            .timeout(apiTimeout);
        debugPrint(
            'ProductAPI: [${sw.elapsedMilliseconds}ms] response received (attempt ${attempt + 1}), status=${response.statusCode}');

        // Retry on 502/503/504 — Render returns these during cold start
        if ((response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) && attempt < maxRetries) {
          debugPrint('ProductAPI: server not ready (${response.statusCode}), retrying in 3s...');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        break; // Success or non-retryable status — exit retry loop
      } on TimeoutException {
        debugPrint('ProductAPI: [${sw.elapsedMilliseconds}ms] attempt ${attempt + 1} timed out');
        if (attempt == maxRetries) {
          return {
            'products': <Map<String, dynamic>>[],
            'message': 'Search is taking too long. The server may be warming up — please try again in a moment.',
            '_error': true,
          };
        }
      } catch (e) {
        debugPrint('ProductAPI: [${sw.elapsedMilliseconds}ms] attempt ${attempt + 1} error: $e');
        if (attempt == maxRetries) {
          return {
            'products': <Map<String, dynamic>>[],
            'message': 'Connection error. Please check your internet and try again.',
            '_error': true,
          };
        }
        // Brief pause before retry to let backend wake up
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (response.statusCode == 200) {
      _backendQuotaExceeded = false;
      _quotaExceededAt = null;

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('ProductAPI: Response is not a Map: ${response.body.substring(0, 200)}');
        return {'products': <Map<String, dynamic>>[], 'message': ''};
      }
      // Log raw response for debugging
      final bodyPreview = response.body.length > 2000
          ? response.body.substring(0, 2000) : response.body;
      debugPrint('ProductAPI: RAW RESPONSE: $bodyPreview');
      debugPrint('ProductAPI: has_matches=${decoded['has_matches']}, '
          'similar_matching_enabled=${decoded['similar_matching_enabled']}, '
          'matched_listings type=${decoded['matched_listings']?.runtimeType} count=${(decoded['matched_listings'] as List?)?.length ?? 0}, '
          'similar_listings type=${decoded['similar_listings']?.runtimeType} count=${(decoded['similar_listings'] as List?)?.length ?? 0}');

      List<Map<String, dynamic>> cards = [];
      String message = decoded['message']?.toString() ?? '';

      try {
        final model = ProductModels.fromJson(decoded);
        debugPrint(
            'ProductAPI: PARSED matched_listings=${model.matchedListings.length}, similar_listings=${model.similarListings.length}, match_count=${model.matchCount}, similar_count=${model.similarCount}, message="${model.message}"');
        cards = model.toCardList();
        message = model.message;
        debugPrint(
            'ProductAPI: [${sw.elapsedMilliseconds}ms] toCardList produced ${cards.length} cards');
      } catch (parseError, parseStack) {
        debugPrint('ProductAPI: MODEL PARSE ERROR: $parseError');
        debugPrint('ProductAPI: PARSE STACK: $parseStack');
        // Fallback: extract cards directly from raw JSON
        cards = _extractCardsFromRawJson(decoded);
        debugPrint('ProductAPI: RAW FALLBACK produced ${cards.length} cards');
      }

      // Deduplicate by listing_id & remove the query's own envelope listing
      final ownListingId = decoded['listing_id']?.toString() ?? '';
      final beforeCount = cards.length;
      final seenIds = <String>{};
      cards.removeWhere((card) {
        final cardListingId = card['listing_id']?.toString() ?? '';
        // Remove the envelope listing (the one created for this search query)
        if (cardListingId.isNotEmpty && cardListingId == ownListingId) return true;
        // Deduplicate by listing_id
        if (cardListingId.isNotEmpty && !seenIds.add(cardListingId)) return true;
        return false;
      });
      if (cards.length != beforeCount) {
        debugPrint('ProductAPI: filtered ${beforeCount - cards.length} duplicate cards → ${cards.length} remaining');
      }

      // Capture current user's API user_id mapping for profile resolution
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (firebaseUid.isNotEmpty) {
        for (final card in cards) {
          final cardUserId = card['user_id']?.toString() ?? '';
          if (cardUserId.isNotEmpty &&
              (cardUserId == userUuid || cardUserId == firebaseUid)) {
            FirebaseFirestore.instance
                .collection('api_user_mappings')
                .doc(cardUserId)
                .set({
                  'firebaseUid': firebaseUid,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true))
                .catchError((_) {});
            if (userUuid.isNotEmpty && cardUserId != userUuid) {
              FirebaseFirestore.instance
                  .collection('api_user_mappings')
                  .doc(userUuid)
                  .set({
                    'firebaseUid': firebaseUid,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true))
                  .catchError((_) {});
            }
            break;
          }
        }
      }

      // Filter out current user's own listings so they only see others' posts
      final beforeUserFilter = cards.length;
      cards.removeWhere((card) {
        final cardUserId = card['user_id']?.toString() ?? '';
        return cardUserId.isNotEmpty &&
            (cardUserId == userUuid || cardUserId == firebaseUid);
      });
      if (cards.length != beforeUserFilter) {
        debugPrint('ProductAPI: removed ${beforeUserFilter - cards.length} own posts → ${cards.length} remaining');
        // Update message to reflect actual remaining count after filtering
        if (cards.isEmpty) {
          message = 'No matches found from other users. Try a different search.';
        } else {
          message = 'Found ${cards.length} match${cards.length == 1 ? '' : 'es'} for you';
        }
      }

      // Resolve Firebase UIDs for remaining cards so Chat/Call work on detail screen
      await _resolveFirebaseUids(cards);

      return {'products': cards, 'message': message};
    } else {
      debugPrint('ProductAPI: Error ${response.statusCode} - ${response.body}');

      final bodyLower = response.body.toLowerCase();

      // Quota exceeded — pause calls
      if ((response.statusCode == 500 || response.statusCode == 429) &&
          (bodyLower.contains('insufficient_quota') ||
           bodyLower.contains('exceeded your current quota') ||
           bodyLower.contains('rate_limit') ||
           bodyLower.contains('quota'))) {
        _backendQuotaExceeded = true;
        _quotaExceededAt = DateTime.now();
        debugPrint('ProductAPI: Backend AI quota exceeded — pausing calls for 10 min');
      }

      // Parse user-friendly error message for all error codes
      final userMessage = _parseErrorResponse(response.statusCode, response.body);
      return {
        'products': <Map<String, dynamic>>[],
        'message': userMessage,
        '_error': true,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  MAIN SEARCH METHOD (search-and-match ONLY — for Home screen)
  // ─────────────────────────────────────────────────────────────

  /// Search products using /search-and-match API only.
  /// Nearby/feed APIs are handled separately by the NearBy screen.
  Future<Map<String, dynamic>> searchWithResponse(String query, {bool bidirectionalMatching = true, double? lat, double? lng}) async {
    final sw = Stopwatch()..start();

    // Ensure backend is warmed up before searching
    if (!_isWarmedUp) {
      if (_warmUpFuture == null) {
        debugPrint('ProductAPI: warmup not started, triggering now...');
        warmUp(); // fire warmup in parallel
      }
      if (_warmUpFuture != null) {
        debugPrint('ProductAPI: waiting for health warmup...');
        await _warmUpFuture!.timeout(
          const Duration(seconds: 30), // Render free tier needs time
          onTimeout: () {
            debugPrint('ProductAPI: health warmup still running, proceeding with search');
          },
        );
      }
    }

    // Always fetch fresh real-time results — no cache
    // Call _callApiFull directly (it handles all errors internally and always
    // returns a valid map with 'products', 'message', and '_error' keys).
    Map<String, dynamic> data;
    try {
      data = await _callApiFull(query, bidirectionalMatching: bidirectionalMatching, lat: lat, lng: lng);
    } catch (e) {
      debugPrint('ProductAPI: unexpected search error: $e');
      data = <String, dynamic>{
        'products': <Map<String, dynamic>>[],
        'message': 'Something went wrong. Please try again.',
        '_error': true,
      };
    }

    final products = data['products'] as List<Map<String, dynamic>>? ?? [];
    debugPrint('ProductAPI: search-and-match returned ${products.length} cards in ${sw.elapsedMilliseconds}ms');

    return data;
  }

  // ─────────────────────────────────────────────────────────────
  //  SIMPLE SEARCH / HOME PRODUCTS
  // ─────────────────────────────────────────────────────────────

  /// Search products by user query (simple version, returns cards only)
  Future<List<Map<String, dynamic>>> searchProducts(String query, {bool bidirectionalMatching = true}) async {
    final results =
        await ApiErrorHandler.handleApiCall<List<Map<String, dynamic>>>(
      () => _callApi(query, bidirectionalMatching: bidirectionalMatching),
      fallback: () => <Map<String, dynamic>>[],
      onError: (errorType) {
        debugPrint('ProductApiService: Search error - ${ApiErrorHandler.getErrorMessage(errorType)}');
      },
    );
    return results ?? [];
  }

  /// Get products for home screen display
  Future<List<Map<String, dynamic>>> getHomeProducts() async {
    final results =
        await ApiErrorHandler.handleApiCall<List<Map<String, dynamic>>>(
      () => _callApi(''),
      fallback: () => <Map<String, dynamic>>[],
      onError: (errorType) {
        debugPrint('ProductApiService: Home error - ${ApiErrorHandler.getErrorMessage(errorType)}');
      },
    );
    return results ?? [];
  }

  // ─────────────────────────────────────────────────────────────
  //  CREATE POST
  // ─────────────────────────────────────────────────────────────

  /// Create a new post via /store-listing API
  Future<Map<String, dynamic>> createPost({
    required String query,
    String category = 'buy',
    String? title,
    String? description,
    double? price,
    String? highlights,
    double? lat,
    double? lng,
    List<String> images = const [],
    String? locationName,
  }) async {
    final userUuid = _userUuid;
    if (userUuid.isEmpty) {
      return {'success': false, 'error': 'No authenticated user'};
    }

    final token = await _getAuthToken();
    final uri = Uri.parse(AppAssets.storeListingUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    // Combine all fields into query so backend gets full context
    // (backend currently only reads 'query' for AI processing)
    final categoryLabel = switch (category) {
          'sell' => 'Selling',
          'seek' => 'Seeking',
          'provide' => 'Providing',
          'mutual' => 'Mutual Exchange',
          _ => 'Buying',
        };
    final queryParts = <String>['$categoryLabel: $query'];
    if (description != null && description.isNotEmpty) queryParts.add('Description: $description');
    if (price != null) queryParts.add('Price: $price');
    if (highlights != null && highlights.isNotEmpty) queryParts.add('Highlights: $highlights');
    if (locationName != null && locationName.isNotEmpty) queryParts.add('Location: $locationName');
    final combinedQuery = queryParts.join('. ');

    final bodyMap = {
      'query': combinedQuery,
      'user_id': userUuid,
      'lat': lat ?? 0,
      'lng': lng ?? 0,
      'images': images,
      // Separate fields for when backend supports them
      'category': category,
      if (title != null && title.isNotEmpty) 'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (price != null) 'price': price,
      if (highlights != null && highlights.isNotEmpty) 'highlights': highlights,
      if (locationName != null && locationName.isNotEmpty) 'location_name': locationName,
    };
    final body = json.encode(bodyMap);

    // Check payload size — base64 images can be huge
    final payloadSizeMB = body.length / (1024 * 1024);
    debugPrint('ProductAPI: createPost URL=${AppAssets.storeListingUrl}');
    debugPrint('ProductAPI: createPost payload=${payloadSizeMB.toStringAsFixed(2)}MB, images=${images.length}');

    if (payloadSizeMB > 10) {
      debugPrint('ProductAPI: createPost payload too large (${payloadSizeMB.toStringAsFixed(1)}MB)');
      return {
        'success': false,
        'error': 'Images are too large. Please use fewer or smaller photos.',
      };
    }

    try {
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 90));

      debugPrint('ProductAPI: createPost status=${response.statusCode}');
      debugPrint('ProductAPI: createPost response=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        final postModel = CreatePostModel.fromJson(decoded);
        debugPrint('ProductAPI: PARSED -> listingId=${postModel.listingId}, intent=${postModel.intent}, images=${postModel.images.length}, message=${postModel.message}');

        // Clear search cache so next search includes the new post
        resetCache();

        return {
          'success': true,
          'data': postModel,
          'listingId': postModel.listingId,
          'message': postModel.message,
        };
      } else if ((response.statusCode == 401 || response.statusCode == 403) && token != null) {
        // Auth error — force-refresh token and retry once
        debugPrint('ProductAPI: createPost got ${response.statusCode}, retrying with fresh token...');
        _cachedToken = null;
        _tokenExpiry = null;
        final freshToken = await _getAuthToken(forceRefresh: true);
        if (freshToken != null) {
          headers['Authorization'] = 'Bearer $freshToken';
          final retryResponse = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 90));
          debugPrint('ProductAPI: createPost retry status=${retryResponse.statusCode}');
          if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
            final decoded = json.decode(retryResponse.body);
            final postModel = CreatePostModel.fromJson(decoded);
            resetCache();
            return {
              'success': true,
              'data': postModel,
              'listingId': postModel.listingId,
              'message': postModel.message,
            };
          }
          debugPrint('ProductAPI: createPost retry also failed: ${retryResponse.statusCode} - ${retryResponse.body}');
          return {'success': false, 'error': _parseErrorResponse(retryResponse.statusCode, retryResponse.body)};
        }
        return {'success': false, 'error': 'Authentication failed. Please try logging in again.'};
      } else {
        debugPrint('ProductAPI: createPost error ${response.statusCode} - ${response.body}');
        return {'success': false, 'error': _parseErrorResponse(response.statusCode, response.body)};
      }
    } on TimeoutException {
      debugPrint('ProductAPI: createPost timeout (90s)');
      return {'success': false, 'error': 'Server is starting up. Please try again in a moment.'};
    } catch (e) {
      debugPrint('ProductAPI: createPost exception - $e');
      return {'success': false, 'error': 'Connection error. Please check your internet and try again.'};
    }
  }

  /// Fallback: extract cards directly from raw API JSON when model parsing fails.
  List<Map<String, dynamic>> _extractCardsFromRawJson(Map<String, dynamic> decoded) {
    final cards = <Map<String, dynamic>>[];
    for (final key in ['matched_listings', 'similar_listings']) {
      final listings = decoded[key];
      if (listings is! List) continue;
      for (final item in listings) {
        if (item is! Map) continue;
        final data = item['data'] is Map ? Map<String, dynamic>.from(item['data'] as Map) : <String, dynamic>{};
        final images = data['images'] is List ? List<String>.from((data['images'] as List).map((e) => e.toString())) : <String>[];
        // Try resolving images from listing level too
        if (images.isEmpty) {
          for (final imgKey in ['images', 'image_urls', 'image']) {
            final val = item[imgKey];
            if (val is List && val.isNotEmpty) {
              images.addAll(val.map((e) => e.toString()));
              break;
            } else if (val is String && val.startsWith('http')) {
              images.add(val);
              break;
            }
          }
        }
        final intent = data['intent']?.toString() ?? '';
        final subintent = data['subintent']?.toString() ?? '';
        final name = subintent.isNotEmpty ? subintent : (intent.isNotEmpty ? intent : 'Listing');

        // Extract dating-specific fields
        String condition = '';
        final other = data['other'];
        if (other is Map) {
          final cat = other['categorical'];
          final rng = other['range'];
          final details = <String>[];
          if (cat is Map && cat['gender'] != null) details.add(cat['gender'].toString());
          if (rng is Map && rng['age'] is List) {
            final age = rng['age'] as List;
            if (age.length >= 2) details.add('${age[0]}-${age[1]} yrs');
          }
          if (cat is Map && cat['diet'] != null) details.add(cat['diet'].toString());
          if (details.isNotEmpty) condition = details.join(' · ');
        }

        cards.add({
          'name': name,
          'category': (data['domain'] is List && (data['domain'] as List).isNotEmpty) ? (data['domain'] as List).first.toString() : '',
          'price': data['budget']?.toString() ?? '',
          'location': '',
          'rating': '0.0',
          'image': images.isNotEmpty ? images.first : '',
          'images': images,
          'match_type': item['match_type']?.toString() ?? 'similar',
          'match_score': '${((item['similarity_score'] as num?)?.toDouble() ?? 0.0) * 100}%',
          'condition': condition,
          'intent': intent,
          'subintent': subintent,
          'smart_message': item['smart_message']?.toString() ?? data['reasoning']?.toString() ?? '',
          'recommendation': item['recommendation']?.toString() ?? '',
          'listing_id': item['listing_id']?.toString() ?? '',
          'user_id': item['user_id']?.toString() ?? '',
          'similarity_score': (item['similarity_score'] as num?)?.toDouble() ?? 0.0,
          'satisfied_constraints': item['satisfied_constraints'] ?? [],
          'unsatisfied_constraints': item['unsatisfied_constraints'] ?? [],
        });
      }
    }
    return cards;
  }

  /// Parse error response body into a user-friendly message
  String _parseErrorResponse(int statusCode, String responseBody) {
    // Try to extract error message from JSON response
    String serverMessage = '';
    try {
      final decoded = json.decode(responseBody);
      if (decoded is Map) {
        serverMessage = decoded['error'] as String? ??
            decoded['message'] as String? ??
            decoded['detail'] as String? ??
            '';
        // Some APIs nest the error
        if (serverMessage.isEmpty && decoded['error'] is Map) {
          serverMessage = (decoded['error'] as Map)['message'] as String? ?? '';
        }
      }
    } catch (_) {
      serverMessage = responseBody.length > 200
          ? responseBody.substring(0, 200)
          : responseBody;
    }

    debugPrint('ProductAPI: parsed server error: "$serverMessage"');

    final bodyLower = responseBody.toLowerCase();

    switch (statusCode) {
      case 400:
        // Bad Request — parse specific causes
        if (bodyLower.contains('image') && bodyLower.contains('large')) {
          return 'Images are too large. Please use smaller photos.';
        }
        if (bodyLower.contains('image') && (bodyLower.contains('invalid') || bodyLower.contains('format'))) {
          return 'Image format not supported. Please use JPG or PNG photos.';
        }
        if (bodyLower.contains('query') && (bodyLower.contains('required') || bodyLower.contains('missing') || bodyLower.contains('empty'))) {
          return 'Please enter what you are looking for.';
        }
        if (bodyLower.contains('user') && (bodyLower.contains('required') || bodyLower.contains('missing'))) {
          return 'Authentication error. Please log out and log in again.';
        }
        if (bodyLower.contains('validation') || bodyLower.contains('invalid')) {
          return serverMessage.isNotEmpty
              ? serverMessage
              : 'Invalid request. Please check your input and try again.';
        }
        if (bodyLower.contains('quota') || bodyLower.contains('exceeded') || bodyLower.contains('rate')) {
          return 'Service is busy. Please try again in a few minutes.';
        }
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'Invalid request. Please try again.';

      case 401:
        return 'Session expired. Please log out and log in again.';

      case 403:
        return 'Access denied. Please log out and log in again.';

      case 413:
        return 'Images are too large. Please use fewer or smaller photos.';

      case 429:
        return 'Too many requests. Please wait a moment and try again.';

      case 500:
        if (bodyLower.contains('quota') || bodyLower.contains('exceeded')) {
          return 'AI search quota exceeded. Please try again in a few minutes.';
        }
        return 'Server error. Please try again later.';

      case 502:
      case 503:
      case 504:
        return 'Server is starting up. Please try again in a minute.';

      default:
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'Something went wrong (error $statusCode). Please try again.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  RESOLVE FIREBASE UIDs FOR API CARDS (enables Chat/Call)
  // ─────────────────────────────────────────────────────────────

  /// Static in-memory cache: API user_id → { firebaseUid, name, photoUrl }
  static final Map<String, Map<String, String>> _uidCache = {};

  /// Batch-resolve Firebase UIDs for search result cards.
  /// Injects 'userId', 'userName', 'userPhoto' into each card so the
  /// detail screen's Chat/Call buttons work immediately.
  Future<void> _resolveFirebaseUids(List<Map<String, dynamic>> cards) async {
    if (cards.isEmpty) return;
    final firestore = FirebaseFirestore.instance;

    // Collect unique user_ids that need resolution
    final needsResolution = <String>{};
    for (final card in cards) {
      final apiUid = (card['user_id']?.toString() ?? '').trim();
      if (apiUid.isEmpty) continue;
      if (_uidCache.containsKey(apiUid)) {
        // Apply cached data immediately
        final cached = _uidCache[apiUid]!;
        card['userId'] = cached['firebaseUid'] ?? '';
        card['userName'] = cached['name'] ?? '';
        card['userPhoto'] = cached['photoUrl'] ?? '';
      } else {
        needsResolution.add(apiUid);
      }
    }

    if (needsResolution.isEmpty) return;
    debugPrint('ProductAPI: resolving ${needsResolution.length} user_ids for Chat/Call');

    // Resolve each unique user_id
    for (final apiUid in needsResolution) {
      String? fbUid;
      String name = '';
      String photo = '';

      try {
        // Strategy 1: api_user_mappings collection
        final mappingDoc = await firestore.collection('api_user_mappings').doc(apiUid).get();
        if (mappingDoc.exists) {
          fbUid = mappingDoc.data()?['firebaseUid']?.toString();
        }

        // Strategy 2: users collection by user_uuid field
        if (fbUid == null) {
          final userQuery = await firestore
              .collection('users')
              .where('user_uuid', isEqualTo: apiUid)
              .limit(1)
              .get();
          if (userQuery.docs.isNotEmpty) {
            fbUid = userQuery.docs.first.id;
            // Save mapping for future lookups
            firestore.collection('api_user_mappings').doc(apiUid).set({
              'firebaseUid': fbUid,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((_) {});
          }
        }

        // Strategy 3: Try user_id directly as Firebase UID
        if (fbUid == null) {
          final directDoc = await firestore.collection('users').doc(apiUid).get();
          if (directDoc.exists) {
            fbUid = apiUid;
          }
        }

        // Fetch name/photo if we found the Firebase UID
        if (fbUid != null && fbUid.isNotEmpty) {
          final userDoc = await firestore.collection('users').doc(fbUid).get();
          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            name = data['name']?.toString() ?? '';
            photo = (data['photoUrl'] ?? data['photoURL'] ?? data['profileImageUrl'])?.toString() ?? '';
          }
        }
      } catch (e) {
        debugPrint('ProductAPI: uid resolution error for $apiUid: $e');
      }

      // Cache result (even if null, to avoid re-querying)
      final resolved = {
        'firebaseUid': fbUid ?? '',
        'name': name,
        'photoUrl': photo,
      };
      _uidCache[apiUid] = resolved;

      if (fbUid != null && fbUid.isNotEmpty) {
        debugPrint('ProductAPI: resolved $apiUid → $fbUid ($name)');
      }
    }

    // Apply resolved data to all cards
    for (final card in cards) {
      final apiUid = (card['user_id']?.toString() ?? '').trim();
      if (apiUid.isEmpty) continue;
      final cached = _uidCache[apiUid];
      if (cached != null && (cached['firebaseUid'] ?? '').isNotEmpty) {
        card['userId'] = cached['firebaseUid']!;
        card['userName'] = cached['name'] ?? '';
        card['userPhoto'] = cached['photoUrl'] ?? '';
      }
    }
  }

  /// Clear all cached state (call on logout)
  void clearToken() {
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedUuid = null;
    _isWarmedUp = false;
    _lastWarmUp = null;
    _backendQuotaExceeded = false;
    _quotaExceededAt = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }
}
