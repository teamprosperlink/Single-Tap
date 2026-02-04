import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

import '../../models/conversation_model.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/chat_common.dart';
import '../../widgets/app_background.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../services/current_user_cache.dart';
import '../../mixins/voice_search_mixin.dart';
import '../chat/enhanced_chat_screen.dart';
import '../chat/create_group_screen.dart';
import '../chat/group_chat_screen.dart';
import '../call/voice_call_screen.dart';
import '../../services/notification_service.dart';

class ConversationsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ConversationsScreen({
    super.key,
    this.onBack,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with TickerProviderStateMixin, VoiceSearchMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  String _searchQuery = '';
  int _currentTabIndex = 0;

  // User cache to avoid repeated Firestore reads
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Call selection mode
  bool _isCallSelectionMode = false;
  final Set<String> _selectedCallIds = {};

  // Conversation selection mode (for Chats and Groups tabs)
  bool _isConversationSelectionMode = false;
  final Set<String> _selectedConversationIds = {};

  @override
  void initState() {
    super.initState();
    initSpeech(); // From VoiceSearchMixin
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    try {
      _tabController.dispose();
    } catch (_) {}
    try {
      _searchController.dispose();
    } catch (_) {}
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
        _searchQuery = recognizedText.toLowerCase();
      });
    });
  }

  void _stopVoiceSearch() {
    stopVoiceSearch(); // From VoiceSearchMixin
  }

  /// Get user data with caching to reduce Firestore reads
  Future<Map<String, dynamic>?> _getUserWithCache(String userId) async {
    if (userId.isEmpty) return null;

    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    // Fetch from Firestore
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final userData = doc.data()!;
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching user $userId: $e');
    }
    return null;
  }

  /// Prefetch user data for a list of user IDs
  Future<void> _prefetchUsers(List<String> userIds) async {
    final uncachedIds = userIds
        .where((id) => !_userCache.containsKey(id) && id.isNotEmpty)
        .toList();
    if (uncachedIds.isEmpty) return;

    // Batch fetch users (max 10 at a time due to Firestore limitations)
    for (var i = 0; i < uncachedIds.length; i += 10) {
      final batch = uncachedIds.skip(i).take(10).toList();
      try {
        final futures = batch.map(
          (id) => _firestore.collection('users').doc(id).get(),
        );
        final results = await Future.wait(futures);
        for (var doc in results) {
          if (doc.exists) {
            _userCache[doc.id] = doc.data()!;
          }
        }
      } catch (e) {
        debugPrint('Error prefetching users: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _buildProfileAvatar(isDarkMode),
        ),
        title: const Text(
          'Messages',
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
              bottom: BorderSide(
                color: Colors.white,
                width: 0.5,
              ),
            ),
          ),
        ),
        actions: [
          // Add person/group icon with circular container
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white, size: 22),
              onPressed: () {
                if (_currentTabIndex == 1) {
                  _createGroup();
                } else {
                  _showNewChatDialog();
                }
              },
            ),
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
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Chats'),
                Tab(text: 'Groups'),
                Tab(text: 'Calls'),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        showParticles: true,
        overlayOpacity: 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spacer for AppBar
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
            ),
            // Search bar (hidden in selection mode)
            if (!_isConversationSelectionMode) _buildSearchBar(isDarkMode),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatsList(isDarkMode, isGroup: false),
                  _buildChatsList(isDarkMode, isGroup: true),
                  _buildCallsList(isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile avatar for AppBar
  Widget _buildProfileAvatar(bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Try multiple sources for photoUrl and name
        String? photoUrl;
        String userName = 'User';

        // 1. Try from Firestore snapshot
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          photoUrl = userData?['photoUrl'] as String?;
          userName =
              userData?['name'] as String? ??
              userData?['displayName'] as String? ??
              'User';
          // Fallback to phone number for phone login users
          if (userName == 'User' || userName.isEmpty) {
            userName = userData?['phone'] as String? ?? 'User';
          }
        }

        // 2. Fallback to cache
        photoUrl ??= CurrentUserCache().photoUrl;
        if (userName == 'User') {
          userName = CurrentUserCache().name;
        }

        // 3. Fallback to Firebase Auth
        photoUrl ??= _auth.currentUser?.photoURL;
        if (userName == 'User') {
          userName = _auth.currentUser?.displayName ?? 'User';
        }

        final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
        final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

        // Avatar fallback widget with user's initial
        Widget buildAvatarFallback() {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.blue.shade400],
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: fixedPhotoUrl != null && fixedPhotoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: fixedPhotoUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => buildAvatarFallback(),
                    errorWidget: (context, url, error) => buildAvatarFallback(),
                  )
                : buildAvatarFallback(),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: GlassSearchField(
        controller: _searchController,
        hintText: 'Search conversations...',
        borderRadius: 26,
        showMic: true,
        isListening: isListening, // From VoiceSearchMixin
        onMicTap: _startVoiceSearch,
        onStopListening: _stopVoiceSearch,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        onClear: () {
          setState(() {
            _searchQuery = '';
          });
        },
      ),
    );
  }

  Widget _buildChatsList(bool isDarkMode, {required bool isGroup}) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please login to see conversations'));
    }

    return Column(
      children: [
        // Selection mode header
        if (_isConversationSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitConversationSelectionMode,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                Text(
                  '${_selectedConversationIds.length} selected',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _selectAllConversations(isGroup),
                  child: Text(
                    'Select All',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedConversationIds.isEmpty
                      ? null
                      : _deleteSelectedConversations,
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('conversations')
                .where('participants', arrayContains: currentUserId)
                .limit(50) // Pagination for better performance
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState(isDarkMode, snapshot.error.toString());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(isDarkMode, isGroup);
              }

              // Filter conversations based on isGroup
              // Use FutureBuilder to get hidden conversations list
              return FutureBuilder<QuerySnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(currentUserId)
                    .collection('hiddenConversations')
                    .get(),
                builder: (context, hiddenSnapshot) {
                  // While loading hidden conversations, show loading
                  if (!hiddenSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Get set of hidden conversation IDs
                  final hiddenConvIds = hiddenSnapshot.data!.docs
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        return data?['conversationId'] as String?;
                      })
                      .where((id) => id != null)
                      .toSet();

                  final List<ConversationModel> conversations = [];
                  final List<String> userIdsToPrefetch = [];

                  for (var doc in snapshot.data!.docs) {
                    try {
                      final conv = ConversationModel.fromFirestore(doc);

                      // Filter by group or direct chat
                      if (conv.isGroup != isGroup) continue;

                      // Skip if user has hidden this conversation
                      if (hiddenConvIds.contains(conv.id)) {
                        continue; // Skip hidden conversations
                      }

                      // OLD: Also check deletedBy field for backwards compatibility
                      if (conv.isGroup) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedBy = data['deletedBy'] as List<dynamic>?;
                        if (deletedBy != null && deletedBy.contains(currentUserId)) {
                          continue; // Skip this conversation
                        }
                      }

                  if (_searchQuery.isEmpty) {
                    conversations.add(conv);
                  } else {
                    final displayName = conv.getDisplayName(currentUserId);
                    if (displayName.toLowerCase().contains(_searchQuery)) {
                      conversations.add(conv);
                    }
                  }

                  // Collect user IDs for prefetching (only for direct chats)
                  if (!conv.isGroup) {
                    final otherUserId = conv.getOtherParticipantId(
                      currentUserId,
                    );
                    if (otherUserId.isNotEmpty &&
                        !_userCache.containsKey(otherUserId)) {
                      userIdsToPrefetch.add(otherUserId);
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing conversation ${doc.id}: $e');
                }
              }

              // OPTIMIZATION: Prefetch all user data in parallel (non-blocking)
              if (userIdsToPrefetch.isNotEmpty) {
                _prefetchUsers(userIdsToPrefetch);
              }

              // Sort by lastMessageTime (client-side to avoid index requirement)
              conversations.sort((a, b) {
                if (a.lastMessageTime == null) return 1;
                if (b.lastMessageTime == null) return -1;
                return b.lastMessageTime!.compareTo(a.lastMessageTime!);
              });

              if (conversations.isEmpty) {
                return _buildEmptyState(isDarkMode, isGroup);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _buildConversationTile(conversation, isDarkMode);
                },
              );
                },
              ); // Close FutureBuilder
            },
          ),
        ), // Close Expanded
      ], // Close Column children
    ); // Close Column
  }

  Widget _buildCallsList(bool isDarkMode) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please login to see calls'));
    }

    return Column(
      children: [
        // Selection mode header
        if (_isCallSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitCallSelectionMode,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                Text(
                  '${_selectedCallIds.length} selected',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectAllCalls,
                  child: Text(
                    'Select All',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedCallIds.isEmpty
                      ? null
                      : _deleteSelectedCalls,
                ),
              ],
            ),
          )
        else
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getCombinedCallsStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Calls error: ${snapshot.error}');
                  return _buildEmptyCallsState(isDarkMode);
                }

                final allCalls = snapshot.data ?? [];
                if (allCalls.isEmpty) {
                  return _buildEmptyCallsState(isDarkMode);
                }

                // Sort by timestamp (descending)
                allCalls.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp? ??
                               aData['createdAt'] as Timestamp?;
                  final bTime = bData['timestamp'] as Timestamp? ??
                               bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                // Prefetch user data
                _prefetchUserDataForCalls(allCalls, currentUserId);

                // Filter by search
                final filteredCalls = _filterCallsBySearch(allCalls, currentUserId);

                if (filteredCalls.isEmpty) {
                  return _buildEmptyCallsState(isDarkMode);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: filteredCalls.length,
                  itemBuilder: (context, index) {
                    final callDoc = filteredCalls[index];
                    final callData = callDoc.data() as Map<String, dynamic>;
                    final isGroupCall = callData.containsKey('groupId');

                    return _buildCallTileWithDelete(
                      callDoc.id,
                      callData,
                      isDarkMode,
                      currentUserId,
                      isGroupCall: isGroupCall,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Stream<List<DocumentSnapshot>> _getCombinedCallsStream(String currentUserId) {
    // Create a controller to combine both streams
    final controller = StreamController<List<DocumentSnapshot>>();

    final individualCallsStream = _firestore
        .collection('calls')
        .where('participants', arrayContains: currentUserId)
        .limit(50)
        .snapshots();

    final groupCallsStream = _firestore
        .collection('group_calls')
        .where('participants', arrayContains: currentUserId)
        .limit(50)
        .snapshots();

    List<DocumentSnapshot>? lastIndividualCalls;
    List<DocumentSnapshot>? lastGroupCalls;

    // Subscribe to individual calls
    final sub1 = individualCallsStream.listen((snapshot) {
      lastIndividualCalls = snapshot.docs;
      if (lastGroupCalls != null) {
        controller.add([...lastIndividualCalls!, ...lastGroupCalls!]);
      }
    });

    // Subscribe to group calls
    final sub2 = groupCallsStream.listen((snapshot) {
      lastGroupCalls = snapshot.docs;
      if (lastIndividualCalls != null) {
        controller.add([...lastIndividualCalls!, ...lastGroupCalls!]);
      }
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  void _prefetchUserDataForCalls(
    List<DocumentSnapshot> calls,
    String currentUserId,
  ) {
    final userIds = <String>[];
    for (var doc in calls) {
      final data = doc.data() as Map<String, dynamic>;

      if (data.containsKey('groupId')) {
        // Group call - prefetch all participants
        final participants = List<String>.from(data['participants'] ?? []);
        userIds.addAll(participants.where((id) => !_userCache.containsKey(id)));
      } else {
        // Individual call
        final callerId = data['callerId'] as String? ?? '';
        final receiverId = data['receiverId'] as String? ?? '';
        if (callerId != currentUserId && callerId.isNotEmpty) {
          userIds.add(callerId);
        }
        if (receiverId != currentUserId && receiverId.isNotEmpty) {
          userIds.add(receiverId);
        }
      }
    }
    if (userIds.isNotEmpty) {
      _prefetchUsers(userIds);
    }
  }

  List<DocumentSnapshot> _filterCallsBySearch(
    List<DocumentSnapshot> calls,
    String currentUserId,
  ) {
    if (_searchQuery.isEmpty) {
      return calls;
    }

    return calls.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (data.containsKey('groupId')) {
        // Group call - search by group name
        final groupName = data['groupName'] as String? ?? '';
        return groupName.toLowerCase().contains(_searchQuery);
      } else {
        // Individual call - search by contact name
        final callerId = data['callerId'] as String? ?? '';
        final receiverId = data['receiverId'] as String? ?? '';
        final otherUserId = callerId == currentUserId ? receiverId : callerId;
        final userData = _userCache[otherUserId];
        final name = (userData?['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery);
      }
    }).toList();
  }

  void _enterCallSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isCallSelectionMode = true;
      _selectedCallIds.clear();
    });
  }

  void _exitCallSelectionMode() {
    setState(() {
      _isCallSelectionMode = false;
      _selectedCallIds.clear();
    });
  }

  void _toggleCallSelection(String callId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCallIds.contains(callId)) {
        _selectedCallIds.remove(callId);
        if (_selectedCallIds.isEmpty) {
          _isCallSelectionMode = false;
        }
      } else {
        _selectedCallIds.add(callId);
      }
    });
  }

  Future<void> _selectAllCalls() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final snapshot = await _firestore
        .collection('calls')
        .where('participants', arrayContains: currentUserId)
        .limit(50)
        .get();

    setState(() {
      _selectedCallIds.clear();
      for (final doc in snapshot.docs) {
        _selectedCallIds.add(doc.id);
      }
    });
  }

  Future<void> _deleteSelectedCalls() async {
    final confirmed = await _showDeleteCallConfirmation(
      _selectedCallIds.length,
    );
    if (!confirmed) return;

    final batch = _firestore.batch();
    for (final callId in _selectedCallIds) {
      batch.delete(_firestore.collection('calls').doc(callId));
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedCallIds.length} calls deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _exitCallSelectionMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete calls'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSingleCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Conversation selection methods (for Chats and Groups tabs)
  void _enterConversationSelectionMode(String conversationId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isConversationSelectionMode = true;
      _selectedConversationIds.clear();
      _selectedConversationIds.add(conversationId);
    });
  }

  void _exitConversationSelectionMode() {
    setState(() {
      _isConversationSelectionMode = false;
      _selectedConversationIds.clear();
    });
  }

  void _toggleConversationSelection(String conversationId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedConversationIds.contains(conversationId)) {
        _selectedConversationIds.remove(conversationId);
        if (_selectedConversationIds.isEmpty) {
          _isConversationSelectionMode = false;
        }
      } else {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _selectAllConversations(bool isGroup) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final snapshot = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .where('isGroup', isEqualTo: isGroup)
        .limit(50)
        .get();

    setState(() {
      _selectedConversationIds.clear();
      for (final doc in snapshot.docs) {
        _selectedConversationIds.add(doc.id);
      }
    });
  }

  Future<void> _deleteSelectedConversations() async {
    final confirmed = await _showDeleteConversationConfirmation(
      _selectedConversationIds.length,
    );
    if (!confirmed) return;

    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final conversationIds = _selectedConversationIds.toList();

      for (var conversationId in conversationIds) {
        // 1. Delete all messages in subcollection first
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();

        // Batch delete messages (Firestore limit: 500 operations per batch)
        final messageBatches = <WriteBatch>[];
        var currentBatch = _firestore.batch();
        var operationCount = 0;

        for (var messageDoc in messagesSnapshot.docs) {
          currentBatch.delete(messageDoc.reference);
          operationCount++;

          if (operationCount == 500) {
            messageBatches.add(currentBatch);
            currentBatch = _firestore.batch();
            operationCount = 0;
          }
        }

        if (operationCount > 0) {
          messageBatches.add(currentBatch);
        }

        // Commit all message deletion batches
        for (var batch in messageBatches) {
          await batch.commit();
        }

        // 2. Delete conversation document
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .delete();
      }

      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${conversationIds.length} conversation${conversationIds.length > 1 ? 's' : ''} deleted',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _exitConversationSelectionMode();
    } catch (e) {
      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConversationConfirmation(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: Text(
              count == 1
                  ? 'Are you sure you want to delete this conversation? All messages will be permanently deleted.'
                  : 'Are you sure you want to delete $count conversations? All messages will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showDeleteCallConfirmation(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Call'),
            content: Text(
              count == 1
                  ? 'Are you sure you want to delete this call from history?'
                  : 'Are you sure you want to delete $count calls from history?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildCallTileWithDelete(
    String callId,
    Map<String, dynamic> callData,
    bool isDarkMode,
    String currentUserId, {
    bool isGroupCall = false,
  }) {
    final isSelected = _selectedCallIds.contains(callId);

    return Dismissible(
      key: Key(callId),
      direction: _isCallSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteCallConfirmation(1);
      },
      onDismissed: (direction) {
        _deleteSingleCall(callId);
      },
      child: GestureDetector(
        onLongPress: () {
          if (!_isCallSelectionMode) {
            HapticFeedback.mediumImpact();
            _enterCallSelectionMode();
            _toggleCallSelection(callId);
          }
        },
        onTap: () {
          if (_isCallSelectionMode) {
            _toggleCallSelection(callId);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              if (_isCallSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleCallSelection(callId),
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
              Expanded(
                child: _buildCallTileOptimized(
                  callData,
                  isDarkMode,
                  currentUserId,
                  isGroupCall: isGroupCall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Optimized call tile using cached user data (no FutureBuilder inside ListView)
  Widget _buildCallTileOptimized(
    Map<String, dynamic> callData,
    bool isDarkMode,
    String currentUserId, {
    bool isGroupCall = false,
  }) {
    final callerId = callData['callerId'] ?? '';
    final receiverId = callData['receiverId'] ?? '';
    final isOutgoing = callerId == currentUserId;
    final otherUserId = isOutgoing ? receiverId : callerId;
    final callStatus = callData['status'] ?? 'unknown';
    final callType = callData['type'] ?? 'voice';
    final timestamp = callData['timestamp'] as Timestamp?;
    final participants = List<String>.from(callData['participants'] ?? []);

    // Get user data from cache (prefetched earlier)
    final userData = _userCache[otherUserId];
    // Get display name - fallback to phone number for phone login users
    String displayName = userData?['name'] ?? userData?['displayName'] ?? '';
    if (displayName.isEmpty || displayName == 'User') {
      displayName = userData?['phone'] ?? 'Unknown User';
    }
    if (displayName.isEmpty) displayName = 'Unknown User';
    final photoUrl = userData?['photoUrl'];
    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    // Check if it's a group call (more than 2 participants)
    final groupCallCheck = participants.length > 2;
    final finalIsGroupCall = isGroupCall || groupCallCheck;

    // Get group name for group calls
    final groupName = callData['groupName'] as String? ?? 'Group Call';

    // Determine call status icon and color
    IconData statusIcon;
    Color statusColor;

    if (callStatus == 'missed') {
      statusIcon = Icons.call_missed;
      statusColor = Colors.red;
    } else if (callStatus == 'declined') {
      statusIcon = Icons.call_missed_outgoing;
      statusColor = Colors.red;
    } else if (isOutgoing) {
      statusIcon = Icons.call_made;
      statusColor = Colors.green;
    } else {
      statusIcon = Icons.call_received;
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: finalIsGroupCall
            ? _buildGroupAvatarStack(participants, currentUserId)
            : _buildUserAvatar(
                photoUrl: fixedPhotoUrl,
                initial: initial,
                radius: 26,
                context: context,
                uniqueId: otherUserId,
              ),
        title: Text(
          finalIsGroupCall
              ? groupName
              : formatDisplayName(displayName),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                finalIsGroupCall
                    ? '${participants.length} ${participants.length == 1 ? 'person' : 'people'} • ${timestamp != null ? timeago.format(timestamp.toDate()) : 'Unknown time'}'
                    : (timestamp != null
                        ? timeago.format(timestamp.toDate())
                        : 'Unknown time'),
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            callType == 'video' ? Icons.videocam : Icons.call,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => _initiateCall(otherUserId, callType == 'video'),
        ),
        onTap: () => _showCallDetails(
          callData,
          finalIsGroupCall ? groupName : formatDisplayName(displayName),
          isDarkMode,
        ),
      ),
    );
  }

  Widget _buildEmptyCallsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call_outlined,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No calls yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupOldStuckCalls(String currentUserId) async {
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      final oldCalls = await _firestore
          .collection('calls')
          .where('participants', arrayContains: currentUserId)
          .where('status', whereIn: ['calling', 'ringing'])
          .get();

      // End calls that are stuck in calling/ringing state for more than 5 minutes
      final batch = _firestore.batch();
      int cleanedCount = 0;

      for (var doc in oldCalls.docs) {
        final timestamp = doc.data()['timestamp'] as Timestamp?;
        if (timestamp != null && timestamp.toDate().isBefore(fiveMinutesAgo)) {
          batch.update(doc.reference, {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
          });
          cleanedCount++;
          debugPrint('Cleaned up old stuck call: ${doc.id}');
        }
      }

      if (cleanedCount > 0) {
        await batch.commit();
        debugPrint('Cleaned up $cleanedCount old stuck calls');
      }
    } catch (e) {
      debugPrint('Error cleaning up old calls: $e');
      // Continue with call initiation even if cleanup fails
    }
  }

  void _initiateCall(String userId, bool isVideo) async {
    // Prevent video calls (feature disabled)
    if (isVideo) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video calling is not available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Clean up old stuck calls (older than 5 minutes) before starting a new one
      await _cleanupOldStuckCalls(currentUserId);

      // Get current user profile for call details
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';
      final currentUserPhoto = currentUserDoc.data()?['photoUrl'];

      // Get receiver's profile
      final receiverDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!receiverDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final receiverName = receiverDoc.data()?['name'] ?? 'Unknown';
      final receiverPhoto = receiverDoc.data()?['photoUrl'];

      // Check if user already has a recent active call (within last 5 minutes)
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      final activeCallsQuery = await _firestore
          .collection('calls')
          .where('participants', arrayContains: currentUserId)
          .where('status', whereIn: ['calling', 'ringing', 'connected'])
          .limit(5)
          .get();

      // Filter for recent calls only (created in last 5 minutes)
      final recentActiveCalls = activeCallsQuery.docs.where((doc) {
        final timestamp = doc.data()['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(fiveMinutesAgo);
      }).toList();

      if (recentActiveCalls.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active call'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Create call document in Firestore
      final callDoc = await _firestore.collection('calls').add({
        'callerId': currentUserId,
        'receiverId': userId,
        'callerName': currentUserName,
        'callerPhoto': currentUserPhoto,
        'receiverName': receiverName,
        'receiverPhoto': receiverPhoto,
        'participants': [currentUserId, userId],
        'status': 'calling',
        'type': 'audio',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Get receiver's profile for navigation
      final receiverProfile = UserProfile.fromMap(receiverDoc.data()!, userId);

      // Send call notification to receiver (fire and forget)
      NotificationService().sendNotificationToUser(
        userId: userId,
        title: 'Incoming Call',
        body: '$currentUserName is calling you',
        type: 'call',
        data: {
          'callId': callDoc.id,
          'callerId': currentUserId,
          'callerName': currentUserName,
          'callerPhoto': currentUserPhoto,
        },
      );

      // Navigate to voice call screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            callId: callDoc.id,
            otherUser: receiverProfile,
            isOutgoing: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error initiating call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showCallDetails(
    Map<String, dynamic> callData,
    String displayName,
    bool isDarkMode,
  ) {
    final timestamp = callData['timestamp'] as Timestamp?;
    final duration = callData['duration'] ?? 0;
    final callStatus = callData['status'] ?? 'unknown';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildCallDetailRow(
              'Status',
              callStatus.toString().toUpperCase(),
              isDarkMode,
            ),
            _buildCallDetailRow(
              'Time',
              timestamp != null
                  ? _formatCallTime(timestamp.toDate())
                  : 'Unknown',
              isDarkMode,
            ),
            if (duration > 0)
              _buildCallDetailRow(
                'Duration',
                _formatDuration(duration),
                isDarkMode,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCallDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCallTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDate = DateTime(time.year, time.month, time.day);

    String timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (callDate == today) {
      return 'Today, $timeStr';
    } else if (callDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else {
      return '${time.day}/${time.month}/${time.year}, $timeStr';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes min ${secs}s';
    }
    return '${secs}s';
  }

  Widget _buildConversationTile(
    ConversationModel conversation,
    bool isDarkMode,
  ) {
    final currentUserId = _auth.currentUser!.uid;
    final otherUserId = conversation.getOtherParticipantId(currentUserId);

    if (otherUserId.isEmpty && !conversation.isGroup) {
      return const SizedBox.shrink();
    }

    String displayName = conversation.getDisplayName(currentUserId);
    String? displayPhoto = conversation.getDisplayPhoto(currentUserId);
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final isTyping = conversation.isUserTyping(otherUserId);

    // For groups, show group icon
    if (conversation.isGroup) {
      return _buildConversationTileContent(
        conversation: conversation,
        otherUserId: '',
        displayName: conversation.groupName ?? 'Group',
        displayPhoto: displayPhoto,
        unreadCount: unreadCount,
        isTyping: false,
        isDarkMode: isDarkMode,
      );
    }

    // Try to get user data from cache first
    if (otherUserId.isNotEmpty && _userCache.containsKey(otherUserId)) {
      final cachedUser = _userCache[otherUserId]!;
      if (displayName == 'Unknown User') {
        // Get display name - fallback to phone number for phone login users
        String cachedName =
            cachedUser['name'] ?? cachedUser['displayName'] ?? '';
        if (cachedName.isEmpty || cachedName == 'User') {
          cachedName = cachedUser['phone'] ?? 'Unknown User';
        }
        displayName = cachedName.isNotEmpty ? cachedName : 'Unknown User';
      }
      displayPhoto ??= cachedUser['photoUrl'];
    }

    // Fetch user details if name is unknown (with caching)
    if (displayName == 'Unknown User' && otherUserId.isNotEmpty) {
      // Trigger async fetch without blocking UI
      _getUserWithCache(otherUserId).then((userData) {
        if (mounted && userData != null) {
          setState(() {}); // Refresh to show cached data
        }
      });
    }

    return _buildConversationTileContent(
      conversation: conversation,
      otherUserId: otherUserId,
      displayName: displayName,
      displayPhoto: displayPhoto,
      unreadCount: unreadCount,
      isTyping: isTyping,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildConversationTileContent({
    required ConversationModel conversation,
    required String otherUserId,
    required String displayName,
    String? displayPhoto,
    required int unreadCount,
    required bool isTyping,
    required bool isDarkMode,
  }) {
    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(displayPhoto);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final isSelected = _selectedConversationIds.contains(conversation.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_isConversationSelectionMode) {
              _toggleConversationSelection(conversation.id);
            } else {
              _openConversation(conversation, otherUserId);
            }
          },
          onLongPress: () {
            if (!_isConversationSelectionMode) {
              _enterConversationSelectionMode(conversation.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox for selection mode
                if (_isConversationSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white.withValues(alpha: 0.5),
                      size: 24,
                    ),
                  ),
                // Avatar
                Stack(
                  children: [
                    conversation.isGroup
                        ? CircleAvatar(
                            radius: 26,
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.group,
                              color: Theme.of(context).primaryColor,
                              size: 26,
                            ),
                          )
                        : _buildUserAvatar(
                            photoUrl: fixedPhotoUrl,
                            initial: initial,
                            radius: 26,
                            context: context,
                            uniqueId: conversation.id,
                          ),
                    // Online indicator for direct chats
                    if (!conversation.isGroup && otherUserId.isNotEmpty)
                      _buildOnlineIndicator(otherUserId, isDarkMode),
                  ],
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              formatDisplayName(displayName),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.lastMessageTime != null)
                            Text(
                              timeago.format(conversation.lastMessageTime!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Message preview with voice message indicator
                          if (conversation.lastMessage?.contains(
                                'Voice message',
                              ) ==
                              true)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.mic,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              isTyping
                                  ? 'Typing...'
                                  : conversation.lastMessage ??
                                        'Start a conversation',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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
  }

  /// Build group avatar stack showing multiple participants
  Widget _buildGroupAvatarStack(List<String> participants, String currentUserId) {
    // Get up to 4 other participants (excluding current user)
    final otherParticipants = participants
        .where((id) => id != currentUserId)
        .take(4)
        .toList();

    const avatarSize = 22.0;
    const stackRadius = 26.0;

    return SizedBox(
      width: stackRadius * 2,
      height: stackRadius * 2,
      child: Stack(
        children: List.generate(otherParticipants.length, (index) {
          final userId = otherParticipants[index];
          final userData = _userCache[userId];
          final name = userData?['name'] ?? 'U';
          final photoUrl = userData?['photoUrl'];
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

          // Position avatars in a 2x2 grid for up to 4 participants
          final row = index ~/ 2;
          final col = index % 2;
          final offsetX = col == 0 ? 0.0 : stackRadius;
          final offsetY = row == 0 ? 0.0 : stackRadius;

          return Positioned(
            left: offsetX,
            top: offsetY,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: PhotoUrlHelper.fixGooglePhotoUrl(photoUrl) ?? photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Build user avatar with proper error handling for profile photos
  Widget _buildUserAvatar({
    required String? photoUrl,
    required String initial,
    required double radius,
    required BuildContext context,
    String? uniqueId,
  }) {
    // Avatar colors for fallback - expanded palette for more variety
    const List<Color> avatarColors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
      Color(0xFFEF4444), // Red
      Color(0xFFF97316), // Orange
      Color(0xFF22C55E), // Green
      Color(0xFF14B8A6), // Teal
      Color(0xFF06B6D4), // Cyan
      Color(0xFF3B82F6), // Blue
      Color(0xFFA855F7), // Violet
      Color(0xFFF43F5E), // Rose
      Color(0xFF10B981), // Emerald
      Color(0xFF0EA5E9), // Sky
      Color(0xFF6D28D9), // Deep Purple
      Color(0xFFD946EF), // Fuchsia
    ];

    // Use uniqueId (userId) for color generation if available, otherwise fall back to initial
    int colorIndex;
    if (uniqueId != null && uniqueId.isNotEmpty) {
      // Generate hash from uniqueId for consistent but unique colors per user
      int hash = 0;
      for (int i = 0; i < uniqueId.length; i++) {
        hash = uniqueId.codeUnitAt(i) + ((hash << 5) - hash);
      }
      colorIndex = hash.abs() % avatarColors.length;
    } else {
      colorIndex = initial.isNotEmpty
          ? initial.codeUnitAt(0) % avatarColors.length
          : 0;
    }
    final avatarColor = avatarColors[colorIndex];

    Widget buildFallback() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(shape: BoxShape.circle, color: avatarColor),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (photoUrl == null || photoUrl.isEmpty) {
      return buildFallback();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => buildFallback(),
        errorWidget: (context, url, error) => buildFallback(),
      ),
    );
  }

  Widget _buildOnlineIndicator(String userId, bool isDarkMode) {
    // Check cache first for quick render without stream
    bool isOnlineFromCache = false;
    if (_userCache.containsKey(userId)) {
      final userData = _userCache[userId]!;
      final showOnlineStatus = userData['showOnlineStatus'] ?? true;
      if (showOnlineStatus) {
        isOnlineFromCache = userData['isOnline'] ?? false;
        if (isOnlineFromCache) {
          final lastSeen = userData['lastSeen'];
          if (lastSeen != null && lastSeen is Timestamp) {
            final difference = DateTime.now().difference(lastSeen.toDate());
            if (difference.inMinutes > 5) {
              isOnlineFromCache = false;
            }
          } else {
            isOnlineFromCache = false;
          }
        }
      }
    }

    // Return cached result immediately if available
    if (_userCache.containsKey(userId)) {
      if (!isOnlineFromCache) return const SizedBox.shrink();
      return Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode ? Colors.black : Colors.white,
              width: 2,
            ),
          ),
        ),
      );
    }

    // Only use stream if not cached (first load)
    return Positioned(
      right: 0,
      bottom: 0,
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          bool isOnline = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            // Update cache
            _userCache[userId] = userData;

            final showOnlineStatus = userData['showOnlineStatus'] ?? true;

            if (showOnlineStatus) {
              isOnline = userData['isOnline'] ?? false;
              if (isOnline) {
                final lastSeen = userData['lastSeen'];
                if (lastSeen != null && lastSeen is Timestamp) {
                  final difference = DateTime.now().difference(
                    lastSeen.toDate(),
                  );
                  if (difference.inMinutes > 5) {
                    isOnline = false;
                  }
                } else {
                  isOnline = false;
                }
              }
            }
          }

          if (!isOnline) return const SizedBox.shrink();

          return Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? Colors.black : Colors.white,
                width: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openConversation(
    ConversationModel conversation,
    String otherUserId,
  ) async {
    HapticFeedback.lightImpact();

    if (conversation.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(
            groupId: conversation.id,
            groupName: conversation.groupName ?? 'Group',
          ),
        ),
      );
      return;
    }

    // OPTIMIZATION: Use cached user data first for instant navigation
    if (_userCache.containsKey(otherUserId)) {
      final cachedData = _userCache[otherUserId]!;
      final otherUser = UserProfile.fromMap(cachedData, otherUserId);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedChatScreen(
            otherUser: otherUser,
            chatId: conversation.id, // Pass chatId to avoid another query
          ),
        ),
      );
      return;
    }

    // Fallback: Fetch from Firestore if not in cache
    try {
      final otherUserDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      if (otherUserDoc.exists) {
        final userData = otherUserDoc.data()!;
        // Cache for future use
        _userCache[otherUserId] = userData;

        final otherUser = UserProfile.fromMap(userData, otherUserId);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedChatScreen(
              otherUser: otherUser,
              chatId: conversation.id, // Pass chatId to avoid another query
            ),
          ),
        );
      } else {
        // User no longer exists - delete orphaned conversation
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This conversation is no longer available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Widget _buildEmptyState(bool isDarkMode, bool isGroup) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGroup ? Icons.group_outlined : Icons.chat_bubble_outline,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isGroup ? 'No groups yet' : 'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGroup
                ? 'Create a group to get started'
                : 'Start a new conversation',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Unable to load',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _createGroup() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    if (result != null && result is String) {
      _openGroupChat(result);
    }
  }

  void _openGroupChat(String groupId) async {
    try {
      final groupDoc = await _firestore
          .collection('conversations')
          .doc(groupId)
          .get();
      if (groupDoc.exists) {
        final data = groupDoc.data()!;
        if (data['isGroup'] == true) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: groupId,
                groupName: data['groupName'] ?? 'Group',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening group: $e');
    }
  }

  void _showNewChatDialog() {
    HapticFeedback.lightImpact();
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;

          return AppBackground(
            showParticles: true,
            overlayOpacity: 0.6,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Message',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildContactsList(
                      currentUserId,
                      scrollController,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactsList(
    String currentUserId,
    ScrollController scrollController,
    bool isDarkMode,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .where('isGroup', isEqualTo: false)
          .snapshots(),
      builder: (context, convSnapshot) {
        if (convSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!convSnapshot.hasData || convSnapshot.data!.docs.isEmpty) {
          return _buildEmptyContactsState(isDarkMode);
        }

        final Set<String> otherUserIds = {};
        for (var doc in convSnapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          for (var participant in participants) {
            if (participant != currentUserId) {
              otherUserIds.add(participant);
            }
          }
        }

        if (otherUserIds.isEmpty) {
          return _buildEmptyContactsState(isDarkMode);
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            otherUserIds.map(
              (id) => _firestore.collection('users').doc(id).get(),
            ),
          ),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!usersSnapshot.hasData) {
              return const Center(child: Text('Error loading contacts'));
            }

            final validUsers = usersSnapshot.data!
                .where((doc) => doc.exists)
                .toList();

            if (validUsers.isEmpty) {
              return _buildEmptyContactsState(isDarkMode);
            }

            return ListView.builder(
              controller: scrollController,
              itemCount: validUsers.length,
              itemBuilder: (context, index) {
                final userDoc = validUsers[index];
                final userData = userDoc.data() as Map<String, dynamic>;
                final userId = userDoc.id;

                return _buildContactTile(userData, userId, isDarkMode);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContactTile(
    Map<String, dynamic> userData,
    String userId,
    bool isDarkMode,
  ) {
    final name = userData['name'] ?? 'Unknown';
    final photoUrl = userData['photoUrl'];
    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Properly validate online status with lastSeen check
    bool isOnline = false;
    final showOnlineStatus = userData['showOnlineStatus'] ?? true;
    if (showOnlineStatus && userData['isOnline'] == true) {
      final lastSeen = userData['lastSeen'];
      if (lastSeen != null && lastSeen is Timestamp) {
        final difference = DateTime.now().difference(lastSeen.toDate());
        // Only show as online if lastSeen within 5 minutes
        isOnline = difference.inMinutes <= 5;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.pop(context);
            final userProfile = UserProfile.fromMap(userData, userId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EnhancedChatScreen(otherUser: userProfile),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    _buildUserAvatar(
                      photoUrl: fixedPhotoUrl,
                      initial: initial,
                      radius: 26,
                      context: context,
                      uniqueId: userId,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDisplayName(name),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOnline ? 'Active now' : 'Tap to message',
                        style: TextStyle(
                          fontSize: 14,
                          color: isOnline
                              ? Colors.green
                              : Colors.white.withValues(alpha: 0.7),
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
  }

  Widget _buildEmptyContactsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start chatting with people from Home or Live Connect',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[600] : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
