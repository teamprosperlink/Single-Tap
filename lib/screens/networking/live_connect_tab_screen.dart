import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/ip_location_service.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../mixins/voice_search_mixin.dart';
import '../../models/extended_user_profile.dart';
import 'user_profile_detail_screen.dart';
import '../../services/connection_service.dart';
import '../../widgets/networking/networking_constants.dart';
import '../../widgets/networking/networking_helpers.dart';
import '../../widgets/networking/networking_widgets.dart';

class _MosaicCardData {
  final ExtendedUserProfile profile;
  final String userName;
  final String userId;

  const _MosaicCardData({
    required this.profile,
    required this.userName,
    required this.userId,
  });
}

/// Floating animation wrapper — each card bobs up & down continuously
class FloatingCard extends StatefulWidget {
  final Widget child;
  final int animationIndex;

  const FloatingCard({super.key, required this.child, this.animationIndex = 0});

  @override
  State<FloatingCard> createState() => FloatingCardState();
}

class FloatingCardState extends State<FloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    // Slightly different duration per card so they don't all move in sync
    final ms = 1600 + (widget.animationIndex % 6) * 220;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    // Start each card at a different phase so grid looks alive
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
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
      child: widget.child,
    );
  }
}

class LiveConnectTabScreen extends ConsumerStatefulWidget {
  final bool activateNearMeFilter; // Flag to activate "Near Me" filter on init
  final bool
  activateNetworkingFilter; // Flag to activate professional/networking filters on init

  const LiveConnectTabScreen({
    super.key,
    this.activateNearMeFilter = false,
    this.activateNetworkingFilter = false,
  });

  // ── Static cache so data survives widget rebuilds ──
  static String? _cachedUserId; // Track which user owns the cache
  static List<Map<String, dynamic>> _cachedNearbyPeople = [];
  static Map<String, dynamic>? _cachedUserProfile;
  static List<String> _cachedMyConnections = [];
  static List<String> _cachedPendingRequestUserIds = [];
  static List<String> _cachedSelectedInterests = [];
  static double? _cachedUserLat;
  static double? _cachedUserLon;
  static bool _hasEverLoaded = false;
  static DateTime? _cachedTimestamp;
  static final Map<String, bool> _globalConnectionStatusCache = {};
  static final Map<String, String?> _globalRequestStatusCache = {};

  static void clearCache() {
    _cachedNearbyPeople = [];
    _cachedUserProfile = null;
    _cachedMyConnections = [];
    _cachedPendingRequestUserIds = [];
    _cachedSelectedInterests = [];
    _cachedUserLat = null;
    _cachedUserLon = null;
    _hasEverLoaded = false;
    _cachedTimestamp = null;
    _globalConnectionStatusCache.clear();
    _globalRequestStatusCache.clear();
  }

  @override
  ConsumerState<LiveConnectTabScreen> createState() =>
      LiveConnectTabScreenState();
}

