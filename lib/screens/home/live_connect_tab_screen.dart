import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/config/app_colors.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../widgets/app_background.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../mixins/voice_search_mixin.dart';
import '../chat/enhanced_chat_screen.dart';
import '../../models/user_profile.dart';
import '../../models/extended_user_profile.dart';
import '../../widgets/profile widgets/profile_detail_bottom_sheet.dart';
import '../../services/connection_service.dart';
import '../../services/location services/location_service.dart';

class LiveConnectTabScreen extends ConsumerStatefulWidget {
  final bool activateNearMeFilter; // Flag to activate "Near Me" filter on init
  final bool
  activateNetworkingFilter; // Flag to activate professional/networking filters on init

  const LiveConnectTabScreen({
    super.key,
    this.activateNearMeFilter = false,
    this.activateNetworkingFilter = false,
  });

  @override
  ConsumerState<LiveConnectTabScreen> createState() =>
      _LiveConnectTabScreenState();
}

class _LiveConnectTabScreenState extends ConsumerState<LiveConnectTabScreen>
    with SingleTickerProviderStateMixin, VoiceSearchMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionService _connectionService = ConnectionService();
  final LocationService _locationService = LocationService();

  Map<String, dynamic>? _userProfile;
  List<String> _selectedInterests = [];
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  List<Map<String, dynamic>> _filteredPeople = []; // For search results
  bool _isLoadingPeople = false;
  String _searchQuery = ''; // Search query
  final TextEditingController _searchController = TextEditingController();

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
  double _distanceFilter = 50.0; // Distance in km
  String _locationFilter =
      'Worldwide'; // 'Near me', 'City', 'Country', 'Worldwide'
  final List<String> _selectedGenders = [];

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
  bool _connectionsLoaded = false;

  // Available genders
  final List<String> _availableGenders = ['Male', 'Female', 'Other'];

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
      'Collaboration',
    ],
    'Activities': [
      'Workout Partner',
      'Sports Partner',
      'Hobby Partner',
      'Event Companion',
      'Study Group',
    ],
    'Learning': [
      'Language Exchange',
      'Skill Sharing',
      'Book Club',
      'Learning Partner',
      'Creative Workshop',
    ],
    'Creative': [
      'Music Jam',
      'Art Collaboration',
      'Photography',
      'Content Creation',
      'Performance',
    ],
    'Other': [
      'Roommate',
      'Pet Playdate',
      'Community Service',
      'Gaming',
      'Online Friends',
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
  final List<String> _tabCategories = ['Discover Connect', 'Smart Connect'];

  @override
  void initState() {
    super.initState();

    // Initialize speech from VoiceSearchMixin
    initSpeech();

    // Initialize TabController
    _tabController = TabController(length: _tabCategories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
        final selectedCategory = _tabCategories[_tabController.index];
        setState(() {
          if (selectedCategory == 'Discover Connect') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Worldwide';
          } else if (selectedCategory == 'Smart Connect') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Smart Connect';
          } else {
            _filterByInterests = true;
            _locationFilter = 'Smart Connect';
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

    // Activate networking/professional filters if requested
    if (widget.activateNetworkingFilter) {
      _filterByConnectionTypes = true;
      _selectedConnectionTypes.addAll([
        'Networking',
        'Mentorship',
        'Business Partner',
        'Career Advice',
        'Collaboration',
      ]);
    }

    // Initialize expanded state for all groups (all collapsed by default)
    for (var groupName in _connectionTypeGroups.keys) {
      _expandedConnectionGroups[groupName] = false;
    }
    for (var groupName in _activityGroups.keys) {
      _expandedActivityGroups[groupName] = false;
    }
    _loadMyConnections(); // Load connections for caching
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    disposeVoiceSearch(); // From VoiceSearchMixin
    super.dispose();
  }

  void _startVoiceSearch() {
    startVoiceSearch((recognizedText) {
      // Update search controller text and move cursor to end
      _searchController.text = recognizedText;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );

      // Force rebuild to apply filter
      setState(() {
        _searchQuery = recognizedText;
        _applySearchFilter();
      });
    });
  }

  void _stopVoiceSearch() {
    stopVoiceSearch(); // From VoiceSearchMixin
  }

  /// Load user's connections list once for caching
  Future<void> _loadMyConnections() async {
    if (_connectionsLoaded) return; // Already loaded

    try {
      _myConnections = await _connectionService.getUserConnections();
      _connectionsLoaded = true;

      // Initialize connection status cache
      for (var userId in _myConnections) {
        _connectionStatusCache[userId] = true;
      }

      debugPrint(
        'LiveConnect: Loaded ${_myConnections.length} connections for caching',
      );
    } catch (e) {
      debugPrint('LiveConnect: Error loading connections: $e');
    }
  }

  /// Update connection status cache when connection status changes
  void _updateConnectionCache(
    String userId,
    bool isConnected, {
    String? requestStatus,
  }) {
    setState(() {
      _connectionStatusCache[userId] = isConnected;
      if (isConnected) {
        if (!_myConnections.contains(userId)) {
          _myConnections.add(userId);
        }
      } else {
        _myConnections.remove(userId);
      }
      if (requestStatus != null) {
        _requestStatusCache[userId] = requestStatus;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userProfile = userData;
          // Load user's saved interests
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
        });

        // Always load nearby people (filters can be applied via filter dialog)
        _loadNearbyPeople();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load profile. Please check your connection and try again.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadUserProfile();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadNearbyPeople({
    bool loadMore = false,
    bool forceRefreshLocation = false,
  }) async {
    if (!mounted) return;

    // If interest filter is on but no interests selected, return early
    if (_filterByInterests && _selectedInterests.isEmpty) return;

    // If already loading more or no more users, return
    if (loadMore && (_isLoadingMore || !_hasMoreUsers)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoadingPeople = true;
        // Reset pagination state for initial load
        _lastDocument = null;
        _hasMoreUsers = true;
      }
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userCity = _userProfile?['city'];

      // Check if we need to refresh location (cached for 90 seconds)
      final now = DateTime.now();
      final shouldRefreshLocation =
          forceRefreshLocation ||
          _currentUserLat == null ||
          _currentUserLon == null ||
          _lastLocationRefresh == null ||
          now.difference(_lastLocationRefresh!) > _locationCacheDuration;

      if (shouldRefreshLocation && !_isRefreshingLocation) {
        if (mounted) {
          setState(() {
            _isRefreshingLocation = true;
          });
        }
        debugPrint(
          'LiveConnect: Refreshing location (cache expired or forced)...',
        );

        final position = await _locationService.getCurrentLocation(
          silent: true,
        );

        if (position != null && mounted) {
          setState(() {
            _currentUserLat = position.latitude;
            _currentUserLon = position.longitude;
            _lastLocationRefresh = now;
            _isRefreshingLocation = false;
          });
          debugPrint(
            'LiveConnect: Location refreshed: ${position.latitude}, ${position.longitude}',
          );
        } else {
          if (_currentUserLat == null || _currentUserLon == null) {
            // Fall back to profile location only if we have no cached location
            _currentUserLat = _userProfile?['latitude']?.toDouble();
            _currentUserLon = _userProfile?['longitude']?.toDouble();
            if (_currentUserLat != null && _currentUserLon != null) {
              _lastLocationRefresh = now;
            }
            debugPrint(
              'LiveConnect: Using profile location (real-time unavailable)',
            );
          }
          if (mounted) {
            setState(() {
              _isRefreshingLocation = false;
            });
          }
        }
      } else {
        debugPrint(
          'LiveConnect: Using cached location (${_lastLocationRefresh != null ? now.difference(_lastLocationRefresh!).inSeconds : 0}s old)',
        );
      }

      final userLat = _currentUserLat;
      final userLon = _currentUserLon;

      // Build query based on filters - USE INDEXES FOR BETTER PERFORMANCE
      Query<Map<String, dynamic>> usersQuery = _firestore.collection('users');

      // ALWAYS filter by discoveryModeEnabled to respect user privacy
      usersQuery = usersQuery.where('discoveryModeEnabled', isEqualTo: true);

      // Apply city filter if 'City' location filter is selected
      // This uses the composite index: discoveryModeEnabled + city
      if (_locationFilter == 'City' &&
          userCity != null &&
          userCity.isNotEmpty) {
        usersQuery = usersQuery.where('city', isEqualTo: userCity);
      }

      // Apply gender filter at database level when enabled
      // This uses the composite index: discoveryModeEnabled + city + gender OR discoveryModeEnabled + gender
      if (_filterByGender && _selectedGenders.length == 1) {
        // Only apply single-gender filter at DB level (arrayContainsAny doesn't work for equality)
        usersQuery = usersQuery.where(
          'gender',
          isEqualTo: _selectedGenders.first,
        );
      }

      // Apply pagination
      if (loadMore && _lastDocument != null) {
        usersQuery = usersQuery.startAfterDocument(_lastDocument!);
      }

      // Calculate fetch size - need to over-fetch when in-memory filters are active
      // to account for documents that will be filtered out
      int fetchSize = _pageSize;
      bool hasInMemoryFilters = false;

      // Check if we have in-memory filters that might reduce results
      if (_locationFilter == 'Near me') {
        hasInMemoryFilters = true; // Distance filtering
      }
      if (_filterByInterests && _selectedInterests.isNotEmpty) {
        hasInMemoryFilters = true;
      }
      if (_filterByGender && _selectedGenders.length > 1) {
        hasInMemoryFilters = true; // Multi-gender
      }
      if (_filterByConnectionTypes && _selectedConnectionTypes.isNotEmpty) {
        hasInMemoryFilters = true;
      }
      if (_filterByActivities && _selectedActivities.isNotEmpty) {
        hasInMemoryFilters = true;
      }

      // Over-fetch by 3x when in-memory filters are active to ensure we get enough results
      if (hasInMemoryFilters) {
        fetchSize = _pageSize * 3; // Fetch 60 instead of 20
      }

      usersQuery = usersQuery.limit(fetchSize);
      final usersSnapshot = await usersQuery.get();

      List<Map<String, dynamic>> people = [];
      for (var doc in usersSnapshot.docs) {
        try {
          if (doc.id == userId) continue; // Skip current user

          final userData = doc.data();

          // Note: discoveryModeEnabled is now filtered at database level for better performance

          final userInterests = List<String>.from(userData['interests'] ?? []);
          final otherUserCity = userData['city'];
          final otherUserLat = userData['latitude']?.toDouble();
          final otherUserLon = userData['longitude']?.toDouble();

          // Calculate distance when both users have location data
          // (for filtering with "Near me" and for displaying on cards)
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
          }
          // Optimization: If location data is missing, distance stays null and won't be displayed

          // Apply location filtering based on _locationFilter
          if (_locationFilter == 'Near me') {
            // Skip if no distance data
            if (distance == null) continue;

            // Skip if user is beyond the distance filter
            if (distance > _distanceFilter) continue;
          } else if (_locationFilter == 'City') {
            // Additional city check for cases where query didn't filter
            if (userCity != null && userCity.isNotEmpty) {
              if (otherUserCity == null || otherUserCity != userCity) {
                continue; // Skip if not in same city
              }
            }
          }
          // 'Worldwide' has no location filtering

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

          // Gender filtering (only needed for multiple genders - single gender filtered at DB level)
          if (_filterByGender && _selectedGenders.length > 1) {
            final userGender = userData['gender'] as String?;

            // Skip if user has no gender or gender is not in selected genders
            if (userGender == null || !_selectedGenders.contains(userGender)) {
              continue;
            }
          }
          // Note: Single gender filter is applied at database level for better performance

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

      // Always sort by distance (closest first), users without distance go to end
      people.sort((a, b) {
        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;

        // Both have distance - sort by closest first
        if (distA != null && distB != null) {
          return distA.compareTo(distB);
        }

        // Only A has distance - A comes first
        if (distA != null && distB == null) return -1;

        // Only B has distance - B comes first
        if (distA == null && distB != null) return 1;

        // Neither has distance - sort by match score
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

          // Update people list
          if (loadMore) {
            _nearbyPeople.addAll(people);
            _isLoadingMore = false;
          } else {
            _nearbyPeople = people;
            _isLoadingPeople = false;
          }

          // Apply search filter if search query exists
          _applySearchFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby people: $e');
      if (mounted) {
        setState(() {
          _isLoadingPeople = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load nearby users. Please check your connection.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadNearbyPeople();
              },
            ),
          ),
        );
      }
    }
  }

  // Filter people based on search query
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPeople = _nearbyPeople;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPeople = _nearbyPeople.where((person) {
        final userData = person['userData'] as Map<String, dynamic>;
        final name = (userData['name'] ?? '').toString().toLowerCase();
        final interests = List<String>.from(userData['interests'] ?? []);

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
      await _firestore.collection('users').doc(userId).update({
        'interests': _selectedInterests,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interests updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload nearby people
      _loadNearbyPeople();
    } catch (e) {
      debugPrint('Error updating interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to save interests. Please try again.'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
              title: const Text('Select Your Interests'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _availableInterests[index];
                    final isSelected = tempSelected.contains(interest);

                    return CheckboxListTile(
                      title: Text(interest),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests = tempSelected;
                    });
                    Navigator.pop(context);
                    _updateInterests();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Filter Options',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location Section with Distance Slider
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Distance Slider (dimmed when Worldwide selected)
                          Opacity(
                            opacity: _locationFilter == 'Worldwide' ? 0.3 : 1.0,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Distance',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      '${_distanceFilter.round()} km',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: const Color(0xFF00D67D),
                                    inactiveTrackColor: Colors.grey[700],
                                    thumbColor: const Color(0xFF00D67D),
                                    overlayColor: const Color(
                                      0xFF00D67D,
                                    ).withValues(alpha: 0.2),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: _distanceFilter,
                                    min: 1,
                                    max: 500,
                                    divisions: 499,
                                    onChanged: _locationFilter == 'Worldwide'
                                        ? null // Disable slider when Worldwide selected
                                        : (value) {
                                            setDialogState(() {
                                              _distanceFilter = value;
                                            });
                                          },
                                  ),
                                ),
                                if (_locationFilter == 'Worldwide')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Distance filter not applicable for worldwide search',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Location Filter Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Near me', 'City', 'Worldwide'].map((
                              filter,
                            ) {
                              final isSelected = _locationFilter == filter;
                              return GestureDetector(
                                onTap: () async {
                                  // Check location permission for "Near me"
                                  if (filter == 'Near me') {
                                    final hasPermission =
                                        await _checkLocationPermission();
                                    if (!hasPermission) {
                                      return; // Don't change filter if permission denied
                                    }
                                  }
                                  setDialogState(() {
                                    _locationFilter = filter;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF00D67D)
                                        : Colors.grey[800],
                                    borderRadius: BorderRadius.circular(20),
                                    border: isSelected
                                        ? null
                                        : Border.all(color: Colors.grey[600]!),
                                  ),
                                  child: Text(
                                    filter,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 32),

                          // Interests Section
                          Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Interests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _filterByInterests,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _filterByInterests = value;
                                  });
                                },
                                activeThumbColor: const Color(0xFF00D67D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_filterByInterests) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Select interests to match with:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                Text(
                                  '${_selectedInterests.length}/10 selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedInterests.length >= 10
                                        ? Colors.orange
                                        : Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedInterests.length >= 10)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Maximum 10 interests can be selected (Firestore limit)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableInterests.map((interest) {
                                final isSelected = _selectedInterests.contains(
                                  interest,
                                );
                                final canSelect =
                                    isSelected ||
                                    _selectedInterests.length < 10;
                                return GestureDetector(
                                  onTap: canSelect
                                      ? () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              _selectedInterests.remove(
                                                interest,
                                              );
                                            } else {
                                              _selectedInterests.add(interest);
                                            }
                                          });
                                        }
                                      : null,
                                  child: Opacity(
                                    opacity: canSelect ? 1.0 : 0.4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                                  .withValues(alpha: 0.2)
                                            : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[600]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                          if (isSelected)
                                            const SizedBox(width: 6),
                                          Text(
                                            interest,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enable to filter by common interests',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Gender Filter Section
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gender',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _filterByGender,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _filterByGender = value;
                                  });
                                },
                                activeThumbColor: const Color(0xFF00D67D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_filterByGender) ...[
                            Text(
                              'Select genders to match with:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableGenders.map((gender) {
                                final isSelected = _selectedGenders.contains(
                                  gender,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        _selectedGenders.remove(gender);
                                      } else {
                                        _selectedGenders.add(gender);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF4A90E2,
                                            ).withValues(alpha: 0.2)
                                          : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(20),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFF4A90E2),
                                              width: 2,
                                            )
                                          : Border.all(
                                              color: Colors.grey[600]!,
                                            ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Color(0xFF4A90E2),
                                          ),
                                        if (isSelected)
                                          const SizedBox(width: 6),
                                        Text(
                                          gender,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFF4A90E2)
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enable to filter by gender',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Connection Types Filter Section
                          Row(
                            children: [
                              const Icon(
                                Icons.connect_without_contact,
                                color: Color(0xFF9C27B0), // Purple
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Connection Types',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _filterByConnectionTypes,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _filterByConnectionTypes = value;
                                  });
                                },
                                activeThumbColor: const Color(0xFF00D67D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_filterByConnectionTypes) ...[
                            Text(
                              'Select connection types you\'re interested in:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Grouped connection types
                            ..._connectionTypeGroups.entries.map((groupEntry) {
                              final groupName = groupEntry.key;
                              final types = groupEntry.value;
                              final isExpanded =
                                  _expandedConnectionGroups[groupName] ?? false;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Group header
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _expandedConnectionGroups[groupName] =
                                            !isExpanded;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF9C27B0,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF9C27B0,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: const Color(0xFF9C27B0),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            groupName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF9C27B0),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${types.where((t) => _selectedConnectionTypes.contains(t)).length}/${types.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Group content (chips)
                                  if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: types.map((type) {
                                          final isSelected =
                                              _selectedConnectionTypes.contains(
                                                type,
                                              );
                                          final userConnectionTypes =
                                              List<String>.from(
                                                _userProfile?['connectionTypes'] ??
                                                    [],
                                              );
                                          final isUserOwn = userConnectionTypes
                                              .contains(type);

                                          return GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                if (isSelected) {
                                                  _selectedConnectionTypes
                                                      .remove(type);
                                                } else {
                                                  _selectedConnectionTypes.add(
                                                    type,
                                                  );
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(
                                                        0xFF00D67D,
                                                      ).withValues(alpha: 0.2)
                                                    : isUserOwn
                                                    ? const Color(
                                                        0xFF9C27B0,
                                                      ).withValues(alpha: 0.1)
                                                    : Colors.grey[800],
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF00D67D)
                                                      : isUserOwn
                                                      ? const Color(
                                                          0xFF9C27B0,
                                                        ).withValues(alpha: 0.5)
                                                      : Colors.grey[600]!,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isSelected)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      size: 16,
                                                      color: Color(0xFF00D67D),
                                                    ),
                                                  if (isSelected)
                                                    const SizedBox(width: 6),
                                                  if (isUserOwn && !isSelected)
                                                    const Icon(
                                                      Icons.person,
                                                      size: 14,
                                                      color: Color(0xFF9C27B0),
                                                    ),
                                                  if (isUserOwn && !isSelected)
                                                    const SizedBox(width: 4),
                                                  Text(
                                                    type,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF00D67D,
                                                            )
                                                          : isUserOwn
                                                          ? const Color(
                                                              0xFF9C27B0,
                                                            )
                                                          : Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              );
                            }),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enable to filter by connection types',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Activities Filter Section
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_run,
                                color: Color(0xFF9C27B0), // Purple
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Activities',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _filterByActivities,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _filterByActivities = value;
                                  });
                                },
                                activeThumbColor: const Color(0xFF00D67D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_filterByActivities) ...[
                            Text(
                              'Select activities you\'re interested in:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Grouped activities
                            ..._activityGroups.entries.map((groupEntry) {
                              final groupName = groupEntry.key;
                              final activities = groupEntry.value;
                              final isExpanded =
                                  _expandedActivityGroups[groupName] ?? false;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Group header
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _expandedActivityGroups[groupName] =
                                            !isExpanded;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF9C27B0,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF9C27B0,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: const Color(0xFF9C27B0),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            groupName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF9C27B0),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${activities.where((a) => _selectedActivities.contains(a)).length}/${activities.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Group content (chips)
                                  if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: activities.map((activity) {
                                          final isSelected = _selectedActivities
                                              .contains(activity);
                                          final userActivities =
                                              List<String>.from(
                                                _userProfile?['activities'] ??
                                                    [],
                                              );
                                          final isUserOwn = userActivities
                                              .contains(activity);

                                          return GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                if (isSelected) {
                                                  _selectedActivities.remove(
                                                    activity,
                                                  );
                                                } else {
                                                  _selectedActivities.add(
                                                    activity,
                                                  );
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(
                                                        0xFF00D67D,
                                                      ).withValues(alpha: 0.2)
                                                    : isUserOwn
                                                    ? const Color(
                                                        0xFF9C27B0,
                                                      ).withValues(alpha: 0.1)
                                                    : Colors.grey[800],
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF00D67D)
                                                      : isUserOwn
                                                      ? const Color(
                                                          0xFF9C27B0,
                                                        ).withValues(alpha: 0.5)
                                                      : Colors.grey[600]!,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isSelected)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      size: 16,
                                                      color: Color(0xFF00D67D),
                                                    ),
                                                  if (isSelected)
                                                    const SizedBox(width: 6),
                                                  if (isUserOwn && !isSelected)
                                                    const Icon(
                                                      Icons.person,
                                                      size: 14,
                                                      color: Color(0xFF9C27B0),
                                                    ),
                                                  if (isUserOwn && !isSelected)
                                                    const SizedBox(width: 4),
                                                  Text(
                                                    activity,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF00D67D,
                                                            )
                                                          : isUserOwn
                                                          ? const Color(
                                                              0xFF9C27B0,
                                                            )
                                                          : Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              );
                            }),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enable to filter by activities',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
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
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // State is already updated from setDialogState
                              });
                              Navigator.pop(context);
                              // Reload nearby people with new filters
                              _loadNearbyPeople();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D67D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(
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
            );
          },
        );
      },
    );
  }

  // Helper method to get gradient colors based on user name
  List<Color> _getAvatarGradient(String name) {
    final hash = name.hashCode % 5;
    switch (hash) {
      case 0:
        return [const Color(0xFFFF6B9D), const Color(0xFFC7365F)]; // Pink
      case 1:
        return [const Color(0xFF4A90E2), const Color(0xFF2E5BFF)]; // Blue
      case 2:
        return [const Color(0xFFFF6B35), const Color(0xFFFF4E00)]; // Orange
      case 3:
        return [const Color(0xFF9B59B6), const Color(0xFF6C3483)]; // Purple
      default:
        return [const Color(0xFF00D67D), const Color(0xFF00A85E)]; // Green
    }
  }

  /// Check if user is truly online based on lastSeen timestamp
  /// User is considered online only if lastSeen is within last 5 minutes
  bool _isUserTrulyOnline(bool isOnlineFlag, DateTime? lastSeen) {
    if (!isOnlineFlag) return false;
    if (lastSeen == null) return false;

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    // Consider online only if seen within last 5 minutes
    return difference.inMinutes < 5;
  }

  void _showProfileDetail(ExtendedUserProfile user) async {
    // Check connection status before showing sheet
    final connectionStatus = await _connectionService
        .getConnectionRequestStatus(user.uid);
    final isConnected = await _connectionService.areUsersConnected(
      _auth.currentUser!.uid,
      user.uid,
    );

    if (!mounted) return;

    // Determine the status to display
    final displayStatus = isConnected
        ? 'connected'
        : connectionStatus; // 'sent', 'received', or null

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileDetailBottomSheet(
        user: user,
        connectionStatus: displayStatus,
        onConnect: isConnected
            ? null // Already connected, hide button
            : connectionStatus == 'sent'
            ? null // Already sent, show different state
            : () async {
                Navigator.pop(context);

                // OPTIMISTIC UPDATE: Immediately show "Request Sent" in UI
                _updateConnectionCache(user.uid, false, requestStatus: 'sent');

                // Show immediate feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Sending connection request...')),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Send real connection request in background
                final result = await _connectionService.sendConnectionRequest(
                  receiverId: user.uid,
                );

                if (!mounted) return;

                if (result['success']) {
                  // Request succeeded - cache is already updated optimistically
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Connection request sent!')),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Request failed - revert optimistic update
                  _updateConnectionCache(user.uid, false, requestStatus: null);

                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result['message'] ?? 'Failed to send request',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
        onMessage: () {
          Navigator.pop(context);
          // Open chat with this user
          final userProfile = UserProfile(
            uid: user.uid,
            name: user.name,
            email: '',
            profileImageUrl: user.photoUrl,
            location: user.location,
            latitude: user.latitude,
            longitude: user.longitude,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            isOnline: user.isOnline,
            interests: user.interests,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: userProfile),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final isGlass = themeState.isGlassmorphism;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Networking',
          style: TextStyle(
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ),
        // actions: [
        //   // Live Connect Icon with Background Container
        //   StreamBuilder<int>(
        //     stream: _connectionService.getPendingRequestsCountStream(),
        //     builder: (context, snapshot) {
        //       final count = snapshot.data ?? 0;

        //       return Stack(
        //         clipBehavior: Clip.none,
        //         children: [
        //           Container(
        //             margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        //             decoration: BoxDecoration(
        //               color: Colors.white.withValues(alpha: 0.15),
        //               shape: BoxShape.circle,
        //               border: Border.all(
        //                 color: Colors.white.withValues(alpha: 0.3),
        //                 width: 1,
        //               ),
        //             ),
        //             child: IconButton(
        //               onPressed: () {
        //                 Navigator.push(
        //                   context,
        //                   MaterialPageRoute(
        //                     builder: (context) => const MyConnectionsScreen(),
        //                   ),
        //                 );
        //               },
        //               icon: const Icon(
        //                 Icons.people_outline,
        //                 color: Colors.white,
        //                 size: 22,
        //               ),
        //               tooltip: 'Connection Requests',
        //             ),
        //           ),
        //           if (count > 0)
        //             Positioned(
        //               right: 4,
        //               top: 4,
        //               child: Container(
        //                 padding: const EdgeInsets.all(4),
        //                 decoration: BoxDecoration(
        //                   color: Colors.red.shade600,
        //                   shape: BoxShape.circle,
        //                   border: Border.all(color: Colors.white, width: 2),
        //                 ),
        //                 constraints: const BoxConstraints(
        //                   minWidth: 20,
        //                   minHeight: 20,
        //                 ),
        //                 child: Center(
        //                   child: Text(
        //                     count > 9 ? '9+' : '$count',
        //                     style: const TextStyle(
        //                       color: Colors.white,
        //                       fontSize: 10,
        //                       fontWeight: FontWeight.bold,
        //                     ),
        //                   ),
        //                 ),
        //               ),
        //             ),
        //         ],
        //       );
        //     },
        //   ),
        //   // Profile Avatar Button (removed - matches Messages screen)
        //   const SizedBox(width: 8),
        // ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.2),
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
              unselectedLabelColor: Colors.white.withOpacity(0.6),

              isScrollable: false,
              tabAlignment: TabAlignment.fill,

              tabs: _tabCategories.map((category) {
                final isFirst = category == _tabCategories.first;

                return Tab(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isFirst ? 18 : 0,
                      right: isFirst ? 0 : 18,
                    ),
                    child: Align(
                      alignment: isFirst
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Text(category),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: AppBackground(
        showParticles: true,
        overlayOpacity: 0.6,
        child: Stack(
          children: [
            // Floating glass circles for depth (kept for visual effect)
            if (isGlass) ...[
              Positioned(
                top: 150,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.iosPurple.withValues(alpha: 0.2),
                        AppColors.iosPurple.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 200,
                left: -100,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.iosBlue.withValues(alpha: 0.15),
                        AppColors.iosBlue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Search bar with filter button - glass effect like Messages screen
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Search field
                        Expanded(
                          child: GlassSearchField(
                            controller: _searchController,
                            hintText: 'Search people...',
                            borderRadius: 26,
                            showMic: true,
                            isListening: isListening, // From VoiceSearchMixin
                            onMicTap: _startVoiceSearch,
                            onStopListening: _stopVoiceSearch,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _applySearchFilter();
                              });
                            },
                            onClear: () {
                              setState(() {
                                _searchQuery = '';
                                _applySearchFilter();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filter button with circular container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _showFilterDialog,
                            icon: const Icon(
                              Icons.tune,
                              color: Colors.white,
                              size: 22,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Main content with TabBarView for swipe
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabCategories.map((category) {
                        return _buildContent(isDarkMode, isGlass);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, bool isGlass) {
    // Show empty state only if interest filter is on AND no interests selected
    if (_filterByInterests && _selectedInterests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Connect with People',
              style: TextStyle(
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
                style: TextStyle(
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
                  onPressed: _showFilterDialog,
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try adjusting your search term',
                      style: TextStyle(
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

    if (_filteredPeople.isEmpty) {
      // Determine contextual empty state message
      String title = 'No users found';
      String subtitle = '';
      IconData icon = Icons.search_off;

      if (_locationFilter == 'Near me' &&
          (_userProfile?['latitude'] == null ||
              _userProfile?['longitude'] == null)) {
        title = 'Location not available';
        subtitle = 'Enable location permissions to find nearby users';
        icon = Icons.location_off;
      } else if (_filterByInterests && _selectedInterests.isEmpty) {
        title = 'No interests selected';
        subtitle = 'Select at least one interest to find matches';
        icon = Icons.favorite_border;
      } else if (_locationFilter == 'Near me' && _distanceFilter < 10) {
        title = 'Search radius too small';
        subtitle =
            'Try expanding your distance to ${(_distanceFilter * 2).round()} km or more';
        icon = Icons.radar;
      } else if (_locationFilter == 'City' &&
          (_userProfile?['city'] == null ||
              (_userProfile?['city'] as String).isEmpty)) {
        title = 'City not set';
        subtitle = 'Update your profile with your city to use this filter';
        icon = Icons.location_city;
      } else {
        title = 'No matches found';
        subtitle = _filterByInterests
            ? 'Try selecting different interests or expanding your search'
            : 'Try adjusting your filters or check back later';
        icon = Icons.people_outline;
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _loadNearbyPeople();
        },
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 80,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: TextStyle(
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
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _showFilterDialog,
                          icon: const Icon(Icons.tune),
                          label: const Text('Adjust Filters'),
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

    return RefreshIndicator(
      onRefresh: () async {
        await _loadNearbyPeople(forceRefreshLocation: true);
      },
      color: Theme.of(context).primaryColor,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),

        itemCount: _filteredPeople.length + (_hasMoreUsers ? 1 : 0),
        itemBuilder: (context, index) {
          // Show "Load More" button at the end if there are more users
          if (index == _filteredPeople.length) {
            return Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: () => _loadNearbyPeople(loadMore: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Load More Users'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
            );
          }

          final person = _filteredPeople[index];
          final userData = person['userData'] as Map<String, dynamic>;
          final commonInterests = person['commonInterests'] as List<String>;
          // matchScore available but not currently displayed
          final userId = person['userId'] as String;
          final distance = person['distance'] as double?;

          // Create ExtendedUserProfile from userData with distance
          final extendedProfile = ExtendedUserProfile.fromMap(userData, userId);

          // Create a new profile with distance set
          final profileWithDistance = ExtendedUserProfile(
            uid: extendedProfile.uid,
            name: extendedProfile.name,
            photoUrl: extendedProfile.photoUrl,
            city: extendedProfile.city,
            location: extendedProfile.location,
            latitude: extendedProfile.latitude,
            longitude: extendedProfile.longitude,
            interests: extendedProfile.interests,
            verified: extendedProfile.verified,
            connectionTypes: extendedProfile.connectionTypes,
            activities: extendedProfile.activities,
            aboutMe: extendedProfile.aboutMe,
            isOnline: extendedProfile.isOnline,
            lastSeen: extendedProfile.lastSeen,
            age: extendedProfile.age,
            gender: extendedProfile.gender,
            distance: distance, // Set the calculated distance
          );

          final gradientColors = _getAvatarGradient(extendedProfile.name);
          final userName = userData['name'] ?? 'Unknown User';

          // Format distance for display
          String? distanceText;
          if (distance != null) {
            if (distance < 1) {
              distanceText = '${(distance * 1000).round()}m';
            } else {
              distanceText = '${distance.toStringAsFixed(1)}km';
            }
          }
          // Netwoking list item with enhanced design and real-time online status
          return GestureDetector(
            onTap: () => _showProfileDetail(profileWithDistance),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: Column(
                  children: [
                    // Profile Image with gradient background
                    Stack(
                      children: [
                        Builder(
                          builder: (context) {
                            final fixedPhotoUrl =
                                PhotoUrlHelper.fixGooglePhotoUrl(
                                  extendedProfile.photoUrl,
                                );
                            final userInitial = userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?';

                            // Fallback widget showing user's initial
                            Widget buildInitialAvatar() {
                              return Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: gradientColors[0].withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    userInitial,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // If no valid photo URL, show initial
                            if (fixedPhotoUrl == null ||
                                fixedPhotoUrl.isEmpty) {
                              return buildInitialAvatar();
                            }

                            // Show photo with fallback to initial on error
                            return Container(
                              margin: EdgeInsets
                                  .zero, //   remove outer space if any
                              width: double.infinity,
                              height: 90,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                ),
                                child: SizedBox.expand(
                                  //   important add this
                                  child: CachedNetworkImage(
                                    imageUrl: fixedPhotoUrl,
                                    fit: BoxFit.cover, //   full cover
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          userInitial,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      if (error.toString().contains('429')) {
                                        PhotoUrlHelper.markAsRateLimited(url);
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            userInitial,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Real-time online status indicator
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            bool isOnline = false;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              if (data != null) {
                                final onlineFlag =
                                    data['isOnline'] as bool? ?? false;
                                final lastSeenTimestamp = data['lastSeen'];
                                DateTime? lastSeen;
                                if (lastSeenTimestamp != null) {
                                  lastSeen = (lastSeenTimestamp as Timestamp)
                                      .toDate();
                                }
                                isOnline = _isUserTrulyOnline(
                                  onlineFlag,
                                  lastSeen,
                                );
                              }
                            }

                            if (!isOnline) return const SizedBox.shrink();

                            return Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D67D),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isGlass
                                        ? Colors.white
                                        : (isDarkMode
                                              ? Colors.black
                                              : Colors.white),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // User Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (extendedProfile.verified) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: gradientColors[0],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // City, Distance, and Gender - always show this row
                            Row(
                              children: [
                                if (extendedProfile.city != null &&
                                    extendedProfile.city!.isNotEmpty) ...[
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: isDarkMode
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  // const SizedBox(width: 4),
                                ],
                                if (distanceText != null) ...[
                                  if (extendedProfile.city != null &&
                                      extendedProfile.city!.isNotEmpty)
                                    const SizedBox(width: 4),
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Common Interests Count
                            if (commonInterests.isNotEmpty &&
                                _filterByInterests) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 13,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${commonInterests.length} common interest${commonInterests.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ); // Close RefreshIndicator
  }

  // Check and request location permission
  Future<bool> _checkLocationPermission() async {
    final status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
        return false;
      }
      return false;
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog();
      return false;
    }

    return false;
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Location Permission Required'),
          ],
        ),
        content: const Text(
          'To find nearby users, please enable location permission in your device settings.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
