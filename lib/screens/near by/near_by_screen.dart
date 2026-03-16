import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../services/ip_location_service.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_text_styles.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../models/nearby_model.dart';
import 'near_by_post_detail_screen.dart';
import 'saved_nearby_screen.dart';

// Floating card animation — same as networking screen
class _FloatingCard extends StatefulWidget {
  final Widget child;
  final int animationIndex;

  const _FloatingCard({required this.child, this.animationIndex = 0});

  @override
  State<_FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<_FloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    final ms = 1600 + (widget.animationIndex % 6) * 220;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    _controller.value = (widget.animationIndex * 0.17) % 1.0;
    _controller.repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class NearByScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isVisible;

  const NearByScreen({super.key, this.onBack, this.isVisible = false});

  // ── Static cache so data survives widget rebuilds ──
  static Map<String, List<Map<String, dynamic>>> _cachedPostsByTab = {};
  static double? _cachedLat;
  static double? _cachedLng;
  static bool _hasEverLoaded = false;

  @override
  State<NearByScreen> createState() => _NearByScreenState();
}

class _NearByScreenState extends State<NearByScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Separate ScrollController per tab to avoid shared-controller conflicts
  late final List<ScrollController> _scrollControllers;
  final TextEditingController _searchController = TextEditingController();

  // Posts data per tab (from API, categorized by domain)
  Map<String, List<Map<String, dynamic>>> _postsByTab = {};
  bool _isLoading = true;
  String? _apiError;


  // Current user location for distance calculation
  double? _myLat;
  double? _myLng;

  // Voice search
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  // Categories — Products first since most posts are product listings
  String _selectedCategory = 'Products';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Products', 'icon': Icons.shopping_bag_rounded},
    {'name': 'Services', 'icon': Icons.computer_rounded},
  ];

  bool _hasFetchedOnce = false;

  // Saved/bookmarked post IDs
  final Set<String> _savedPostIds = {};
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(_categories.length, (_) => ScrollController());
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategory = _categories[_tabController.index]['name'];
        });
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPostIds();

    // ── Restore from static cache instantly (no loading spinner) ──
    if (NearByScreen._hasEverLoaded && NearByScreen._cachedPostsByTab.isNotEmpty) {
      _postsByTab = Map.of(NearByScreen._cachedPostsByTab);
      _myLat = NearByScreen._cachedLat;
      _myLng = NearByScreen._cachedLng;
      _isLoading = false;
    }

    _initSpeech();

    // Only fetch if already visible on first build
    if (widget.isVisible) {
      _hasFetchedOnce = true;
      _loadMyLocationThenFetchFeed();
    }
  }

  @override
  void didUpdateWidget(covariant NearByScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fetch when user navigates to Nearby tab for the first time
    if (widget.isVisible && !oldWidget.isVisible && !_hasFetchedOnce) {
      _hasFetchedOnce = true;
      _loadMyLocationThenFetchFeed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _stopVoiceSearch();
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    _searchController.dispose();
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  /// Load all saved post IDs from Firestore once
  Future<void> _loadSavedPostIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .get();
      if (mounted) {
        setState(() {
          _savedPostIds.clear();
          for (final doc in snap.docs) {
            _savedPostIds.add(doc.id);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading saved post IDs: $e');
    }
  }

  /// Toggle save/unsave a nearby post
  Future<void> _toggleSavePost(String postId, Map<String, dynamic> postData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();

    final wasSaved = _savedPostIds.contains(postId);
    // Optimistic UI update
    setState(() {
      if (wasSaved) {
        _savedPostIds.remove(postId);
      } else {
        _savedPostIds.add(postId);
      }
    });

    try {
      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(postId);
      if (wasSaved) {
        await ref.delete();
      } else {
        await ref.set({
          'savedAt': FieldValue.serverTimestamp(),
          'postData': postData,
          'source': 'nearby',
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (wasSaved) {
            _savedPostIds.add(postId);
          } else {
            _savedPostIds.remove(postId);
          }
        });
      }
      debugPrint('Error toggling save: $e');
    }
  }

  /// Convert Firebase UID to deterministic UUID v5 (same logic as ProductApiService)
  String get _userUuid {
    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) return '';
    return const Uuid().v5(Namespace.url.value, 'singletap:$firebaseUid');
  }

  /// Load location first, then fetch feed from API
  Future<void> _loadMyLocationThenFetchFeed() async {
    await _loadMyLocation();
    await _fetchNearbyFeed();
  }

  /// Fetch nearby posts from /nearby/feed API using NearbyModel
  Future<void> _fetchNearbyFeed() async {
    if (!mounted) return;

    final userUuid = _userUuid;
    if (userUuid.isEmpty) {
      debugPrint('NearBy: No user UUID — skipping API call');
      if (mounted) setState(() { _isLoading = false; _apiError = 'Not logged in'; });
      return;
    }

    // Only show loading spinner if we have NO cached data
    if (_postsByTab.isEmpty) {
      setState(() { _isLoading = true; _apiError = null; });
    }

    // Try up to 2 times (initial + 1 retry) to handle Render cold starts
    for (int attempt = 0; attempt < 2; attempt++) {
      if (!mounted) return;

      try {
        String? token;
        try {
          token = await _auth.currentUser?.getIdToken();
        } catch (_) {}

        final uri = Uri.parse(AppAssets.nearbyFeedUrl);
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        };
        final body = json.encode({
          'user_id': userUuid,
          'lat': _myLat ?? 0.0,
          'lng': _myLng ?? 0.0,
          'radius_km': 50,
          'limit': 50,
        });

        debugPrint('NearBy: API request attempt ${attempt + 1}');

        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 60));

        debugPrint('NearBy: API response status=${response.statusCode}');

        if (response.statusCode == 200 && mounted) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;

          // Debug: dump first raw listing from API
          final rawBuy = decoded['buy'] as List? ?? [];
          final rawSell = decoded['sell'] as List? ?? [];
          final firstRaw = rawBuy.isNotEmpty ? rawBuy.first : (rawSell.isNotEmpty ? rawSell.first : null);
          if (firstRaw != null) {
            final rawData = firstRaw['data'] ?? {};
            final rawItems = rawData['items'] as List? ?? [];
            debugPrint('RAW_API_FIRST → listing_id=${firstRaw['listing_id']}, distance_km=${firstRaw['distance_km']}');
            debugPrint('RAW_API_FIRST → TOP-LEVEL KEYS=${(firstRaw as Map).keys.toList()}');
            debugPrint('RAW_API_FIRST → data.location=${rawData['location']}, data.target_location=${rawData['target_location']}, data.budget=${rawData['budget']}, data.price=${rawData['price']}');
            debugPrint('RAW_API_FIRST → images=${firstRaw['images']}, image_urls=${firstRaw['image_urls']}, data.images=${rawData['images']}');
            if (rawItems.isNotEmpty) {
              debugPrint('RAW_API_FIRST → items[0]=${json.encode(rawItems.first)}');
            } else {
              debugPrint('RAW_API_FIRST → items=EMPTY');
            }
          }

          // Parse with NearbyModel
          final nearbyModel = NearbyModel.fromJson(decoded);
          debugPrint('NearBy: NearbyModel parsed — buy=${nearbyModel.buy.length}, sell=${nearbyModel.sell.length}, seek=${nearbyModel.seek.length}, provide=${nearbyModel.provide.length}, total=${nearbyModel.totalCount}');

          // Convert all listings to flat card maps
          final allCards = nearbyModel.toFlatCards();

          // Categorize into tabs, deduplicate by listing_id AND
          // collapse near-identical listings from same user
          final tabPosts = <String, List<Map<String, dynamic>>>{
            'Products': [],
            'Services': [],
          };
          final seenIds = <String>{};
          // Track user+itemType+model combos → kept card reference
          final seenUserItems = <String, Map<String, dynamic>>{};

          // Helper to check if a card has valid price
          bool hasPrice(Map<String, dynamic> c) {
            final p = c['price'];
            return p != null && p != '' && p != 0;
          }

          // Sort by created_at descending so we keep the newest per combo
          allCards.sort((a, b) {
            final aDate = a['created_at']?.toString() ?? '';
            final bDate = b['created_at']?.toString() ?? '';
            return bDate.compareTo(aDate);
          });

          final firebaseUid = _auth.currentUser?.uid ?? '';

          // Capture current user's API user_id → Firebase UID mapping
          // so other users can resolve our profile when viewing our posts
          if (firebaseUid.isNotEmpty) {
            for (final card in allCards) {
              final cardOwnerId = (card['user_id'] ?? '').toString();
              if (cardOwnerId.isNotEmpty &&
                  (cardOwnerId == userUuid || cardOwnerId == firebaseUid)) {
                // This is our own listing — store the mapping
                _firestore.collection('api_user_mappings').doc(cardOwnerId).set({
                  'firebaseUid': firebaseUid,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true)).catchError((_) {});
                // Also store UUID v5 mapping
                if (userUuid.isNotEmpty && cardOwnerId != userUuid) {
                  _firestore.collection('api_user_mappings').doc(userUuid).set({
                    'firebaseUid': firebaseUid,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true)).catchError((_) {});
                }
                break;
              }
            }
          }

          for (final card in allCards) {
            // Skip current user's own posts — only show others' posts
            final cardOwnerId = (card['user_id'] ?? '').toString();
            if (cardOwnerId.isNotEmpty &&
                (cardOwnerId == userUuid || cardOwnerId == firebaseUid)) continue;

            final id = (card['listing_id'] ?? '').toString();
            if (id.isNotEmpty && seenIds.contains(id)) continue;
            if (id.isNotEmpty) seenIds.add(id);

            // Collapse duplicates: same user + same item type + same model/brand
            final userId = (card['user_id'] ?? '').toString();
            final itemType = (card['item_type'] ?? '').toString().toLowerCase();
            final cardModel = (card['model'] ?? '').toString().toLowerCase();
            final cardBrand = (card['brand'] ?? '').toString().toLowerCase();
            final dedupKey = '$userId|$itemType|$cardModel|$cardBrand';
            if (userId.isNotEmpty && itemType.isNotEmpty) {
              final existing = seenUserItems[dedupKey];
              if (existing != null) {
                // Merge price from duplicate if existing has no price
                if (!hasPrice(existing) && hasPrice(card)) {
                  existing['price'] = card['price'];
                }
                continue;
              }
            }

            final postType = (card['postType'] ?? 'Products').toString();
            final targetList = tabPosts[postType] ?? tabPosts['Products']!;
            targetList.add(card);

            if (userId.isNotEmpty && itemType.isNotEmpty) {
              seenUserItems[dedupKey] = card;
            }
          }

          debugPrint('NearBy: Products=${tabPosts['Products']!.length}, Services=${tabPosts['Services']!.length}');

          // Debug: log first card's key fields to verify data flow
          if (allCards.isNotEmpty) {
            final sample = allCards.first;
            debugPrint('NearBy: SAMPLE CARD → title=${sample['title']}, price=${sample['price']}, location=${sample['location']}, domain=${sample['domain']}, distance_km=${sample['distance_km']}, feedCategory=${sample['feedCategory']}, images=${(sample['images'] as List?)?.length ?? 0}');
          }

          if (mounted) {
            setState(() {
              _postsByTab = tabPosts;
              _isLoading = false;
              _apiError = null;
              NearByScreen._cachedPostsByTab = Map.of(tabPosts);
              NearByScreen._hasEverLoaded = true;
            });
          }
          return; // Success — exit retry loop

        } else {
          debugPrint('NearBy: API error ${response.statusCode}');
          if (attempt == 1 && mounted) {
            setState(() { _isLoading = false; _apiError = 'Server error (${response.statusCode})'; });
          }
        }
      } on TimeoutException {
        debugPrint('NearBy: API timed out (attempt ${attempt + 1})');
        if (attempt == 1 && mounted) {
          setState(() { _isLoading = false; _apiError = 'Server is starting up, pull to refresh'; });
        }
      } catch (e) {
        debugPrint('NearBy: API exception (attempt ${attempt + 1}): $e');
        if (attempt == 1 && mounted) {
          setState(() { _isLoading = false; _apiError = 'Connection error'; });
        }
      }

      // Wait before retry
      if (attempt == 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _loadMyLocation() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _isLoading = false; });
      return;
    }

    // Priority 1: Use static cache if available (instant)
    if (NearByScreen._cachedLat != null && NearByScreen._cachedLng != null) {
      setState(() {
        _myLat = NearByScreen._cachedLat;
        _myLng = NearByScreen._cachedLng;
        _isLoading = false;
      });
      debugPrint('NearBy: Using cached location: $_myLat, $_myLng');
      return;
    }

    // Priority 2: IP-based location
    try {
      final result = await IpLocationService.detectLocation().timeout(
        const Duration(seconds: 10),
      );
      if (result != null && mounted) {
        setState(() {
          _myLat = result['lat'] as double;
          _myLng = result['lng'] as double;
          _isLoading = false;
          NearByScreen._cachedLat = _myLat;
          NearByScreen._cachedLng = _myLng;
          });
        debugPrint('NearBy: Using IP location: $_myLat, $_myLng');
        return;
      }
    } catch (e) {
      debugPrint('NearBy: IP location error: $e');
    }

    // All location methods failed — show posts without distance filter
    if (mounted) {
      setState(() { _isLoading = false; });
    }
    debugPrint('NearBy: No location available — distance filter disabled');
  }

  double? _calcDistance(double? lat2, double? lng2) {
    if (_myLat == null || _myLng == null || lat2 == null || lng2 == null) {
      return null;
    }
    const r = 6371.0;
    final dLat = (lat2 - _myLat!) * (pi / 180);
    final dLng = (lng2 - _myLng!) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_myLat! * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _startVoiceSearch() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Request microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('Microphone permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if speech is available
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _stopVoiceSearch();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted && _isListening) {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!_speechEnabled) {
        debugPrint('Speech recognition not available');
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
    });

    // Start 5-second silence timer
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isListening && _searchController.text.isEmpty) {
        _stopVoiceSearch();
      }
    });

    // Start listening
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          if (result.recognizedWords.isNotEmpty) {
            _silenceTimer?.cancel();
          }

          // Update search controller text and move cursor to end
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );

          // Force rebuild to apply filter
          setState(() {});

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _stopVoiceSearch();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN', // Support for Indian English
    );
  }

  void _stopVoiceSearch() async {
    if (!mounted) return;

    _silenceTimer?.cancel();
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  /// Title Case helper
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').where((w) => w.isNotEmpty).map((w) =>
      '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
    ).join(' ');
  }

  /// Helper to get a post's unique ID from API data
  String _getPostId(Map<String, dynamic> post) {
    return (post['id'] ?? post['listing_id'] ?? post['_syntheticId'] ?? '').toString();
  }

  List<Map<String, dynamic>> _getFilteredPosts(String category) {
    final searchQuery = _searchController.text.toLowerCase().trim();

    // Get posts for this tab directly from API-categorized data
    final tabList = _postsByTab[category] ?? [];

    final result = tabList.where((data) {
      // Search filter
      if (searchQuery.isNotEmpty && !_matchesSearch(data, searchQuery)) {
        return false;
      }

      return true;
    }).toList();

    // Sort by distance (nearest first)
    if (_myLat != null && _myLng != null) {
      result.sort((a, b) {
        final aDist = _calcDistance(
          (a['latitude'] as num?)?.toDouble(),
          (a['longitude'] as num?)?.toDouble(),
        ) ?? double.infinity;
        final bDist = _calcDistance(
          (b['latitude'] as num?)?.toDouble(),
          (b['longitude'] as num?)?.toDouble(),
        ) ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }

    return result;
  }

  bool _matchesSearch(Map<String, dynamic> data, String searchQuery) {
    final title = (data['title'] ?? '').toString().toLowerCase();
    if (title.contains(searchQuery)) return true;

    final description = (data['description'] ?? '').toString().toLowerCase();
    if (description.contains(searchQuery)) return true;

    final prompt = (data['originalPrompt'] ?? '').toString().toLowerCase();
    if (prompt.contains(searchQuery)) return true;

    final userName = (data['userName'] ?? '').toString().toLowerCase();
    if (userName.contains(searchQuery)) return true;

    final rawH = data['hashtags'];
    final hashtags = (rawH is List) ? rawH.join(' ').toLowerCase() : '';
    if (hashtags.contains(searchQuery)) return true;

    final rawK = data['keywords'];
    final keywords = (rawK is List) ? rawK.join(' ').toLowerCase() : '';
    if (keywords.contains(searchQuery)) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Nearby',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedNearbyScreen()),
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Colors.white,
              indicatorWeight: 1,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              isScrollable: false,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabAlignment: TabAlignment.fill,
              tabs: _categories.map((c) => Tab(text: c['name'] as String)).toList(),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: Column(
          children: [
            // Spacer for AppBar + TabBar
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(_categories.length, (tabIndex) {
                  final tabCategory = _categories[tabIndex]['name'] as String;
                  final tabPosts = _getFilteredPosts(tabCategory);
                  return _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : tabPosts.isEmpty
                      ? RefreshIndicator(
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          onRefresh: _loadMyLocationThenFetchFeed,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildGlassSearchBar(),
                              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                              _buildEmptyState(),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          onRefresh: _loadMyLocationThenFetchFeed,
                          child: CustomScrollView(
                            controller: _scrollControllers[tabIndex],
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(child: _buildGlassSearchBar()),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                                sliver: SliverMasonryGrid.count(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childCount: tabPosts.length,
                                  itemBuilder: (context, index) {
                                    final data = tabPosts[index];
                                    final postId = _getPostId(data);
                                    return _FloatingCard(
                                      animationIndex: index,
                                      child: _buildPostCard(
                                        postId: postId,
                                        post: data,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: GlassSearchField(
        controller: _searchController,
        hintText: 'Search posts...',
        borderRadius: 16,
        showMic: true,
        isListening: _isListening,
        onMicTap: _startVoiceSearch,
        onStopListening: _stopVoiceSearch,
        onChanged: (value) {
          // Invalidate all filter caches since search query changed
            setState(() {});
        },
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
  }) {

    final rawModel = (post['model'] ?? '').toString();
    final rawBrand = (post['brand'] ?? '').toString();
    final rawTitle = (post['title'] ?? post['originalPrompt'] ?? 'No Title').toString();
    // Product name: prefer model, then title — Title Case
    final rawName = rawModel.isNotEmpty ? rawModel : rawTitle;
    final title = _toTitleCase(rawName);
    final brand = rawBrand.isNotEmpty ? _toTitleCase(rawBrand) : '';
    final feedCategory = (post['feedCategory'] ?? '').toString();
    final locationStr = (post['location'] ?? '').toString();
    final rawImgs = post['images'];
    final images = (rawImgs is List) ? rawImgs : <dynamic>[];
    final rawImageUrl = post['imageUrl'];

    final allImageUrls = <String>[];
    if (rawImageUrl != null && rawImageUrl.toString().isNotEmpty) {
      allImageUrls.add(rawImageUrl.toString());
    }
    for (final img in images) {
      final url = img?.toString() ?? '';
      if (url.isNotEmpty && !allImageUrls.contains(url)) allImageUrls.add(url);
    }
    // No fallback to user profile photo — only show actual post/product images
    final imageUrl = allImageUrls.isNotEmpty ? allImageUrls[0] : null;

    // Price — try price first, then budget as fallback
    String? priceText;
    for (final key in ['price', 'budget']) {
      final raw = post[key];
      if (raw == null || raw == '') continue;
      final priceNum = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString().replaceAll(RegExp(r'[₹$€£,\s]'), ''));
      if (priceNum != null && priceNum > 0) {
        priceText = priceNum == priceNum.roundToDouble()
            ? '₹${priceNum.toInt()}'
            : '₹${priceNum.toStringAsFixed(2)}';
        break;
      }
    }

    // Domain — show first domain as category tag
    final rawDomain = post['domain'];
    String domainStr = '';
    if (rawDomain is List && rawDomain.isNotEmpty) {
      domainStr = rawDomain.first.toString();
    } else if (rawDomain is String && rawDomain.isNotEmpty) {
      domainStr = rawDomain;
    }

    final postLat = (post['latitude'] as num?)?.toDouble();
    final postLng = (post['longitude'] as num?)?.toDouble();
    final calcDist = _calcDistance(postLat, postLng);
    final apiDistKm = (post['distance_km'] as num?)?.toDouble();
    final distance = calcDist ?? apiDistKm;
    final distanceText = distance != null && distance > 0
        ? (distance < 1
            ? '${(distance * 1000).toInt()} m'
            : '${distance.toStringAsFixed(1)} km')
        : '';

    // Debug: trace what values the card will actually display
    debugPrint('CARD_DEBUG[$postId] → title=$title, brand=$brand, priceText=$priceText, rawPrice=${post['price']}, rawBudget=${post['budget']}, location=$locationStr, distText=$distanceText, lat=$postLat, lng=$postLng, domain=$domainStr, imageUrl=$imageUrl');

    return Container(
        height: 200,
        margin: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full cover image or gradient placeholder
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildGradientPlaceholder(domainStr, itemType: (post['item_type'] ?? '').toString()),
                )
              else
                _buildGradientPlaceholder(domainStr, itemType: (post['item_type'] ?? '').toString()),

              // Bottom gradient fade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                      stops: const [0.35, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Full card tap area for navigation
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    Navigator.push(
                      context,
                      _ExpandRoute(
                        builder: (_) => NearByPostDetailScreen(
                          postId: postId,
                          post: post,
                          distanceText: distanceText,
                          tabCategory: _selectedCategory,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Top-left badge: Domain (e.g. "technology & electronics")
              if (domainStr.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            domainStr,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Top-right bookmark button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _toggleSavePost(postId, post),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF007AFF),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Icon(
                      _savedPostIds.contains(postId)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _savedPostIds.contains(postId)
                          ? Colors.white
                          : Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // Bottom glassmorphism info bar (IgnorePointer — non-interactive)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Line 1: Product name (model or title)
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            // Line 2: Brand + Buy/Sell badge in one row
                            if (brand.isNotEmpty || feedCategory.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (brand.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        brand,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.grey[400],
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  if (brand.isEmpty) const Spacer(),
                                  if (feedCategory.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: feedCategory == 'sell'
                                            ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
                                            : feedCategory == 'buy'
                                                ? const Color(0xFFFF9800).withValues(alpha: 0.85)
                                                : Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        feedCategory == 'sell' ? 'Selling' : feedCategory == 'buy' ? 'Buying' : _toTitleCase(feedCategory),
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            // Line 3: Price
                            if (priceText != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                priceText,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.green[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            // Line 4: Location / distance
                            if (distanceText.isNotEmpty || locationStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me,
                                    size: 11,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      [
                                        if (locationStr.isNotEmpty) locationStr,
                                        if (distanceText.isNotEmpty) distanceText,
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.grey[400],
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
    );
  }

  /// Gradient placeholder with category icon when no image is available
  Widget _buildGradientPlaceholder(String domain, {String itemType = ''}) {
    final domainLower = domain.toLowerCase();
    final typeLower = itemType.toLowerCase();

    // Pick gradient colors and icon based on domain/item type
    List<Color> colors;
    IconData icon;

    if (typeLower.contains('phone') || typeLower.contains('smartphone')) {
      colors = [const Color(0xFF1a1a2e), const Color(0xFF16213e)];
      icon = Icons.smartphone_rounded;
    } else if (typeLower.contains('gpu') || typeLower.contains('computer') || typeLower.contains('laptop')) {
      colors = [const Color(0xFF0f0c29), const Color(0xFF302b63)];
      icon = Icons.memory_rounded;
    } else if (typeLower.contains('gas') || typeLower.contains('petroleum') || typeLower.contains('fuel')) {
      colors = [const Color(0xFF1a1a0e), const Color(0xFF2d2d1a)];
      icon = Icons.local_fire_department_rounded;
    } else if (domainLower.contains('technology') || domainLower.contains('electronics')) {
      colors = [const Color(0xFF0d1b2a), const Color(0xFF1b2838)];
      icon = Icons.devices_rounded;
    } else if (domainLower.contains('fashion') || domainLower.contains('clothing')) {
      colors = [const Color(0xFF2d1b2e), const Color(0xFF1a1028)];
      icon = Icons.checkroom_rounded;
    } else if (domainLower.contains('food') || domainLower.contains('restaurant')) {
      colors = [const Color(0xFF2e1a0d), const Color(0xFF1a1208)];
      icon = Icons.restaurant_rounded;
    } else if (domainLower.contains('vehicle') || domainLower.contains('auto')) {
      colors = [const Color(0xFF1a1a2e), const Color(0xFF0d1b2a)];
      icon = Icons.directions_car_rounded;
    } else if (domainLower.contains('home') || domainLower.contains('furniture')) {
      colors = [const Color(0xFF1a2e1a), const Color(0xFF0d2a1b)];
      icon = Icons.home_rounded;
    } else if (domainLower.contains('energy') || domainLower.contains('utilities')) {
      colors = [const Color(0xFF2e2a0d), const Color(0xFF1a1808)];
      icon = Icons.bolt_rounded;
    } else if (domainLower.contains('service')) {
      colors = [const Color(0xFF0d2a2e), const Color(0xFF081a1a)];
      icon = Icons.build_rounded;
    } else {
      colors = [const Color(0xFF1a1a2e), const Color(0xFF121220)];
      icon = Icons.inventory_2_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.12),
          size: 64,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasError = _apiError != null;
    return Align(
      alignment: const Alignment(0, -0.4),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: Icon(
                hasError ? Icons.cloud_off_rounded : Icons.article_outlined,
                size: 64,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasError ? 'Could Not Load Posts' : 'No Posts Found',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? _apiError! : 'Try a different search or category',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            if (hasError) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  setState(() { _apiError = null; });
                  _loadMyLocationThenFetchFeed();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Tap to Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slide-up from bottom — like iOS App Store card open.
class _ExpandRoute<T> extends PageRouteBuilder<T> {
  _ExpandRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnim = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            );

            // Open: slide in from left, Back: slide out to right
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(slideAnim);

            // Slight fade in at start
            final fadeAnimation = Tween<double>(
              begin: 0.5,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
        );
}
