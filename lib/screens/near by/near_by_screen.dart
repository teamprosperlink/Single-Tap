import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';
import '../../services/notification_service.dart';
import '../../res/utils/snackbar_helper.dart';
import 'near_by_posts _screen.dart';

import 'edit_post_screen.dart';

class NearByScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NearByScreen({super.key, this.onBack});

  @override
  State<NearByScreen> createState() => _NearByScreenState();
}

class _NearByScreenState extends State<NearByScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Posts data
  List<DocumentSnapshot> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false; // Separate flag for pagination loading
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 30; // Increased page size for fewer loads

  // Cached filtered posts to avoid recomputation
  List<DocumentSnapshot>? _cachedFilteredPosts;
  String? _lastSearchQuery;
  String? _lastSelectedCategory;

  // Real-time stream subscription
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  // Saved posts
  Set<String> _savedPostIds = {};

  // User cache for fetching names
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Voice search
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  // Categories
  String _selectedCategory = 'All';
  bool _isCategoryLoading = false;

  // Expanded posts tracking
  final Set<String> _expandedPosts = {};

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Service', 'icon': Icons.computer_rounded},
    {'name': 'Jobs', 'icon': Icons.work_rounded},
    {'name': 'Products', 'icon': Icons.shopping_bag_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
        setState(() {
          _isCategoryLoading = true;
          _selectedCategory = _categories[_tabController.index]['name'];
        });
        // Simulate loading delay for smooth UX
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isCategoryLoading = false;
            });
          }
        });
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _subscribeToFeedPosts();
    _loadSavedPosts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _initSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload saved posts when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadSavedPosts();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload saved posts when returning to this screen
    _loadSavedPosts();
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

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _postsSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  void _onScroll() {
    // Trigger loading earlier (500px before end) for smoother experience
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoadingMore && !_isLoading && _hasMore) {
        _loadMorePosts();
      }
    }
  }

  void _subscribeToFeedPosts() {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    // Real-time stream subscription for latest posts
    _postsSubscription = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _posts = snapshot.docs;
                _isLoading = false;
                _hasMore = snapshot.docs.length == _pageSize;
                if (snapshot.docs.isNotEmpty) {
                  _lastDocument = snapshot.docs.last;
                }
                // Invalidate cache when posts change
                _cachedFilteredPosts = null;
              });
            }
          },
          onError: (e) {
            debugPrint('Error loading feed posts: $e');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _lastDocument == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Simple query without compound index requirement
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          // Filter out duplicates before adding
          final existingIds = _posts.map((d) => d.id).toSet();
          final newDocs = snapshot.docs
              .where((d) => !existingIds.contains(d.id))
              .toList();
          _posts.addAll(newDocs);
          _isLoadingMore = false;
          _hasMore = snapshot.docs.length == _pageSize;
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
          }
          // Invalidate cache when posts change
          _cachedFilteredPosts = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadSavedPosts() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .get();

      if (mounted) {
        setState(() {
          _savedPostIds = savedSnapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
    }
  }

  /// Fetch user data from Firestore and cache it
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    return null;
  }

  /// Get display name for a post - fetches from user profile if not stored
  String _getDisplayName(
    Map<String, dynamic> post,
    Map<String, dynamic>? userData,
  ) {
    // First try post's stored userName
    final postUserName = post['userName'] as String?;
    if (postUserName != null &&
        postUserName.isNotEmpty &&
        postUserName != 'User') {
      return postUserName;
    }

    // Then try fetched user data
    if (userData != null) {
      // Try name first
      final name = userData['name'] ?? userData['displayName'];
      if (name != null &&
          name.toString().isNotEmpty &&
          name.toString() != 'User') {
        return name.toString();
      }
      // Fallback to phone number for phone login users
      final phone = userData['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        return phone;
      }
    }

    return 'User';
  }

  /// Get photo URL for a post - fetches from user profile if not stored
  String? _getPhotoUrl(
    Map<String, dynamic> post,
    Map<String, dynamic>? userData,
  ) {
    // First try post's stored userPhoto
    final postPhoto = post['userPhoto'] as String?;
    if (postPhoto != null && postPhoto.isNotEmpty) {
      return postPhoto;
    }

    // Then try fetched user data
    if (userData != null) {
      return userData['photoUrl'] ??
          userData['photoURL'] ??
          userData['profileImageUrl'];
    }

    return null;
  }

  Future<void> _toggleSavePost(
    String postId,
    Map<String, dynamic> postData,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    HapticFeedback.lightImpact();

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(postId);

      if (_savedPostIds.contains(postId)) {
        await savedRef.delete();
        if (mounted) {
          setState(() {
            _savedPostIds.remove(postId);
          });
        }
      } else {
        await savedRef.set({
          'postId': postId,
          'postData': postData,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _savedPostIds.add(postId);
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
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

    setState(() {
      _isListening = false;
    });
  }

  List<DocumentSnapshot> get _filteredPosts {
    final searchQuery = _searchController.text.toLowerCase().trim();

    // Return cached result if inputs haven't changed
    if (_cachedFilteredPosts != null &&
        _lastSearchQuery == searchQuery &&
        _lastSelectedCategory == _selectedCategory) {
      return _cachedFilteredPosts!;
    }

    final currentUserId = _auth.currentUser?.uid;
    final seenIds = <String>{};
    final seenTitles = <String>{}; // Track unique titles to remove duplicates

    final result = _posts.where((doc) {
      // Remove duplicates by ID
      if (seenIds.contains(doc.id)) return false;
      seenIds.add(doc.id);

      final data = doc.data() as Map<String, dynamic>;

      // Skip dummy posts (users that don't exist in Firebase)
      final isDummyPost = data['isDummyPost'] == true;
      if (isDummyPost) return false;

      // Skip posts from dummy users (userId starts with 'dummy_')
      final postUserId = data['userId'] as String?;
      if (postUserId == null || postUserId.startsWith('dummy_')) return false;

      // Remove duplicates by title only (more reliable)
      final title = (data['title'] ?? data['originalPrompt'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (title.isNotEmpty && seenTitles.contains(title)) return false;
      if (title.isNotEmpty) seenTitles.add(title);

      // Filter out current user's own posts (they can see them in My Posts tab)
      if (postUserId == currentUserId) return false;

      // Filter out inactive posts
      if (data['isActive'] == false) return false;

      // Category filter
      if (_selectedCategory != 'All') {
        if (!_matchesCategory(data)) return false;
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        if (!_matchesSearch(data, searchQuery)) return false;
      }

      return true;
    }).toList();

    // Cache the result
    _cachedFilteredPosts = result;
    _lastSearchQuery = searchQuery;
    _lastSelectedCategory = _selectedCategory;

    return result;
  }

  // Extracted for better performance - avoid recreating strings repeatedly
  bool _matchesCategory(Map<String, dynamic> data) {
    final text = _getCombinedText(data);

    switch (_selectedCategory) {
      case 'News':
        return text.contains('news') ||
            text.contains('breaking') ||
            text.contains('update') ||
            text.contains('report') ||
            text.contains('headline') ||
            text.contains('latest') ||
            text.contains('announcement');

      case 'Entertainment':
        return text.contains('entertainment') ||
            text.contains('movie') ||
            text.contains('music') ||
            text.contains('film') ||
            text.contains('song') ||
            text.contains('celebrity') ||
            text.contains('show') ||
            text.contains('concert') ||
            text.contains('game') ||
            text.contains('gaming');

      case 'Technology':
        return text.contains('technology') ||
            text.contains('tech') ||
            text.contains('software') ||
            text.contains('app') ||
            text.contains('computer') ||
            text.contains('phone') ||
            text.contains('ai') ||
            text.contains('digital') ||
            text.contains('gadget') ||
            text.contains('device');

      case 'Jobs':
        return text.contains('job') ||
            text.contains('hiring') ||
            text.contains('work') ||
            text.contains('vacancy') ||
            text.contains('career') ||
            text.contains('employment') ||
            text.contains('recruit') ||
            text.contains('position') ||
            text.contains('opening');

      case 'Products':
        return text.contains('product') ||
            text.contains('sell') ||
            text.contains('buy') ||
            text.contains('sale') ||
            text.contains('price') ||
            text.contains('shop') ||
            text.contains('store') ||
            text.contains('discount') ||
            text.contains('offer') ||
            data['price'] != null;

      default:
        return true;
    }
  }

  String _getCombinedText(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().toLowerCase();
    final description = (data['description'] ?? '').toString().toLowerCase();
    final hashtags =
        (data['hashtags'] as List<dynamic>?)?.join(' ').toLowerCase() ?? '';
    return '$title $description $hashtags';
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

    final hashtags =
        (data['hashtags'] as List<dynamic>?)?.join(' ').toLowerCase() ?? '';
    if (hashtags.contains(searchQuery)) return true;

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
        actions: [
          // More options icon with circular container
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPostsScreen()),
              );
            },
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 18,
            ),
            iconSize: 18,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              isScrollable: false,
              tabs: _categories.map((category) {
                return Tab(text: category['name'] as String);
              }).toList(),
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
        child: Stack(
          children: [
            Column(
              children: [
                // Spacer for AppBar with TabBar
                SizedBox(
                  height:
                      MediaQuery.of(context).padding.top + kToolbarHeight + 48,
                ),

                // Search bar
                _buildGlassSearchBar(),

                // Posts list with TabBarView for swipe functionality
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _categories.map((category) {
                      return _isLoading && _posts.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : _isCategoryLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : _filteredPosts.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              // Performance optimizations
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              cacheExtent: 500,
                              itemCount:
                                  _filteredPosts.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredPosts.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }

                                final doc = _filteredPosts[index];
                                final data = doc.data() as Map<String, dynamic>;

                                return RepaintBoundary(
                                  child: _buildPostCard(
                                    postId: doc.id,
                                    post: data,
                                    isSaved: _savedPostIds.contains(doc.id),
                                  ),
                                );
                              },
                            );
                    }).toList(),
                  ),
                ),
              ],
            ),

            // // Floating Action Button - Create Post
            // Positioned(
            //   bottom: 20,
            //   right: 20,
            //   child: FloatingActionButton(
            //     onPressed: _showCreatePostDialog,
            //     backgroundColor: AppColors.iosBlue,
            //     shape: const CircleBorder(),
            //     child: const Icon(Icons.add, color: Colors.white, size: 28),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: GlassSearchField(
        controller: _searchController,
        hintText: 'Search posts...',
        borderRadius: 16,
        showMic: true,
        isListening: _isListening,
        onMicTap: _startVoiceSearch,
        onStopListening: _stopVoiceSearch,
        onChanged: (value) => setState(() {}),
        onClear: () => setState(() {}),
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
    required bool isSaved,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    final postUserId = post['userId'] as String?;
    final isOwnPost = currentUserId == postUserId;

    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description =
        (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    // Collect all image URLs
    final allImageUrls = <String>[];
    if (rawImageUrl != null && rawImageUrl.toString().isNotEmpty) {
      allImageUrls.add(rawImageUrl.toString());
    }
    for (final img in images) {
      final url = img?.toString() ?? '';
      if (url.isNotEmpty && !allImageUrls.contains(url)) {
        allImageUrls.add(url);
      }
    }
    // Limit to max 10 images
    if (allImageUrls.length > 10)
      allImageUrls.removeRange(10, allImageUrls.length);
    final imageUrl = allImageUrls.isNotEmpty ? allImageUrls[0] : null;
    final price = post['price'];
    final createdAt = post['createdAt'];

    // Check if we need to fetch user data
    final storedUserName = post['userName'] as String?;
    final storedUserPhoto = post['userPhoto'] as String?;

    // Get cached data if available
    final cachedUserData = postUserId != null ? _userCache[postUserId] : null;

    // Determine display name and photo
    String userName;
    String? userPhoto;

    if (cachedUserData != null) {
      userName = _getDisplayName(post, cachedUserData);
      userPhoto = _getPhotoUrl(post, cachedUserData);
    } else {
      userName = storedUserName ?? 'User';
      userPhoto = storedUserPhoto;

      // Fetch user data in background if name is missing/default
      if (postUserId != null &&
          !postUserId.startsWith('dummy_') &&
          (storedUserName == null ||
              storedUserName.isEmpty ||
              storedUserName == 'User')) {
        _getUserData(postUserId).then((userData) {
          if (userData != null && mounted) {
            setState(() {}); // Trigger rebuild with cached data
          }
        });
      }
    }

    DateTime? time;
    if (createdAt != null && createdAt is Timestamp) {
      time = createdAt.toDate();
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

    int contentLevel = 0;
    if (hasImage) {
      contentLevel = 3;
    } else if (hasPrice && hasDescription) {
      contentLevel = 2;
    } else if (hasPrice || hasDescription) {
      contentLevel = 1;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = contentLevel == 3 ? screenHeight * 0.16 : 0.0;
    final cardPadding = contentLevel >= 2 ? 12.0 : 10.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(
                      userPhoto,
                    ),
                    radius: contentLevel >= 2 ? 18 : 14,
                    fallbackText: userName,
                  ),
                  SizedBox(width: contentLevel >= 2 ? 10 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: contentLevel >= 2 ? 13 : 12,
                            color: Colors.white,
                          ),
                        ),
                        if (time != null)
                          Text(
                            timeago.format(time),
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Action buttons
                  // For own posts: Edit and Delete
                  if (isOwnPost) ...[
                    _buildIconOnlyButton(
                      icon: Icons.edit_outlined,
                      color: Colors.white,
                      onTap: () => _editPost(postId, post),
                      contentLevel: contentLevel,
                    ),
                    const SizedBox(width: 10),
                    _buildIconOnlyButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.white,
                      onTap: () => _showDeleteConfirmation(postId),
                      contentLevel: contentLevel,
                    ),
                  ],
                  // For other's posts: Chat, Call, Save
                  if (!isOwnPost) ...[
                    _buildIconOnlyButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      onTap: () => _openUserChat(post),
                      contentLevel: contentLevel,
                    ),
                    if (post['allowCalls'] ?? true) ...[
                      const SizedBox(width: 10),
                      _buildIconOnlyButton(
                        icon: Icons.call_outlined,
                        color: Colors.white,
                        onTap: () => _makeVoiceCall(post),
                        contentLevel: contentLevel,
                      ),
                    ],
                    const SizedBox(width: 10),
                    _buildIconOnlyButton(
                      icon: _savedPostIds.contains(postId)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: Colors.white,
                      onTap: () => _toggleSavePost(postId, post),
                      contentLevel: contentLevel,
                    ),
                  ],
                ],
              ),

              SizedBox(height: contentLevel >= 2 ? 8 : 6),

              // Title and Description with See More
              _buildExpandableText(
                title: title,
                description: hasDescription ? description : null,
                postId: postId,
              ),

              // Price
              if (hasPrice) ...[
                SizedBox(height: contentLevel >= 2 ? 8 : 6),
                Text(
                  '₹${price.toString()}',
                  style: TextStyle(
                    fontSize: contentLevel >= 2 ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.vibrantGreen,
                  ),
                ),
              ],

              // Post Images
              if (allImageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Main image
                GestureDetector(
                  onTap: () => _openImageViewer(allImageUrls, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: allImageUrls[0],
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiaryDark,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                // Additional images in grid
                if (allImageUrls.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 2nd image
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openImageViewer(allImageUrls, 1),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: allImageUrls[1],
                              height: screenHeight * 0.12,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: screenHeight * 0.12,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBackgroundDark(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: screenHeight * 0.12,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBackgroundDark(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textTertiaryDark,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 3rd image with +N overlay
                      if (allImageUrls.length > 2) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openImageViewer(allImageUrls, 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: screenHeight * 0.12,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: allImageUrls[2],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.glassBackgroundDark(
                                          alpha: 0.1,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color:
                                                AppColors.glassBackgroundDark(
                                                  alpha: 0.1,
                                                ),
                                            child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: AppColors.textTertiaryDark,
                                              size: 24,
                                            ),
                                          ),
                                    ),
                                    if (allImageUrls.length > 3)
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+${allImageUrls.length - 3}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);
    int currentPage = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            title: Text(
              '${currentPage + 1} / ${imageUrls.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            centerTitle: true,
          ),
          body: PageView.builder(
            controller: pageController,
            itemCount: imageUrls.length,
            onPageChanged: (index) {
              setDialogState(() => currentPage = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Icon button with border and background - fixed size for all posts
  Widget _buildIconOnlyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int contentLevel = 2,
  }) {
    // Fixed size for all posts - consistent look
    const double buttonSize = 32.0;
    const double iconSize = 16.0;
    const double borderRadius = 8.0;

    // Wrap in Material to absorb InkWell splash from parent
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableText({
    required String title,
    String? description,
    required String postId,
  }) {
    final isExpanded = _expandedPosts.contains(postId);

    const titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      height: 1.4,
    );

    final descStyle = AppTextStyles.bodyMedium.copyWith(
      color: Colors.white70,
      height: 1.4,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate if title exceeds 3 lines
        final titleSpan = TextSpan(text: title, style: titleStyle);
        final titlePainter = TextPainter(
          text: titleSpan,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final titleExceeds3Lines = titlePainter.didExceedMaxLines;

        // Calculate if description exceeds 2 lines
        bool descExceeds2Lines = false;
        if (description != null && description.isNotEmpty) {
          final descSpan = TextSpan(text: description, style: descStyle);
          final descPainter = TextPainter(
            text: descSpan,
            maxLines: 2,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          descExceeds2Lines = descPainter.didExceedMaxLines;
        }

        // Show "See more" only if text exceeds limits
        final needsSeeMore = titleExceeds3Lines || descExceeds2Lines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: titleStyle,
              maxLines: isExpanded ? null : 3,
              overflow: isExpanded ? null : TextOverflow.ellipsis,
            ),

            // Description
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: descStyle,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
              ),
            ],

            // See more / See less button - only if text exceeds limits
            if (needsSeeMore) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isExpanded) {
                      _expandedPosts.remove(postId);
                    } else {
                      _expandedPosts.add(postId);
                    }
                  });
                },
                child: Text(
                  isExpanded ? 'See less' : 'See more',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.iosBlue,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _makeVoiceCall(Map<String, dynamic> post) {
    final postUserId = post['userId'] as String?;
    final currentUserId = _auth.currentUser?.uid;

    if (postUserId == null || postUserId == currentUserId) return;

    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];

    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User avatar with call icon
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: userPhoto != null
                          ? NetworkImage(userPhoto)
                          : null,
                      child: userPhoto == null
                          ? Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Call $userName?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You are about to start a voice call.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        // Wait for dialog to close before navigating
                        await Future.delayed(const Duration(milliseconds: 100));
                        if (!mounted) return;
                        _initiateCall(post);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initiateCall(Map<String, dynamic> post) async {
    final postUserId = post['userId'] as String?;
    final currentUser = _auth.currentUser;

    if (postUserId == null || currentUser == null) return;

    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];

    debugPrint('  ====== INITIATING CALL (Feed) ======');
    debugPrint('  Caller ID (me): ${currentUser.uid}');
    debugPrint('  Receiver ID (other): $postUserId');

    try {
      // Get current user's profile for proper name
      final callerDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final callerData = callerDoc.data();
      final callerName =
          callerData?['name'] ??
          callerData?['displayName'] ??
          currentUser.displayName ??
          'Unknown';
      final callerPhoto =
          callerData?['photoUrl'] ??
          callerData?['photoURL'] ??
          callerData?['profileImageUrl'] ??
          currentUser.photoURL;

      debugPrint('  Caller name: $callerName');
      debugPrint('  Receiver name: $userName');

      // Create call record in Firestore
      final callDoc = await _firestore.collection('calls').add({
        'callerId': currentUser.uid,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'receiverId': postUserId,
        'receiverName': userName,
        'receiverPhoto': userPhoto,
        'participants': [currentUser.uid, postUserId],
        'type': 'voice',
        'status': 'calling',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('  Call document created: ${callDoc.id}');

      // Send push notification to receiver for incoming call
      await NotificationService().sendNotificationToUser(
        userId: postUserId,
        title: 'Incoming Call',
        body: '$callerName is calling you',
        type: 'call',
        data: {
          'callId': callDoc.id,
          'callerId': currentUser.uid,
          'callerName': callerName,
          'callerPhoto': callerPhoto,
        },
      );

      if (!mounted) return;

      // Fetch full user profile for chat navigation
      final userDoc = await _firestore
          .collection('users')
          .doc(postUserId)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Use fromFirestore to get proper name (with phone fallback)
      final userProfile = UserProfile.fromFirestore(userDoc);

      // Navigate to voice call screen
      Navigator.pushNamed(
        context,
        '/voice-call',
        arguments: {
          'callId': callDoc.id,
          'otherUser': userProfile,
          'isOutgoing': true,
        },
      );
    } catch (e) {
      debugPrint('Error initiating call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPost(String postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(postId: postId, postData: post),
      ),
    );
    // Feed auto-refreshes via real-time subscription
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.glassBackgroundDark(alpha: 0.2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure? This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await _deletePost(postId);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.error,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
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

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post deleted successfully');
        // Feed auto-refreshes via real-time subscription
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete post');
      }
    }
  }

  Future<void> _openUserChat(Map<String, dynamic> post) async {
    final postUserId = post['userId'] as String?;
    final currentUserId = _auth.currentUser?.uid;

    if (postUserId == null || postUserId == currentUserId) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(postUserId)
          .get();

      if (!userDoc.exists || !mounted) return;

      // Use fromFirestore to get proper name (with phone fallback)
      final userProfile = UserProfile.fromFirestore(userDoc);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedChatScreen(otherUser: userProfile),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Posts Found',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search or category',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