class LiveConnectTabScreenState extends ConsumerState<LiveConnectTabScreen>
    with SingleTickerProviderStateMixin, VoiceSearchMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionService _connectionService = ConnectionService();

  Map<String, dynamic>? _userProfile;
  List<String> _selectedInterests = [];
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  List<Map<String, dynamic>> _filteredPeople = []; // For search results
  bool _isLoadingPeople = true;
  String _searchQuery = ''; // Search query
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Real-time location for distance calculation
  double? _currentUserLat;
  double? _currentUserLon;

  // Location caching - prevent multiple refresh attempts
  DateTime? _lastLocationRefresh;
  bool _isRefreshingLocation = false;
  static const Duration _locationCacheDuration = Duration(seconds: 90);

  // Filter options
  bool _filterByInterests = false;
  bool _filterByGender = false;
  bool _filterByConnectionTypes = false;
  bool _filterByActivities = false;
  RangeValues _distanceRange = const RangeValues(1, 500); // Distance in km
  String _locationFilter =
      'Near me'; // 'Near me', 'City', 'Country', 'Worldwide'
  final List<String> _selectedGenders = [];
  RangeValues _ageRange = const RangeValues(18, 60);
  bool _showOnlineOnly = false;

  // Category-specific filter selections (keyed by filter label)
  final Map<String, String?> _categoryDropdownSelections = {};

  // Pagination variables
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20; // Number of users to load per page

  // Connection status caching (to avoid repeated Firestore queries)
  final Map<String, bool> _connectionStatusCache = {}; // userId -> isConnected
  final Map<String, String?> _requestStatusCache =
      {}; // userId -> 'sent'|'received'|null
  List<String> _myConnections = []; // List of connected user IDs
  List<String> _pendingRequestUserIds = []; // List of users with pending requests
  bool _connectionsLoaded = false;

  // Networking category filter
  String _selectedNetworkingCategory = 'All';
  String? _selectedSubcategory;

  // Category-specific filters and subcategory filters are now in NetworkingConstants
  // (categoryFilters, subcategoryFilters)

  // REMOVED: _categoryFilters and _subcategoryFilters — use NetworkingConstants instead

  // Available connection types (grouped)
  final Map<String, List<String>> _connectionTypeGroups = {
    'Social': [
      'Dating',
      'Friendship',
      'Casual Hangout',
      'Travel Buddy',
      'Nightlife Partner',
    ],
    'Professional': [
      'Networking',
      'Mentorship',
      'Business Partner',
      'Career Advice',
      'Freelancing',
    ],
    'Educational': [
      'Study Group',
      'Tutoring',
      'Language Exchange',
      'Skill Sharing',
      'Exam Prep',
    ],
    'Creative': [
      'Music Jam',
      'Art Collaboration',
      'Photography',
      'Content Creation',
      'Film Making',
    ],
    'Community': [
      'Volunteering',
      'Social Causes',
      'Environmental',
      'Community Service',
      'Youth Development',
    ],
    'Other': [
      'Roommate',
      'Pet Playdate',
      'Gaming',
      'Online Friends',
      'Event Companion',
    ],
  };

  // Available activities (grouped)
  final Map<String, List<String>> _activityGroups = {
    'Sports': [
      'Tennis',
      'Badminton',
      'Basketball',
      'Football',
      'Volleyball',
      'Golf',
      'Table Tennis',
      'Squash',
    ],
    'Fitness': [
      'Running',
      'Gym',
      'Yoga',
      'Pilates',
      'CrossFit',
      'Cycling',
      'Swimming',
      'Dance',
    ],
    'Outdoor': [
      'Hiking',
      'Rock Climbing',
      'Camping',
      'Kayaking',
      'Surfing',
      'Mountain Biking',
      'Trail Running',
    ],
    'Creative': [
      'Photography',
      'Painting',
      'Music',
      'Writing',
      'Cooking',
      'Crafts',
      'Gaming',
    ],
  };

  // Expanded state for each group
  final Map<String, bool> _expandedConnectionGroups = {};
  final Map<String, bool> _expandedActivityGroups = {};

  // Common interests for users to choose from
  final List<String> _availableInterests = [
    'Dating',
    'Friendship',
    'Business',
    'Roommate',
    'Job Seeker',
    'Hiring',
    'Selling',
    'Buying',
    'Lost & Found',
    'Events',
    'Sports',
    'Travel',
    'Food',
    'Music',
    'Movies',
    'Gaming',
    'Fitness',
    'Art',
    'Technology',
    'Photography',
    'Fashion',
  ];

  // Tab categories for TabBar
  final List<String> _tabCategories = ['Discover All ', 'Smart '];

  @override
  void initState() {
    super.initState();

    // Initialize speech from VoiceSearchMixin
    initSpeech();

    // Initialize TabController
    _tabController = TabController(length: _tabCategories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        HapticFeedback.lightImpact();
        final selectedCategory = _tabCategories[_tabController.index];
        setState(() {
          if (selectedCategory == 'Discover All ') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Near me';
          } else if (selectedCategory == 'Smart ') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Smart ';
          } else {
            _filterByInterests = true;
            _locationFilter = 'Smart ';
            _selectedInterests.removeWhere(
              (item) =>
                  ['Dating', 'Friendship', 'Business', 'Sports'].contains(item),
            );
            _selectedInterests.add(selectedCategory);
          }
        });
        _loadNearbyPeople();
      }
    });

    // Activate "Near Me" filter if requested
    if (widget.activateNearMeFilter) {
      _locationFilter = 'Near me';
    }

    // Activate Smart networking filter if requested
    if (widget.activateNetworkingFilter) {
      _locationFilter = 'Smart ';
    }

    // Initialize expanded state for all groups (all collapsed by default)
    for (var groupName in _connectionTypeGroups.keys) {
      _expandedConnectionGroups[groupName] = false;
    }
    for (var groupName in _activityGroups.keys) {
      _expandedActivityGroups[groupName] = false;
    }
    // ── Restore from static cache instantly (no spinner) ──
    // Only restore if cache belongs to the current user (prevents data leak on auth switch)
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (LiveConnectTabScreen._cachedUserId != null &&
        LiveConnectTabScreen._cachedUserId != currentUid) {
      LiveConnectTabScreen.clearCache();
    }
    if (LiveConnectTabScreen._hasEverLoaded &&
        LiveConnectTabScreen._cachedNearbyPeople.isNotEmpty) {
      _nearbyPeople = List.of(LiveConnectTabScreen._cachedNearbyPeople);
      _filteredPeople = List.of(_nearbyPeople);
      _userProfile = LiveConnectTabScreen._cachedUserProfile;
      _myConnections = List.of(LiveConnectTabScreen._cachedMyConnections);
      _pendingRequestUserIds = List.of(LiveConnectTabScreen._cachedPendingRequestUserIds);
      _selectedInterests = List.of(LiveConnectTabScreen._cachedSelectedInterests);
      _currentUserLat = LiveConnectTabScreen._cachedUserLat;
      _currentUserLon = LiveConnectTabScreen._cachedUserLon;
      _connectionStatusCache.addAll(LiveConnectTabScreen._globalConnectionStatusCache);
      _requestStatusCache.addAll(LiveConnectTabScreen._globalRequestStatusCache);
      _connectionsLoaded = true;
      _isLoadingPeople = false;
      _applySearchFilter();
      // Silent background refresh
      _backgroundRefresh();
    } else {
      _loadUserProfile(); // First ever load with spinner
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    disposeVoiceSearch(); // From VoiceSearchMixin
    super.dispose();
  }

  /// Public method to refresh people list (called after profile creation)
  Future<void> refreshPeople() async {
    LiveConnectTabScreen._cachedTimestamp = null; // Force full refresh
    _connectionsLoaded = false;
    await _loadMyConnections();
    if (mounted) await _loadNearbyPeople();
  }

  /// Silently refresh data in background (no spinner).
  Future<void> _backgroundRefresh() async {
    // Skip if cache is very fresh (< 30 seconds)
    if (LiveConnectTabScreen._cachedTimestamp != null &&
        DateTime.now().difference(LiveConnectTabScreen._cachedTimestamp!) <
            const Duration(seconds: 30)) {
      return;
    }
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final results = await Future.wait([
        _firestore.collection('users').doc(userId).get(),
        _firestore.collection('networking_profiles').doc(userId).get(),
        _loadMyConnections(),
      ]);
      if (!mounted) return;

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final netDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (userDoc.exists) {
        _userProfile = userDoc.data();
        // Reject stale Mountain View from base user profile
        final baseCity = (_userProfile?['city'] as String? ?? '').toLowerCase();
        if (baseCity.contains('mountain view')) {
          _userProfile?.remove('latitude');
          _userProfile?.remove('longitude');
          _userProfile?.remove('city');
        }
        if (netDoc.exists) {
          final netData = netDoc.data() ?? {};
          _selectedInterests = List<String>.from(netData['interests'] ?? []);
          final netCity = (netData['city'] as String? ?? '').toLowerCase();
          final netLat = (netData['latitude'] as num?)?.toDouble();
          final netLng = (netData['longitude'] as num?)?.toDouble();
          final isStale = netCity.contains('mountain view') ||
              (netLat != null && netLng != null && netLat.abs() < 0.01 && netLng.abs() < 0.01);
          if (!isStale && _userProfile != null) {
            if (netData['city'] != null) _userProfile!['city'] = netData['city'];
            if (netLat != null) _userProfile!['latitude'] = netLat;
            if (netLng != null) _userProfile!['longitude'] = netLng;
          }
        }
        await _loadNearbyPeople(silent: true);
      }
    } catch (e) {
      debugPrint('LiveConnect: Background refresh error: $e');
    }
  }

  /// Load user's connections and pending request user IDs for filtering
  Future<void> _loadMyConnections() async {
    if (_connectionsLoaded) return; // Already loaded

    try {
      // Load connections + pending requests in parallel
      final results = await Future.wait([
        _connectionService.getUserConnections(),
        _connectionService.getPendingRequestUserIds(),
      ]);

      _myConnections = results[0];
      _pendingRequestUserIds = results[1];
      _connectionsLoaded = true;

      // Initialize connection status cache
      for (var userId in _myConnections) {
        _connectionStatusCache[userId] = true;
      }

      debugPrint(
        'LiveConnect: Loaded ${_myConnections.length} connections and ${_pendingRequestUserIds.length} pending requests for filtering',
      );
    } catch (e) {
      debugPrint('LiveConnect: Error loading connections: $e');
    }
  }

  /// Update connection status cache when connection status changes
  void updateConnectionCache(
    String userId,
    bool isConnected, {
    String? requestStatus,
  }) {
    if (!mounted) return;
    setState(() {
      _connectionStatusCache[userId] = isConnected;
      if (isConnected) {
        if (!_myConnections.contains(userId)) {
          _myConnections.add(userId);
        }
        // Remove from pending since now connected
        _pendingRequestUserIds.remove(userId);
      } else {
        _myConnections.remove(userId);
      }
      if (requestStatus == 'sent' || requestStatus == 'received') {
        // Add to pending list so they're filtered from discover
        if (!_pendingRequestUserIds.contains(userId)) {
          _pendingRequestUserIds.add(userId);
        }
      }
      if (requestStatus != null) {
        _requestStatusCache[userId] = requestStatus;
      }
      // Update static cache
      LiveConnectTabScreen._globalConnectionStatusCache[userId] = isConnected;
      if (requestStatus != null) {
        LiveConnectTabScreen._globalRequestStatusCache[userId] = requestStatus;
      }
      LiveConnectTabScreen._cachedMyConnections = List.of(_myConnections);
      LiveConnectTabScreen._cachedPendingRequestUserIds = List.of(_pendingRequestUserIds);
    });
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _isLoadingPeople = false; });
        return;
      }
      final userId = user.uid;

      // Ensure Firestore auth token is valid before querying
      await user.getIdToken(true);

      // Parallel fetch: user profile + networking profile + connections all at once
      final results = await Future.wait([
        _firestore.collection('users').doc(userId).get(),
        _firestore.collection('networking_profiles').doc(userId).get(),
        _loadMyConnections(), // returns void but runs in parallel
      ]);
      if (!mounted) return;

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final netDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (userDoc.exists) {
        _userProfile = userDoc.data();

        // Reject stale Mountain View from base user profile
        final baseCity = (_userProfile?['city'] as String? ?? '').toLowerCase();
        if (baseCity.contains('mountain view')) {
          _userProfile?.remove('latitude');
          _userProfile?.remove('longitude');
          _userProfile?.remove('city');
        }

        if (netDoc.exists) {
          final netData = netDoc.data() ?? {};
          _selectedInterests = List<String>.from(
            netData['interests'] ?? [],
          );
          // Merge networking profile city/location (skip stale Mountain View)
          final netCity = (netData['city'] as String? ?? '').toLowerCase();
          final netLat = (netData['latitude'] as num?)?.toDouble();
          final netLng = (netData['longitude'] as num?)?.toDouble();
          final isStale = netCity.contains('mountain view') ||
              (netLat != null && netLng != null && netLat.abs() < 0.01 && netLng.abs() < 0.01);
          if (!isStale && _userProfile != null) {
            if (netData['city'] != null) _userProfile!['city'] = netData['city'];
            if (netLat != null) _userProfile!['latitude'] = netLat;
            if (netLng != null) _userProfile!['longitude'] = netLng;
          }
        }

        if (mounted) {
          setState(() {}); // Single setState after all data is set
          _loadNearbyPeople();
        }
      } else {
        // User doc doesn't exist — stop loading
        if (mounted) setState(() { _isLoadingPeople = false; });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() { _isLoadingPeople = false; });
        // Don't show error snackbar for permission-denied (auth token race condition)
        if (!e.toString().contains('permission-denied')) {
          NetworkingHelpers.showErrorSnackBar(context, 'Failed to load profile. Please check your connection and try again.');
        }
      }
    }
  }

  /// Refresh GPS location in background without blocking UI.
  /// When done, silently reloads nearby people with updated distances.
  void _refreshLocationInBackground() {
    Future<void> doRefresh() async {
      try {
        // Priority 1: Fresh GPS via IpLocationService
        final result = await IpLocationService.detectLocation();
        if (result != null && mounted) {
          _currentUserLat = result['lat'] as double;
          _currentUserLon = result['lng'] as double;
          _lastLocationRefresh = DateTime.now();
          _isRefreshingLocation = false;
          // Silently reload with updated location for accurate distances
          _loadNearbyPeople(silent: true);
          return;
        }
      } catch (_) {}
      // Priority 2: Firestore user profile fallback
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users').doc(uid).get();
          if (userDoc.exists) {
            final lat = (userDoc.data()?['latitude'] as num?)?.toDouble();
            final lng = (userDoc.data()?['longitude'] as num?)?.toDouble();
            final city = (userDoc.data()?['city'] as String? ?? '').toLowerCase();
            if (lat != null && lng != null && mounted &&
                !city.contains('mountain view') &&
                !(lat.abs() < 0.01 && lng.abs() < 0.01)) {
              _currentUserLat = lat;
              _currentUserLon = lng;
              _lastLocationRefresh = DateTime.now();
              _isRefreshingLocation = false;
              _loadNearbyPeople(silent: true);
              return;
            }
          }
        }
      } catch (_) {}
      _isRefreshingLocation = false;
    }
    doRefresh();
  }

  Future<void> _loadNearbyPeople({
    bool loadMore = false,
    bool forceRefreshLocation = false,
    bool silent = false,
  }) async {
    if (!mounted) return;

    // If interest filter is on but no interests selected, return early
    if (_filterByInterests && _selectedInterests.isEmpty) return;

    // If already loading more or no more users, return
    if (loadMore && (_isLoadingMore || !_hasMoreUsers)) return;

    if (!mounted) return;
    if (silent) {
      // Silent mode: reset pagination but no spinner
      _lastDocument = null;
      _hasMoreUsers = true;
    } else {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          _isLoadingPeople = true;
          _lastDocument = null;
          _hasMoreUsers = true;
        }
      });
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        if (mounted) setState(() { _isLoadingPeople = false; _isLoadingMore = false; });
        return;
      }

      final userCity = _userProfile?['city'];

      // Use profile lat/lng immediately if no location yet (non-blocking)
      if (_currentUserLat == null || _currentUserLon == null) {
        final rawLat = _userProfile?['latitude'];
        final rawLon = _userProfile?['longitude'];
        final profileCity = (_userProfile?['city'] as String? ?? '').toLowerCase();
        final lat = rawLat is num ? rawLat.toDouble() : null;
        final lng = rawLon is num ? rawLon.toDouble() : null;
        if (lat != null && lng != null &&
            !profileCity.contains('mountain view') &&
            !(lat.abs() < 0.01 && lng.abs() < 0.01)) {
          _currentUserLat = lat;
          _currentUserLon = lng;
          _lastLocationRefresh = DateTime.now();
        }
      }

      // Check if we need to refresh location (cached for 90 seconds)
      final now = DateTime.now();
      final shouldRefreshLocation =
          forceRefreshLocation ||
          _lastLocationRefresh == null ||
          now.difference(_lastLocationRefresh!) > _locationCacheDuration;

      // Kick off GPS refresh in background (non-blocking — don't wait for it)
      if (shouldRefreshLocation && !_isRefreshingLocation) {
        _isRefreshingLocation = true;
        _refreshLocationInBackground();
      }

      // Build query based on filters - query networking_profiles (separate from main user profile)
      Query<Map<String, dynamic>> usersQuery = _firestore.collection('networking_profiles');

      // ALWAYS filter by discoveryModeEnabled to respect user privacy
      usersQuery = usersQuery.where('discoveryModeEnabled', isEqualTo: true);

      // Apply pagination
      if (loadMore && _lastDocument != null) {
        usersQuery = usersQuery.startAfterDocument(_lastDocument!);
      }

      // Calculate fetch size - need to over-fetch when in-memory filters are active
      int fetchSize = _pageSize;
      bool hasInMemoryFilters =
          (_locationFilter == 'Near me' || _locationFilter == 'City') ||
          (_filterByInterests && _selectedInterests.isNotEmpty) ||
          (_filterByGender && _selectedGenders.isNotEmpty) ||
          (_filterByConnectionTypes && _selectedConnectionTypes.isNotEmpty) ||
          (_filterByActivities && _selectedActivities.isNotEmpty) ||
          (_selectedNetworkingCategory != 'All') ||
          _categoryDropdownSelections.values.any((v) => v != null) ||
          (_ageRange.start > 18 || _ageRange.end < 60) ||
          _showOnlineOnly;

      if (hasInMemoryFilters) {
        fetchSize = _pageSize * 5; // Fetch 100 instead of 20
      }

      usersQuery = usersQuery.limit(fetchSize);

      final usersSnapshot = await usersQuery.get();

      final userLat = _currentUserLat;
      final userLon = _currentUserLon;

      // Pre-fetch online status from main users collection if needed
      // (networking_profiles may not have isOnline — batch query avoids N+1 reads)
      Set<String> onlineUserIds = {};
      if (_showOnlineOnly && usersSnapshot.docs.isNotEmpty) {
        final userIds = usersSnapshot.docs.map((d) => d.id).toList();
        // Firestore whereIn limit is 30, so chunk the IDs
        for (int c = 0; c < userIds.length; c += 30) {
          final chunk = userIds.sublist(c, c + 30 > userIds.length ? userIds.length : c + 30);
          try {
            final onlineSnap = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .where('isOnline', isEqualTo: true)
                .get();
            for (final doc in onlineSnap.docs) {
              onlineUserIds.add(doc.id);
            }
          } catch (_) {}
        }
      }

      List<Map<String, dynamic>> people = [];
      for (var doc in usersSnapshot.docs) {
        try {
          if (doc.id == userId) continue; // Skip current user

          // Skip users who are already connected (accepted connections)
          if (_myConnections.contains(doc.id)) {
            continue;
          }

          // Skip users who have pending requests (sent or received)
          if (_pendingRequestUserIds.contains(doc.id)) {
            continue;
          }

          final userData = doc.data();

          // Note: discoveryModeEnabled is now filtered at database level for better performance

          final userInterests = (userData['interests'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
          final otherUserCity = userData['city'];
          final rawOtherLat = userData['latitude'];
          final rawOtherLon = userData['longitude'];
          // Reject Mountain View / null-island from other user
          final otherCityRaw = (userData['city'] as String? ?? '').toLowerCase();
          final otherIsMV = otherCityRaw.contains('mountain view');
          final tmpOtherLat = rawOtherLat is num ? rawOtherLat.toDouble() : null;
          final tmpOtherLon = rawOtherLon is num ? rawOtherLon.toDouble() : null;
          final otherNI = tmpOtherLat != null && tmpOtherLon != null &&
              tmpOtherLat.abs() < 0.01 && tmpOtherLon.abs() < 0.01;
          final otherUserLat = (otherIsMV || otherNI) ? null : tmpOtherLat;
          final otherUserLon = (otherIsMV || otherNI) ? null : tmpOtherLon;

          // Calculate distance when both users have location data
          double? distance;
          if (userLat != null &&
              userLon != null &&
              otherUserLat != null &&
              otherUserLon != null) {
            distance = _calculateDistance(
              userLat,
              userLon,
              otherUserLat,
              otherUserLon,
            );
            if (distance > 10000) distance = null;
          }
          // Optimization: If location data is missing, distance stays null and won't be displayed

          // Apply location filtering based on _locationFilter
          if (_locationFilter == 'Near me') {
            if (userLat != null && userLon != null) {
              // Skip if other user has no distance data
              if (distance == null) continue;

              // Skip if user is outside the distance range
              if (distance < _distanceRange.start ||
                  distance > _distanceRange.end) {
                continue;
              }
            } else {
              // User has no location — can't calculate distance, skip profile
              continue;
            }
          } else if (_locationFilter == 'City') {
            // Additional city check for cases where query didn't filter
            if (userCity != null && userCity.isNotEmpty) {
              if (otherUserCity == null || otherUserCity != userCity) {
                continue; // Skip if not in same city
              }
            }
          } else if (_locationFilter == 'Smart ') {
            // Smart mode: only show users who have a networking profile
            final userNetCategory =
                userData['networkingCategory'] as String?;
            if (userNetCategory == null || userNetCategory.isEmpty) {
              continue;
            }
          }
          // 'Worldwide' has no location filtering

          // Smart tab always requires networking profile — even if Near me/City
          // filter was applied (which overrides _locationFilter from 'Smart ')
          if (_locationFilter != 'Smart ' && _tabController.index == 1) {
            final userNetCategory =
                userData['networkingCategory'] as String?;
            if (userNetCategory == null || userNetCategory.isEmpty) {
              continue;
            }
          }

          // Calculate common interests
          List<String> commonInterests = [];
          double matchScore =
              1.0; // Default match score when interest filter is off

          if (_filterByInterests && _selectedInterests.isNotEmpty) {
            commonInterests = _selectedInterests
                .where((interest) => userInterests.contains(interest))
                .toList();

            // Skip if no common interests when filter is on
            if (commonInterests.isEmpty) continue;

            matchScore = commonInterests.length / _selectedInterests.length;
          } else {
            // When interest filter is off, show all their interests as "common"
            commonInterests = userInterests;
          }

          // Gender filtering (all done in-memory to avoid composite index issues)
          if (_filterByGender && _selectedGenders.isNotEmpty) {
            final userGender = userData['gender'] as String?;

            // Skip if user has no gender or gender is not in selected genders
            if (userGender == null || !_selectedGenders.contains(userGender)) {
              continue;
            }
          }

          // Connection Types filtering
          if (_filterByConnectionTypes && _selectedConnectionTypes.isNotEmpty) {
            final userConnectionTypes = List<String>.from(
              userData['connectionTypes'] ?? [],
            );

            // Check if user has any of the selected connection types
            final hasMatchingType = _selectedConnectionTypes.any(
              (type) => userConnectionTypes.contains(type),
            );

            if (!hasMatchingType) continue;
          }

          // Activities filtering
          if (_filterByActivities && _selectedActivities.isNotEmpty) {
            final userActivities = List<String>.from(
              userData['activities'] ?? [],
            );

            // Check if user has any of the selected activities
            final hasMatchingActivity = _selectedActivities.any(
              (activity) => userActivities.contains(activity),
            );

            if (!hasMatchingActivity) continue;
          }

          // Networking category filtering
          if (_selectedNetworkingCategory != 'All') {
            final userNetworkingCategory =
                userData['networkingCategory'] as String?;
            final userSubcategory =
                userData['networkingSubcategory'] as String?;
            if (userNetworkingCategory == null ||
                userNetworkingCategory != _selectedNetworkingCategory) {
              continue;
            }
            // Also filter by subcategory if selected
            if (_selectedSubcategory != null) {
              if (userSubcategory == null ||
                  userSubcategory != _selectedSubcategory) {
                continue;
              }
            }
          }

          // Category-specific filter matching (e.g., Experience Level, Industry)
          if (_categoryDropdownSelections.values.any((v) => v != null)) {
            final rawCatFilters = userData['categoryFilters'];
            final userCategoryFilters = (rawCatFilters is Map) ? Map<String, dynamic>.from(rawCatFilters) : <String, dynamic>{};
            bool matchesCategoryFilters = true;
            for (final entry in _categoryDropdownSelections.entries) {
              if (entry.value != null) {
                final userValue = userCategoryFilters[entry.key] as String?;
                if (userValue == null || userValue != entry.value) {
                  matchesCategoryFilters = false;
                  break;
                }
              }
            }
            if (!matchesCategoryFilters) continue;
          }

          // Age range filtering
          if (_ageRange.start > 18 || _ageRange.end < 60) {
            final userAge = (userData['age'] as num?)?.toInt();
            if (userAge == null) {
              continue; // Exclude profiles without age when age filter is active
            }
            if (userAge < _ageRange.start.round() ||
                userAge > _ageRange.end.round()) {
              continue;
            }
          }

          // Online only filtering (uses pre-fetched batch data)
          if (_showOnlineOnly) {
            final isOnline = (userData['isOnline'] as bool? ?? false) || onlineUserIds.contains(doc.id);
            if (!isOnline) continue;
          }

          // Add user with match data
          people.add({
            'userId': doc.id,
            'userData': userData,
            'commonInterests': commonInterests,
            'matchScore': matchScore,
            'distance': distance, // Add distance for display
          });
        } catch (e) {
          // Skip user if there's an error processing their data
          debugPrint('Error processing user ${doc.id}: $e');
          continue;
        }
      }

      // Tag new profiles (not in previous cache) to surface them at top
      final cachedIds = LiveConnectTabScreen._cachedNearbyPeople
          .map((p) => p['userId'] as String)
          .toSet();
      for (final person in people) {
        person['_isNew'] = !cachedIds.contains(person['userId'] as String);
      }

      // Sort: new profiles first, then by distance, then by match score
      people.sort((a, b) {
        final aNew = a['_isNew'] as bool? ?? false;
        final bNew = b['_isNew'] as bool? ?? false;
        if (aNew && !bNew) return -1;
        if (!aNew && bNew) return 1;

        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;
        if (distA != null && distB != null) return distA.compareTo(distB);
        if (distA != null && distB == null) return -1;
        if (distA == null && distB != null) return 1;
        return (b['matchScore'] as double).compareTo(a['matchScore'] as double);
      });

      if (mounted) {
        setState(() {
          // Update pagination state
          if (usersSnapshot.docs.isNotEmpty) {
            _lastDocument = usersSnapshot.docs.last;
          }
          // Has more if we fetched the full fetch size
          // (not _pageSize, but the actual size we requested)
          _hasMoreUsers = usersSnapshot.docs.length >= fetchSize;

          // Limit final results to _pageSize even if we fetched more
          if (people.length > _pageSize) {
            people = people.sublist(0, _pageSize);
          }

          // Update people list (deduplicate by userId)
          if (loadMore) {
            final existingIds = _nearbyPeople.map((p) => p['userId'] as String).toSet();
            final uniqueNew = people.where((p) => !existingIds.contains(p['userId'] as String)).toList();
            _nearbyPeople.addAll(uniqueNew);
            _isLoadingMore = false;
          } else {
            // Deduplicate initial load as well
            final seen = <String>{};
            _nearbyPeople = people.where((p) {
              final id = p['userId'] as String;
              return seen.add(id);
            }).toList();
            if (!silent) _isLoadingPeople = false;
          }

          // Apply search filter if search query exists
          _applySearchFilter();

          // ── Persist to static cache (tied to current user) ──
          LiveConnectTabScreen._cachedUserId = FirebaseAuth.instance.currentUser?.uid;
          LiveConnectTabScreen._cachedNearbyPeople = List.of(_nearbyPeople);
          LiveConnectTabScreen._cachedUserProfile = _userProfile != null
              ? Map<String, dynamic>.from(_userProfile!)
              : null;
          LiveConnectTabScreen._cachedMyConnections = List.of(_myConnections);
          LiveConnectTabScreen._cachedPendingRequestUserIds = List.of(_pendingRequestUserIds);
          LiveConnectTabScreen._cachedSelectedInterests = List.of(_selectedInterests);
          LiveConnectTabScreen._cachedUserLat = _currentUserLat;
          LiveConnectTabScreen._cachedUserLon = _currentUserLon;
          LiveConnectTabScreen._globalConnectionStatusCache
            ..clear()
            ..addAll(_connectionStatusCache);
          LiveConnectTabScreen._globalRequestStatusCache
            ..clear()
            ..addAll(_requestStatusCache);
          LiveConnectTabScreen._hasEverLoaded = true;
          LiveConnectTabScreen._cachedTimestamp = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby people: $e');
      if (mounted) {
        setState(() {
          if (!silent) _isLoadingPeople = false;
          _isLoadingMore = false;
        });
        NetworkingHelpers.showErrorSnackBar(context, 'Failed to load nearby users. Please check your connection.');
      }
    }
  }

  // Filter people based on search query
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPeople = List.of(_nearbyPeople);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPeople = _nearbyPeople.where((person) {
        final userData = (person['userData'] is Map) ? person['userData'] as Map<String, dynamic> : <String, dynamic>{};
        final name = (userData['name'] ?? '').toString().toLowerCase();
        final rawInterests = userData['interests'];
        final interests = (rawInterests is List) ? rawInterests.map((e) => e.toString()).toList() : <String>[];

        // Search in name
        if (name.contains(query)) return true;

        // Search in interests
        for (final interest in interests) {
          if (interest.toLowerCase().contains(query)) return true;
        }

        // Search in city
        final city = (userData['city'] ?? '').toString().toLowerCase();
        if (city.contains(query)) return true;

        return false;
      }).toList();
    }
  }

  // Helper method to calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _updateInterests() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Only update interests if user already has a networking profile (prevent ghost profiles)
      final existingDoc = await _firestore.collection('networking_profiles').doc(userId).get();
      if (!existingDoc.exists) {
        if (mounted) {
          NetworkingHelpers.showErrorSnackBar(context, 'Please create a networking profile first.');
        }
        return;
      }
      await _firestore.collection('networking_profiles').doc(userId).update({
        'interests': _selectedInterests,
      });

      if (mounted) {
        NetworkingHelpers.showSuccessSnackBar(context, 'Interests updated successfully');
      }

      // Reload nearby people
      _loadNearbyPeople();
    } catch (e) {
      debugPrint('Error updating interests: $e');
      if (mounted) {
        NetworkingHelpers.showErrorSnackBar(context, 'Failed to save interests. Please try again.');
      }
    }
  }

  // ──────────────────── Generic Grid Picker ────────────────────
  Future<String?> _showGridPicker({
    required String title,
    required List<String> options,
    String? currentValue,
    Widget Function(String)? leadingBuilder,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                      GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = opt == currentValue;
                        final itemColor = NetworkingConstants.subcategoryColors[opt]
                            ?? NetworkingConstants.filterOptionColors[opt];
                        final itemIcon = NetworkingConstants.subcategoryIcons[opt]
                            ?? NetworkingConstants.filterOptionIcons[opt];
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? (itemColor != null
                                        ? [itemColor, itemColor.withValues(alpha: 0.7)]
                                        : [const Color(0xFF6366F1), const Color(0xFFA855F7)])
                                    : [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.15)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (itemColor ?? const Color(0xFF6366F1)).withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (itemColor ?? Colors.white).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : (itemColor ?? Colors.white).withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: leadingBuilder != null
                                      ? leadingBuilder(opt)
                                      : Icon(
                                          itemIcon ?? Icons.label_rounded,
                                          color: isSelected ? Colors.white : (itemColor ?? Colors.white),
                                          size: 20,
                                        ),
                                ),
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(opt, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Category Grid Picker ────────────────────
  Future<String?> _showCategoryGridPicker({String? currentValue}) {
    if (!mounted) return Future.value(null);
    final categories = NetworkingConstants.categorySubcategories.keys.toList();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Category', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                      GestureDetector(onTap: () => Navigator.pop(ctx), child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final catName = categories[index];
                        final icon = NetworkingConstants.categoryFlatIcons[catName] ?? Icons.hub_rounded;
                        final color = NetworkingConstants.getCategoryFlatColor(catName);
                        final colors = [color, color.withValues(alpha: 0.7)];
                        final isSelected = currentValue == catName;
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, catName),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected ? colors : [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.15)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? color.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.3), width: isSelected ? 1.5 : 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSelected ? Colors.white.withValues(alpha: 0.5) : color.withValues(alpha: 0.4), width: 1.2),
                                  ),
                                  child: Icon(icon, color: isSelected ? Colors.white : color, size: 20),
                                ),
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(catName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInterestsDialog() {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedInterests);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Interests', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _availableInterests[index];
                    final isSelected = tempSelected.contains(interest);

                    return CheckboxListTile(
                      title: Text(interest, style: const TextStyle(fontFamily: 'Poppins')),
                      value: isSelected,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(interest);
                          } else {
                            tempSelected.remove(interest);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests = tempSelected;
                    });
                    Navigator.pop(context);
                    _updateInterests();
                  },
                  child: const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showFilterDialog() {
    if (!mounted) return;

    // Save current filter state so Cancel/Back can restore it
    final savedCategory = _selectedNetworkingCategory;
    final savedSubcategory = _selectedSubcategory;
    final savedCategoryDropdowns = Map<String, String?>.from(_categoryDropdownSelections);
    final savedConnectionTypes = List<String>.from(_selectedConnectionTypes);
    final savedFilterByConnectionTypes = _filterByConnectionTypes;
    final savedActivities = List<String>.from(_selectedActivities);
    final savedFilterByActivities = _filterByActivities;
    final savedGenders = List<String>.from(_selectedGenders);
    final savedFilterByGender = _filterByGender;
    final savedAgeRange = _ageRange;
    final savedDistanceRange = _distanceRange;
    final savedLocationFilter = _locationFilter;
    final savedShowOnlineOnly = _showOnlineOnly;
    bool filtersApplied = false;

    void restoreFilterState() {
      if (filtersApplied) return; // Don't restore if Apply was pressed
      _selectedNetworkingCategory = savedCategory;
      _selectedSubcategory = savedSubcategory;
      _categoryDropdownSelections.clear();
      _categoryDropdownSelections.addAll(savedCategoryDropdowns);
      _selectedConnectionTypes.clear();
      _selectedConnectionTypes.addAll(savedConnectionTypes);
      _filterByConnectionTypes = savedFilterByConnectionTypes;
      _selectedActivities.clear();
      _selectedActivities.addAll(savedActivities);
      _filterByActivities = savedFilterByActivities;
      _selectedGenders.clear();
      _selectedGenders.addAll(savedGenders);
      _filterByGender = savedFilterByGender;
      _ageRange = savedAgeRange;
      _distanceRange = savedDistanceRange;
      _locationFilter = savedLocationFilter;
      _showOnlineOnly = savedShowOnlineOnly;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;

              return PopScope(
                onPopInvokedWithResult: (didPop, _) {
                  // Restore filters on system back button press
                  restoreFilterState();
                },
                child: Scaffold(
                backgroundColor: Colors.transparent,
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  centerTitle: true,
                  toolbarHeight: 56,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    onPressed: () {
                      restoreFilterState();
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Filter Options',
                    style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          _selectedNetworkingCategory = 'All';
                          _selectedSubcategory = null;
                          _categoryDropdownSelections.clear();
                          _selectedConnectionTypes.clear();
                          _filterByConnectionTypes = false;
                          _selectedActivities.clear();
                          _filterByActivities = false;
                          _selectedGenders.clear();
                          _filterByGender = false;
                          _ageRange = const RangeValues(18, 60);
                          _distanceRange = const RangeValues(1, 500);
                          _locationFilter = 'Near me';
                          _showOnlineOnly = false;
                        });
                      },
                      child: const Text(
                        'Reset All',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                ),
                body: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(64, 64, 64, 1),
                        Color.fromRGBO(0, 0, 0, 1),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Networking Categories Section
                                Row(
                                  children: [
                                    Text(
                                      'Categories',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedNetworkingCategory != 'All')
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedNetworkingCategory = 'All';
                                            _selectedSubcategory = null;
                                            _categoryDropdownSelections.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(fontFamily: 'Poppins', 
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Category Dropdown
                                GestureDetector(
                                  onTap: () async {
                                    final result = await _showCategoryGridPicker(
                                      currentValue: _selectedNetworkingCategory == 'All' ? null : _selectedNetworkingCategory,
                                    );
                                    if (result != null && mounted) {
                                      setDialogState(() {
                                        _selectedNetworkingCategory = result;
                                        _selectedSubcategory = null;
                                        _selectedConnectionTypes.clear();
                                        _filterByConnectionTypes = false;
                                        _selectedActivities.clear();
                                        _filterByActivities = false;
                                        _categoryDropdownSelections.clear();
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        if (_selectedNetworkingCategory != 'All') ...[
                                          Icon(
                                            NetworkingConstants.categoryFlatIcons[_selectedNetworkingCategory] ?? Icons.hub_rounded,
                                            color: NetworkingConstants.getCategoryFlatColor(_selectedNetworkingCategory),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                          child: Text(
                                            _selectedNetworkingCategory == 'All' ? 'Select Category' : _selectedNetworkingCategory,
                                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                                          ),
                                        ),
                                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),

                                // Subcategory Dropdown — shown when a category is selected
                                if (_selectedNetworkingCategory != 'All') ...[
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final color = NetworkingConstants.getCategoryFlatColor(_selectedNetworkingCategory);
                                      final subs =
                                          NetworkingConstants.categorySubcategories[_selectedNetworkingCategory] ?? <String>[];

                                      return GestureDetector(
                                        onTap: () async {
                                          final result = await _showGridPicker(
                                            title: 'Select Subcategory',
                                            options: subs,
                                            currentValue: _selectedSubcategory,
                                          );
                                          if (result != null) {
                                            setDialogState(() {
                                              _selectedSubcategory = result;
                                              _categoryDropdownSelections.clear();
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            children: [
                                              if (_selectedSubcategory != null) ...[
                                                Icon(
                                                  NetworkingConstants.subcategoryIcons[_selectedSubcategory] ?? Icons.label_rounded,
                                                  color: NetworkingConstants.subcategoryColors[_selectedSubcategory] ?? color,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  _selectedSubcategory ?? 'Select Subcategory',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: _selectedSubcategory != null
                                                        ? Colors.white
                                                        : Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                // ── Category-Specific Filters (dynamic) ──
                                if (_selectedNetworkingCategory != 'All')
                                  Builder(
                                    builder: (context) {
                                      final catColor =
                                          NetworkingConstants.getCategoryFlatColor(_selectedNetworkingCategory);
                                      // Collect filters: category-level + subcategory-level
                                      final filters = <Map<String, dynamic>>[
                                        ...(NetworkingConstants.categoryFilters[_selectedNetworkingCategory] ??
                                            []),
                                        if (_selectedSubcategory != null)
                                          ...(NetworkingConstants.subcategoryFilters[_selectedSubcategory] ??
                                              []),
                                      ];
                                      if (filters.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: filters.expand<Widget>((
                                          filter,
                                        ) {
                                          final label =
                                              filter['label'] as String? ?? '';
                                          final options = List<String>.from(
                                            (filter['options'] as List?) ?? [],
                                          );

                                          return [
                                            const SizedBox(height: 16),
                                            // Filter label
                                            Text(
                                              label,
                                              style: const TextStyle(fontFamily: 'Poppins', 
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                final result = await _showGridPicker(
                                                  title: 'Select $label',
                                                  options: options,
                                                  currentValue: _categoryDropdownSelections[label],
                                                );
                                                if (result != null) {
                                                  setDialogState(() => _categoryDropdownSelections[label] = result);
                                                }
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                                decoration: BoxDecoration(
                                                  color: catColor.withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    if (_categoryDropdownSelections[label] != null) ...[
                                                      Icon(
                                                        NetworkingConstants.filterOptionIcons[_categoryDropdownSelections[label]] ?? Icons.label_rounded,
                                                        color: NetworkingConstants.filterOptionColors[_categoryDropdownSelections[label]] ?? catColor,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 12),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        _categoryDropdownSelections[label] ?? 'Select $label',
                                                        style: TextStyle(
                                                          fontFamily: 'Poppins',
                                                          color: _categoryDropdownSelections[label] != null
                                                              ? Colors.white
                                                              : Colors.white.withValues(alpha: 0.5),
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ];
                                        }).toList(),
                                      );
                                    },
                                  ),

                                // ── Connection Types (Dropdown, only if relevant) ──
                                if (_selectedNetworkingCategory == 'All' ||
                                    (NetworkingConstants.categoryConnectionGroups[_selectedNetworkingCategory] ??
                                            [])
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Connection Types',
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_selectedConnectionTypes.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              _selectedConnectionTypes.clear();
                                              _filterByConnectionTypes = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final relevantGroups =
                                          _selectedNetworkingCategory == 'All'
                                          ? _connectionTypeGroups
                                          : Map.fromEntries(
                                              (NetworkingConstants.categoryConnectionGroups[_selectedNetworkingCategory] ??
                                                      _connectionTypeGroups.keys
                                                          .toList())
                                                  .where(
                                                    (key) =>
                                                        _connectionTypeGroups
                                                            .containsKey(key),
                                                  )
                                                  .map(
                                                    (key) => MapEntry(
                                                      key,
                                                      _connectionTypeGroups[key]!,
                                                    ),
                                                  ),
                                            );
                                      final allTypes = <String>[];
                                      for (final group
                                          in relevantGroups.entries) {
                                        for (final type in group.value) {
                                          allTypes.add(type);
                                        }
                                      }
                                      return GestureDetector(
                                        onTap: () async {
                                          final result = await _showGridPicker(
                                            title: 'Select Connection Type',
                                            options: allTypes,
                                            currentValue: _selectedConnectionTypes.isNotEmpty ? _selectedConnectionTypes.first : null,
                                          );
                                          if (result != null) {
                                            setDialogState(() {
                                              _selectedConnectionTypes.clear();
                                              _selectedConnectionTypes.add(result);
                                              _filterByConnectionTypes = true;
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            children: [
                                              if (_selectedConnectionTypes.isNotEmpty) ...[
                                                Icon(
                                                  NetworkingConstants.filterOptionIcons[_selectedConnectionTypes.first] ?? Icons.link_rounded,
                                                  color: NetworkingConstants.filterOptionColors[_selectedConnectionTypes.first] ?? const Color(0xFF6366F1),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  _selectedConnectionTypes.isNotEmpty ? _selectedConnectionTypes.first : 'Select Connection Type',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: _selectedConnectionTypes.isNotEmpty
                                                        ? Colors.white
                                                        : Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                // ── Activities (Dropdown, only if relevant for selected category) ──
                                if (_selectedNetworkingCategory == 'All' ||
                                    (NetworkingConstants.categoryActivityGroups[_selectedNetworkingCategory] ??
                                            [])
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Activities',
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_selectedActivities.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              _selectedActivities.clear();
                                              _filterByActivities = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final relevantGroups =
                                          _selectedNetworkingCategory == 'All'
                                          ? _activityGroups
                                          : Map.fromEntries(
                                              (NetworkingConstants.categoryActivityGroups[_selectedNetworkingCategory] ??
                                                      _activityGroups.keys
                                                          .toList())
                                                  .where(
                                                    (key) => _activityGroups
                                                        .containsKey(key),
                                                  )
                                                  .map(
                                                    (key) => MapEntry(
                                                      key,
                                                      _activityGroups[key]!,
                                                    ),
                                                  ),
                                            );
                                      final allActivities = <String>[];
                                      for (final group
                                          in relevantGroups.entries) {
                                        for (final activity in group.value) {
                                          allActivities.add(activity);
                                        }
                                      }
                                      return GestureDetector(
                                        onTap: () async {
                                          final result = await _showGridPicker(
                                            title: 'Select Activity',
                                            options: allActivities,
                                            currentValue: _selectedActivities.isNotEmpty ? _selectedActivities.first : null,
                                          );
                                          if (result != null) {
                                            setDialogState(() {
                                              _selectedActivities.clear();
                                              _selectedActivities.add(result);
                                              _filterByActivities = true;
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            children: [
                                              if (_selectedActivities.isNotEmpty) ...[
                                                Icon(
                                                  NetworkingConstants.filterOptionIcons[_selectedActivities.first] ?? Icons.sports_esports_rounded,
                                                  color: NetworkingConstants.filterOptionColors[_selectedActivities.first] ?? const Color(0xFF6366F1),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  _selectedActivities.isNotEmpty ? _selectedActivities.first : 'Select Activity',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: _selectedActivities.isNotEmpty
                                                        ? Colors.white
                                                        : Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // ── Gender Filter (Dropdown) ──
                                Row(
                                  children: [
                                    Text(
                                      'Gender',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedGenders.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedGenders.clear();
                                            _filterByGender = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(fontFamily: 'Poppins', 
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    final result = await _showGridPicker(
                                      title: 'Select Gender',
                                      options: const ['Male', 'Female', 'Non-binary', 'Other'],
                                      currentValue: _selectedGenders.isNotEmpty ? _selectedGenders.first : null,
                                      leadingBuilder: (gender) {
                                        final genderColor = gender == 'Male'
                                            ? const Color(0xFF42A5F5)
                                            : gender == 'Female'
                                                ? const Color(0xFFFF6B9D)
                                                : const Color(0xFFAB47BC);
                                        return Icon(
                                          gender == 'Male' ? Icons.male : gender == 'Female' ? Icons.female : Icons.transgender,
                                          color: genderColor, size: 20,
                                        );
                                      },
                                    );
                                    if (result != null) {
                                      setDialogState(() {
                                        _selectedGenders.clear();
                                        _selectedGenders.add(result);
                                        _filterByGender = true;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        if (_selectedGenders.isNotEmpty) ...[
                                          Icon(
                                            _selectedGenders.first == 'Male' ? Icons.male : _selectedGenders.first == 'Female' ? Icons.female : Icons.transgender,
                                            color: _selectedGenders.first == 'Male'
                                                ? const Color(0xFF42A5F5)
                                                : _selectedGenders.first == 'Female'
                                                    ? const Color(0xFFFF6B9D)
                                                    : const Color(0xFFAB47BC),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                          child: Text(
                                            _selectedGenders.isNotEmpty ? _selectedGenders.first : 'Select Gender',
                                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                                          ),
                                        ),
                                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── Age Range (Dropdowns) ──
                                Row(
                                  children: [
                                    Text(
                                      'Age Range',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    RangeValues tempAge = _ageRange;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => StatefulBuilder(
                                        builder: (ctx, setSliderState) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF2A2A2A,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          title: const Text(
                                            'Age Range',
                                            style: TextStyle(fontFamily: 'Poppins', 
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${tempAge.start.round()} - ${tempAge.end.round() == 60 ? "60+" : tempAge.end.round()}',
                                                style: const TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  activeTrackColor:
                                                      Colors.white,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.2),
                                                  thumbColor: Colors.white,
                                                  overlayColor: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  rangeThumbShape:
                                                      const RoundRangeSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                ),
                                                child: RangeSlider(
                                                  values: tempAge,
                                                  min: 18,
                                                  max: 60,
                                                  divisions: 42,
                                                  onChanged: (values) {
                                                    setSliderState(() {
                                                      tempAge = values;
                                                    });
                                                  },
                                                ),
                                              ),
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '18',
                                                    style: TextStyle(fontFamily: 'Poppins', 
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    '60+',
                                                    style: TextStyle(fontFamily: 'Poppins', 
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setDialogState(() {
                                                  _ageRange = tempAge;
                                                });
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_ageRange.start.round()} - ${_ageRange.end.round() == 60 ? "60+" : _ageRange.end.round()}',
                                            style: const TextStyle(fontFamily: 'Poppins', 
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── Location (Distance Dropdowns) ──
                                Row(
                                  children: [
                                    Text(
                                      'Location',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    RangeValues tempDist = _distanceRange;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => StatefulBuilder(
                                        builder: (ctx, setSliderState) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF2A2A2A,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          title: const Text(
                                            'Location Range',
                                            style: TextStyle(fontFamily: 'Poppins', 
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${tempDist.start.round()} km - ${tempDist.end.round() == 500 ? "500+" : "${tempDist.end.round()}"} km',
                                                style: const TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  activeTrackColor:
                                                      Colors.white,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.2),
                                                  thumbColor: Colors.white,
                                                  overlayColor: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  rangeThumbShape:
                                                      const RoundRangeSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                ),
                                                child: RangeSlider(
                                                  values: tempDist,
                                                  min: 1,
                                                  max: 500,
                                                  divisions: 499,
                                                  onChanged: (values) {
                                                    setSliderState(() {
                                                      tempDist = values;
                                                    });
                                                  },
                                                ),
                                              ),
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '1 km',
                                                    style: TextStyle(fontFamily: 'Poppins', 
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    '500+ km',
                                                    style: TextStyle(fontFamily: 'Poppins', 
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setDialogState(() {
                                                  _distanceRange = tempDist;
                                                  _locationFilter = 'Near me';
                                                });
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_distanceRange.start.round()} km - ${_distanceRange.end.round() == 500 ? "500+" : "${_distanceRange.end.round()}"} km',
                                            style: const TextStyle(fontFamily: 'Poppins', 
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── Show Online Only ──
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _showOnlineOnly
                                              ? const Color(0xFF00E676)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                          boxShadow: _showOnlineOnly
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF00E676,
                                                    ).withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Show Online Only',
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 24,
                                        width: 40,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: Switch(
                                            value: _showOnlineOnly,
                                            onChanged: (value) {
                                              setDialogState(() {
                                                _showOnlineOnly = value;
                                              });
                                            },
                                            activeTrackColor: const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.5),
                                            activeThumbColor: const Color(
                                              0xFF00E676,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Action Buttons
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    restoreFilterState();
                                    Navigator.pop(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF016CFF),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF016CFF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    filtersApplied = true;
                                    Navigator.pop(context);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {});
                                          _loadNearbyPeople();
                                        });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF016CFF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Apply Filters',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              );
            },
          );
        },
      ),
    );
  }

  /// Check if user is truly online based on lastSeen timestamp
  /// User is considered online only if lastSeen is within last 5 minutes
  void _showProfileDetail(ExtendedUserProfile user) async {
    // Check connection status before navigating (with error handling)
    String? connectionStatus;
    bool isConnected = false;

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        connectionStatus = await _connectionService
            .getConnectionRequestStatus(user.uid);
        isConnected = await _connectionService.areUsersConnected(
          currentUserId,
          user.uid,
        );
      }
    } catch (e) {
      debugPrint('Error checking connection status: $e');
    }

    if (!mounted) return;

    final displayStatus = isConnected
        ? 'connected'
        : connectionStatus; // 'sent', 'received', or null

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileDetailScreen(
            user: user,
            connectionStatus: displayStatus,
            selectedCategory: _selectedNetworkingCategory != 'All'
                ? _selectedNetworkingCategory
                : null,
            selectedSubcategory: _selectedSubcategory,
            onConnect: isConnected || connectionStatus == 'sent'
                ? null
                : () async {
                    // OPTIMISTIC UPDATE: Immediately show "Request Sent" in UI
                    updateConnectionCache(
                      user.uid,
                      false,
                      requestStatus: 'sent',
                    );

                    // Send real connection request in background
                    final result = await _connectionService
                        .sendConnectionRequest(receiverId: user.uid);

                    if (!mounted) return;

                    if (result['success'] == true) {
                      NetworkingHelpers.showSuccessSnackBar(this.context, 'Connection request sent!');
                    } else {
                      // Request failed - revert optimistic update
                      updateConnectionCache(
                        user.uid,
                        false,
                        requestStatus: null,
                      );
                      NetworkingHelpers.showErrorSnackBar(this.context, result['message'] ?? 'Failed to send request');
                    }
                  },
          ),
        ),
      ).then((_) {
        // Refresh connections and people list when returning from profile detail
        // (handles disconnect, accept, etc.)
        if (mounted) {
          refreshPeople();
        }
      });
    } catch (e) {
      debugPrint('Error opening profile detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final isGlass = themeState.isGlassmorphism;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildContent(isDarkMode, isGlass),
    );
  }

  Widget _buildContent(bool isDarkMode, bool isGlass) {
    // Show empty state only if interest filter is on AND no interests selected
    if (_filterByInterests && _selectedInterests.isEmpty) {
      return Align(
        alignment: const Alignment(0, -0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Connect with People',
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Select your interests to find people with similar interests, or disable the interest filter to see everyone',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showInterestsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Select Interests'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isLoadingPeople) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredPeople.isEmpty &&
        _nearbyPeople.isNotEmpty &&
        _searchQuery.isNotEmpty) {
      // Show search-specific empty state
      return RefreshIndicator(
        onRefresh: () async {
          await _loadNearbyPeople();
        },
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Align(
              alignment: const Alignment(0, -0.3),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No results found',
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try adjusting your search term',
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 15,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _applySearchFilter();
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isRefreshingLocation
                              ? null
                              : () async {
                                  await _loadNearbyPeople(
                                    forceRefreshLocation: true,
                                  );
                                },
                          icon: _isRefreshingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _isRefreshingLocation ? 'Refreshing...' : 'Refresh',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final List<_MosaicCardData> allCards = [];

    for (int i = 0; i < _filteredPeople.length; i++) {
      final person = _filteredPeople[i];
      final userData = (person['userData'] is Map) ? person['userData'] as Map<String, dynamic> : <String, dynamic>{};
      final userId = (person['userId'] ?? '').toString();
      final distance = person['distance'] as double?;

      final extendedProfile = ExtendedUserProfile.fromMap(userData, userId);
      final profileWithDistance = extendedProfile.copyWith(distance: distance);

      allCards.add(
        _MosaicCardData(
          profile: profileWithDistance,
          userName: userData['name'] ?? 'Unknown',
          userId: userId,
        ),
      );
    }

    // Colorful cards — every 3rd card shows in full color
    bool isColorCard(int index) => index % 3 == 0;

    Widget buildCardAt(int index) {
      final card = allCards[index];
      const double cardHeight = 145.0;

      final profile = card.profile;
      final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(profile.photoUrl);

      return _buildMosaicCard(
        userName: profile.name.isNotEmpty ? profile.name : 'Unknown',
        imageUrl: fixedPhotoUrl,
        isCenter: isColorCard(index),
        height: cardHeight,
        animationIndex: index,
        onTap: () => _showProfileDetail(profile),
        userId: card.userId,
        age: profile.age,
        profession: profile.occupation ?? profile.category,
        distance: profile.distance,
        isOnline: profile.isOnline,
        networkingCategory: profile.networkingCategory,
      );
    }

    // Build active filter chips
    final bool hasActiveFilters =
        _selectedNetworkingCategory != 'All' ||
        _selectedGenders.isNotEmpty ||
        (_ageRange.start > 18 || _ageRange.end < 60) ||
        _selectedConnectionTypes.isNotEmpty ||
        _selectedActivities.isNotEmpty ||
        _showOnlineOnly ||
        (_locationFilter != 'Worldwide' && _locationFilter != 'Smart ');

    return Column(
      children: [
        // Active filter chips bar
        if (hasActiveFilters)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (_selectedNetworkingCategory != 'All') ...[
                    _buildFilterChip(
                      label: _selectedSubcategory != null
                          ? '$_selectedNetworkingCategory > $_selectedSubcategory'
                          : _selectedNetworkingCategory,
                      color:
                          NetworkingConstants.getCategoryFlatColor(_selectedNetworkingCategory),
                      onRemove: () {
                        setState(() {
                          _selectedNetworkingCategory = 'All';
                          _selectedSubcategory = null;
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_locationFilter != 'Worldwide' && _locationFilter != 'Smart ') ...[
                    _buildFilterChip(
                      label: _locationFilter == 'Near me'
                          ? 'Near me (${_distanceRange.start.round()}-${_distanceRange.end.round()} km)'
                          : _locationFilter,
                      color: const Color(0xFF00D67D),
                      onRemove: () {
                        setState(() {
                          _locationFilter = 'Worldwide';
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Each gender as separate chip
                  ..._selectedGenders.toList().map(
                    (gender) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: gender,
                        color: const Color(0xFFFF6B9D),
                        onRemove: () {
                          setState(() {
                            _selectedGenders.remove(gender);
                            if (_selectedGenders.isEmpty) {
                              _filterByGender = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  if (_ageRange.start > 18 || _ageRange.end < 60) ...[
                    _buildFilterChip(
                      label:
                          'Age ${_ageRange.start.round()}-${_ageRange.end.round() == 60 ? "60+" : "${_ageRange.end.round()}"}',
                      color: const Color(0xFFFFB74D),
                      onRemove: () {
                        setState(() {
                          _ageRange = const RangeValues(18, 60);
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Each connection type as separate chip
                  ..._selectedConnectionTypes.toList().map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: type,
                        color: const Color(0xFF7C4DFF),
                        onRemove: () {
                          setState(() {
                            _selectedConnectionTypes.remove(type);
                            if (_selectedConnectionTypes.isEmpty) {
                              _filterByConnectionTypes = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  // Each activity as separate chip
                  ..._selectedActivities.toList().map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: activity,
                        color: const Color(0xFF26C6DA),
                        onRemove: () {
                          setState(() {
                            _selectedActivities.remove(activity);
                            if (_selectedActivities.isEmpty) {
                              _filterByActivities = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  if (_showOnlineOnly) ...[
                    _buildFilterChip(
                      label: 'Online',
                      color: const Color(0xFF00E676),
                      onRemove: () {
                        setState(() {
                          _showOnlineOnly = false;
                        });
                        _loadNearbyPeople();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        // People grid — 2 cards per row
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadNearbyPeople(forceRefreshLocation: true);
            },
            color: const Color(0xFF00D67D),
            child: allCards.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              'No people found nearby',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pull down to refresh',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 90),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: allCards.length,
                    itemBuilder: (context, index) => buildCardAt(index),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }



  /// Stylish mosaic card with glassmorphism info overlay
  Widget _buildMosaicCard({
    required String userName,
    required String? imageUrl,
    required bool isCenter,
    required VoidCallback onTap,
    required double height,
    int animationIndex = 0,
    String? userId,
    int? age,
    String? profession,
    double? distance,
    bool isOnline = false,
    String? networkingCategory,
  }) {
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final gradientColors = NetworkingHelpers.getAvatarGradient(userName);
    final firstName = userName.split(' ').first;

    // Gradient background for placeholder / behind transparent images
    final bgGradient = BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    final placeholderWidget = Container(
      decoration: bgGradient,
      child: Center(
        child: Text(
          userInitial,
          style: const TextStyle(fontFamily: 'Poppins', 
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    // Build the image widget
    final bool isAssetImage =
        imageUrl != null && imageUrl.startsWith('assets/');
    final bool isGooglePhoto =
        imageUrl != null && imageUrl.contains('googleusercontent.com');
    Widget imageWidget;
    if (isAssetImage) {
      imageWidget = SizedBox.expand(
        child: Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Asset load error: $error');
            return placeholderWidget;
          },
        ),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => placeholderWidget,
        errorWidget: (context, url, error) {
          if (error.toString().contains('429')) {
            PhotoUrlHelper.markAsRateLimited(url);
          }
          return placeholderWidget;
        },
        // imageBuilder forces the image to fill the entire card
        imageBuilder: (context, imageProvider) {
          final child = SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            ),
          );
          // Google photos are circular PNGs — scale 1.5x so circle fills rectangle
          if (isGooglePhoto) {
            return ClipRect(child: Transform.scale(scale: 1.5, child: child));
          }
          return child;
        },
      );
    } else {
      imageWidget = placeholderWidget;
    }

    return FloatingCard(
      animationIndex: animationIndex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            if (isCenter)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image fills entire card
              Positioned.fill(
                child: imageWidget,
              ),

              // Networking category badge at top-left (auto-sizes with text)
              if (networkingCategory != null && networkingCategory.isNotEmpty)
                Positioned(
                  top: 6,
                  left: 6,
                  child: NetworkingWidgets.glassBadge(networkingCategory),
                ),

              // Glassmorphism info card at bottom
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                          // Name + age row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  age != null ? '$firstName, $age' : firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // Online dot
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF00E676)
                                      : Colors.grey.shade500,
                                  shape: BoxShape.circle,
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          // Profession only
                          if (profession != null && profession.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                profession,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          // Distance
                          if (distance != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    distance < 1
                                        ? '${(distance * 1000).toInt()} m'
                                        : '${distance.toStringAsFixed(1)} km',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Subtle top-right shine for color cards
              if (isCenter)
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
