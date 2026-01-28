import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/config/app_assets.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../models/user_profile.dart';
import '../../models/business_model.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../models/message_model.dart';
import '../../services/notification_service.dart';
import '../../services/chat services/conversation_service.dart';
import '../../services/hybrid_chat_service.dart';
import '../../services/active_chat_service.dart';
import '../../providers/other providers/app_providers.dart';
import '../call/voice_call_screen.dart';
// import '../call/video_call_screen.dart'; // Video calling disabled
import '../../res/utils/snackbar_helper.dart';
import '../../widgets/chat_common.dart';
import '../home/main_navigation_screen.dart';
import 'media_gallery_screen.dart';

class EnhancedChatScreen extends ConsumerStatefulWidget {
  final UserProfile otherUser;
  final String? initialMessage;
  final String? chatId; // Optional chatId from Live Connect
  final bool isBusinessChat; // Whether this is a business conversation
  final BusinessModel? business; // Business info if it's a business chat

  const EnhancedChatScreen({
    super.key,
    required this.otherUser,
    this.initialMessage,
    this.chatId, // Accept chatId from Live Connect
    this.isBusinessChat = false,
    this.business,
  });

  @override
  ConsumerState<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends ConsumerState<EnhancedChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ConversationService _conversationService = ConversationService();
  final HybridChatService _hybridChatService = HybridChatService();
  final ActiveChatService _activeChatService = ActiveChatService();

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);

  // Cached user ID for use during dispose (when ref is no longer available)
  String? _cachedUserId;

  String? _conversationId;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  Timer? _typingTimer;
  MessageModel? _replyToMessage;
  MessageModel? _editingMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showScrollButton = false;
  final int _unreadCount = 0;

  // Search related variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<MessageModel> _searchResults = [];
  int _currentSearchIndex = 0;
  List<MessageModel> _allMessages = [];

  // Pagination variables
  static const int _messagesPerPage = 20;
  final List<DocumentSnapshot> _loadedMessages = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // Single stream for user status (avoid duplicate queries)
  Stream<DocumentSnapshot>? _userStatusStream;

  // Daily media counters (SharedPreferences-based, same as group chat)
  int _todayImageCount = 0;
  int _todayVideoCount = 0;
  int _todayAudioCount = 0;
  DateTime? _lastMediaCountReset;
  bool _isMediaOperationInProgress =
      false; // Lock to prevent concurrent operations
  bool _isCounterLoaded =
      false; // Track if counter has been loaded from SharedPreferences
  bool _isCounterLoading = false; // Prevent concurrent counter loads

  // Voice recording variables - lazy initialized to prevent crashes
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Video recording flag to prevent multiple simultaneous recordings
  bool _isRecordingVideo = false;

  // Call state flags to prevent multiple simultaneous calls
  bool _isStartingCall = false;

  // Chat theme
  String _selectedTheme = 'default';

  // Multi-select mode for bulk delete
  bool _isMultiSelectMode = false;
  final Set<String> _selectedMessageIds = {};

  // Voice playback variables - lazy initialized to prevent crashes
  FlutterSoundPlayer? _audioPlayer;
  bool _isPlayerInitialized = false;
  String? _currentlyPlayingMessageId;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  StreamSubscription? _playerSubscription;

  // Optimistic messages (shown immediately before server confirms)
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Mention functionality
  bool _showMentionSuggestions = false;
  List<Map<String, dynamic>> _filteredUsers = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();

    debugPrint('🚀 ========== ENHANCED CHAT SCREEN OPENED ==========');
    debugPrint(
      '🚀 Chat with: ${widget.otherUser.name} (${widget.otherUser.uid})',
    );
    debugPrint('🚀 Current time: ${DateTime.now()}');

    try {
      // Cache user ID for use during dispose
      _cachedUserId = ref.read(currentUserIdProvider);
      debugPrint('🚀 Cached UserId: $_cachedUserId');

      // Initialize single user status stream
      _userStatusStream = _firestore
          .collection('users')
          .doc(widget.otherUser.uid)
          .snapshots();

      WidgetsBinding.instance.addObserver(this);

      // Initialize conversation IMMEDIATELY for faster loading
      _initializeConversation();

      // Set this chat as active to suppress notifications (WhatsApp-style)
      _activeChatService.setActiveChat(
        conversationId: _conversationId,
        userId: widget.otherUser.uid,
      );

      _setupAnimations();
      _scrollController.addListener(_scrollListener);

      // Initialize daily media counter with retry mechanism
      _initializeCounterWithRetry();

      // Defer non-critical tasks to after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        try {
          _markMessagesAsRead();

          // If there's an initial message, set it in the message controller
          if (widget.initialMessage != null) {
            _messageController.text = widget.initialMessage!;
            FocusScope.of(context).requestFocus(_messageFocusNode);
          }

          // Listen for incoming messages for sound/vibration feedback
          _listenForIncomingMessages();

          // Sync messages from Firebase to local database in background (low priority)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _syncMessagesInBackground();
              _cleanupEmptyCallMessages(); //   Remove empty call messages
            }
          });
        } catch (e) {
          // Error in post frame callback
        }
      });
    } catch (e) {
      // Error in initState
    }
  }

  void _listenForIncomingMessages() {
    // Add a slight delay to avoid triggering on initial load
    Future.delayed(const Duration(seconds: 2), () {
      if (_conversationId != null && mounted) {
        // Simplified query without compound where clause to avoid index requirement
        _firestore
            .collection('conversations')
            .doc(_conversationId!)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots()
            .listen(
              (snapshot) {
                if (snapshot.docs.isNotEmpty &&
                    mounted &&
                    _currentUserId != null) {
                  final latestMessage = snapshot.docs.first.data();
                  // Check if it's an incoming message in memory
                  if (latestMessage['receiverId'] == _currentUserId &&
                      latestMessage['senderId'] != _currentUserId) {
                    HapticFeedback.mediumImpact();
                  }
                }
              },
              onError: (error) {
                // Silently handle any errors
                debugPrint('Error listening for messages: $error');
              },
            );
      }
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  void _scrollListener() {
    // Debounce scroll events to reduce rebuilds
    if (!_scrollController.hasClients) return;

    final shouldShow = _scrollController.position.pixels > 500;
    if (shouldShow != _showScrollButton) {
      setState(() => _showScrollButton = shouldShow);
    }

    // Load more messages when user scrolls near the top (pagination)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (_hasMoreMessages && !_isLoadingMore && !_isSearching) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _conversationId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_messagesPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _loadedMessages.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _hasMoreMessages = snapshot.docs.length == _messagesPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _initializeConversation() async {
    try {
      // If chatId is provided from Live Connect, use it directly
      // Otherwise, use ConversationService to get or create conversation
      final conversationId =
          widget.chatId ??
          await _conversationService.getOrCreateConversation(widget.otherUser);

      if (mounted) {
        setState(() {
          _conversationId = conversationId;
        });
        // Load chat theme after conversation is initialized
        _loadThemeFromFirestore();

        //   Clean up empty/duplicate call messages immediately after conversation is initialized
        _cleanupEmptyCallMessages();

        //   Set up real-time guard against empty messages
        _setupEmptyMessageGuard();
      }
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading conversation: $e');
      }
    }
  }

  @override
  void dispose() {
    // Clear active chat status to re-enable notifications (WhatsApp-style)
    _activeChatService.clearActiveChat();

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}

    try {
      _messageController.dispose();
    } catch (_) {}

    try {
      _messageFocusNode.dispose();
    } catch (_) {}

    try {
      _scrollController.dispose();
    } catch (_) {}

    _typingTimer?.cancel();

    try {
      _animationController.dispose();
    } catch (_) {}

    try {
      _searchController.dispose();
    } catch (_) {}

    try {
      _searchFocusNode.dispose();
    } catch (_) {}

    // Dispose audio recorder safely
    _recordingTimer?.cancel();
    try {
      if (_isRecorderInitialized && _audioRecorder != null) {
        _audioRecorder?.closeRecorder();
      }
    } catch (_) {}

    // Dispose audio player safely
    _playerSubscription?.cancel();
    try {
      if (_isPlayerInitialized && _audioPlayer != null) {
        _audioPlayer?.closePlayer();
      }
    } catch (_) {}

    // Update typing status directly without using ref (which is disposed)
    _clearTypingStatusOnDispose();
    super.dispose();
  }

  void _clearTypingStatusOnDispose() {
    // Only clear if we have both conversation and user IDs cached
    if (_conversationId == null || _cachedUserId == null) return;

    _firestore
        .collection('conversations')
        .doc(_conversationId!)
        .update({'isTyping.$_cachedUserId': false})
        .catchError((_) {
          // Ignore errors during dispose
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(isDarkMode),
        body: Stack(
          children: [
            // Default background - always shows (for default theme)
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeBackgroundImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Dark overlay - always shows (for default theme)
            Positioned.fill(
              child: Container(color: AppColors.darkOverlay(alpha: 0.6)),
            ),

            // Main content
            SafeArea(
              bottom:
                  false, // Remove bottom padding to eliminate space below input
              child: Column(
                children: [
                  if (_isSearching) _buildSearchResultsBar(isDarkMode),
                  Expanded(
                    child: Container(
                      // Theme-based background for middle area only
                      decoration: _selectedTheme != 'default'
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  (chatThemeColors[_selectedTheme] ??
                                          chatThemeColors['default']!)
                                      .first
                                      .withValues(alpha: 0.3),
                                  (chatThemeColors[_selectedTheme] ??
                                          chatThemeColors['default']!)
                                      .last
                                      .withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            )
                          : null, // No decoration for default theme (shows bg image)
                      child: Stack(
                        children: [
                          _buildMessagesList(isDarkMode),
                          if (_showScrollButton) _buildScrollToBottomButton(),
                        ],
                      ),
                    ),
                  ),
                  if (!_isMultiSelectMode && _replyToMessage != null)
                    _buildReplyPreview(isDarkMode),
                  if (!_isMultiSelectMode && _editingMessage != null)
                    _buildEditPreview(isDarkMode),
                  if (!_isMultiSelectMode) _buildTypingIndicator(isDarkMode),
                  // Mention suggestions (appears above input)
                  if (!_isMultiSelectMode && _showMentionSuggestions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildMentionSuggestions(),
                    ),
                  if (!_isMultiSelectMode) _buildMessageInput(isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    // Multi-select mode AppBar
    if (_isMultiSelectMode) {
      return AppBar(
        backgroundColor: Colors.blue.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          onPressed: _exitMultiSelectMode,
        ),
        title: Text(
          '${_selectedMessageIds.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Forward button
          IconButton(
            icon: const Icon(Icons.forward, color: Colors.white),
            onPressed: _selectedMessageIds.isNotEmpty
                ? _forwardSelectedMessages
                : null,
            tooltip: 'Forward',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _selectedMessageIds.isNotEmpty
                ? _deleteSelectedMessages
                : null,
            tooltip: 'Delete',
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
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
              Color(0x66000000), // Fixed black with 40% opacity
              Color(0x33000000), // Fixed black with 20% opacity
              Color(0x00000000), // Transparent
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: const Color(0x4DFFFFFF), // Fixed white with 30% opacity
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDarkMode ? Colors.white : AppColors.iosBlue,
          size: 22,
        ),
        onPressed: () {
          if (_isSearching) {
            _toggleSearch();
          } else {
            // Navigate to messages screen (conversations screen)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) =>
                    const MainNavigationScreen(initialIndex: 1),
              ),
              (route) => false,
            );
          }
        },
      ),
      title: _isSearching
          ? _buildSearchField(isDarkMode)
          : Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            PhotoUrlHelper.isValidUrl(
                              widget.otherUser.profileImageUrl,
                            )
                            ? CachedNetworkImageProvider(
                                widget.otherUser.profileImageUrl!,
                              )
                            : null,
                        child:
                            !PhotoUrlHelper.isValidUrl(
                              widget.otherUser.profileImageUrl,
                            )
                            ? Text(
                                widget.otherUser.name.isNotEmpty
                                    ? widget.otherUser.name[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _userStatusStream,
                      builder: (context, snapshot) {
                        bool isOnline = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final showOnlineStatus =
                              userData['showOnlineStatus'] ?? true;

                          // Only show online if user allows it and they're actually online
                          if (showOnlineStatus) {
                            isOnline = userData['isOnline'] ?? false;

                            // Check if lastSeen is recent
                            if (isOnline) {
                              final lastSeen = userData['lastSeen'];
                              if (lastSeen != null && lastSeen is Timestamp) {
                                final lastSeenTime = lastSeen.toDate();
                                final difference = DateTime.now().difference(
                                  lastSeenTime,
                                );
                                // Consider offline if last seen more than 5 minutes ago
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

                        return Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode
                                    ? AppColors.darkCard
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.otherUser.name.isNotEmpty
                                  ? widget.otherUser.name
                                  : 'Unknown User',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Business badge indicator
                          if (widget.isBusinessChat) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00D67D,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00D67D,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Color(0xFF00D67D),
                                    size: 10,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Business',
                                    style: TextStyle(
                                      color: Color(0xFF00D67D),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _conversationId != null
                            ? _firestore
                                  .collection('conversations')
                                  .doc(_conversationId!)
                                  .snapshots()
                            : const Stream.empty(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            final isTyping =
                                data['isTyping']?[widget.otherUser.uid] ??
                                false;

                            if (isTyping) {
                              return Text(
                                'Typing...',
                                style: AppTextStyles.caption.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                          }

                          return StreamBuilder<DocumentSnapshot>(
                            stream: _userStatusStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData =
                                    snapshot.data!.data()
                                        as Map<String, dynamic>;
                                final showOnlineStatus =
                                    userData['showOnlineStatus'] ?? true;

                                if (!showOnlineStatus) {
                                  return Text(
                                    'Status hidden',
                                    style: AppTextStyles.caption.copyWith(
                                      color: isDarkMode
                                          ? Colors.grey[600]
                                          : Colors.grey,
                                    ),
                                  );
                                }

                                var isOnline = userData['isOnline'] ?? false;

                                // Check if lastSeen is recent
                                if (isOnline) {
                                  final lastSeen = userData['lastSeen'];
                                  if (lastSeen != null &&
                                      lastSeen is Timestamp) {
                                    final lastSeenTime = lastSeen.toDate();
                                    final difference = DateTime.now()
                                        .difference(lastSeenTime);
                                    // Consider offline if last seen more than 5 minutes ago
                                    if (difference.inMinutes > 5) {
                                      isOnline = false;
                                    }
                                  } else {
                                    isOnline = false;
                                  }
                                }

                                if (isOnline) {
                                  return Text(
                                    'Active now',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.green,
                                    ),
                                  );
                                } else if (userData['lastSeen'] != null) {
                                  final lastSeen =
                                      (userData['lastSeen'] as Timestamp)
                                          .toDate();
                                  return Text(
                                    'Active ${timeago.format(lastSeen)}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: isDarkMode
                                          ? Colors.grey[600]
                                          : Colors.grey,
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        if (!_isSearching) ...[
          // Video call button
          IconButton(
            icon: Icon(
              Icons.videocam_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
          ),
          // Audio call button (voice only)
          IconButton(
            icon: Icon(
              Icons.call_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startAudioCall,
            tooltip: 'Voice Call',
          ),
        ],
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.more_vert_rounded,
            color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
            size: 24,
          ),
          onPressed: _isSearching ? _toggleSearch : _showChatInfo,
        ),
      ],
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    if (_conversationId == null) {
      // Show minimal loading state instead of profile icon
      return const Center(child: SizedBox.shrink());
    }

    // Use StreamBuilder for real-time updates from Firebase with pagination
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_messagesPerPage)
          .snapshots(),
      builder: (context, snapshot) {
        // Show nothing while loading - prevents profile icon flash
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allMessages.isEmpty) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.red[400]),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyChatState(isDarkMode);
        }

        // Convert Firestore documents to MessageModel
        // Filter out messages deleted for current user (WhatsApp-style "Delete for me")
        // Also filter out videos/images that are still uploading (status == sending) for receivers
        final currentUserId = _currentUserId;
        final messages = snapshot.data!.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Check if message is deleted for current user
              final deletedFor = data['deletedFor'] as List<dynamic>?;
              if (deletedFor != null && currentUserId != null) {
                return !deletedFor.contains(currentUserId);
              }

              //   Filter out empty/invalid call messages to prevent blank UI
              final messageTypeEnum = _parseMessageType(data['type']);
              if (messageTypeEnum == MessageType.voiceCall ||
                  messageTypeEnum == MessageType.videoCall ||
                  messageTypeEnum == MessageType.missedCall) {
                final text = data['text'] as String?;
                final timestamp = data['timestamp'];
                final callId = data['callId'] as String?;

                // Debug: Print all call message data
                debugPrint(
                  '  Call message found: id=${doc.id}, text="$text", callId=$callId, hasTimestamp=${timestamp != null}',
                );

                // Filter out messages with empty text OR null timestamp
                if (text == null || text.isEmpty || text.trim().isEmpty) {
                  debugPrint(
                    '  Filtering out empty call message: ${doc.id}, text="$text"',
                  );
                  return false; // Skip empty call messages
                }

                // Also filter out call messages with null/invalid timestamp (incomplete saves)
                if (timestamp == null) {
                  debugPrint(
                    '  Filtering out call message with null timestamp: ${doc.id}',
                  );
                  return false;
                }
              }

              // Hide videos/images that are still uploading from receiver
              // Only show uploading media to the sender
              final senderId = data['senderId'] as String?;
              final messageStatusEnum = _parseMessageStatusFromInt(
                data['status'],
              );
              final mediaUrl = data['mediaUrl'] as String?;

              // If this is a video or image message
              if (messageTypeEnum == MessageType.video ||
                  messageTypeEnum == MessageType.image) {
                // If status is 'sending' or mediaUrl is empty, only sender should see it
                if (messageStatusEnum == MessageStatus.sending ||
                    (mediaUrl == null || mediaUrl.isEmpty)) {
                  // Only show to sender
                  if (senderId != currentUserId) {
                    return false; // Hide from receiver
                  }
                }
              }

              // FILTER OUT GROUP MESSAGES FROM 1-ON-1 CHATS
              // Hide group-related messages that shouldn't appear in 1-on-1 chats
              final text = data['text'] as String?;
              final actionType = data['actionType'] as String?;
              final isSystemMessage = data['isSystemMessage'] as bool?;
              final callId = data['callId'] as String?;
              final groupId = data['groupId'] as String?;

              // Filter 1: System messages (typically group-related)
              if (isSystemMessage == true) {
                debugPrint('  Filtering out system message from 1-on-1 chat');
                return false;
              }

              // Filter 2: Messages with groupId field (definitely group-related)
              if (groupId != null && groupId.isNotEmpty) {
                debugPrint(
                  '  Filtering out message with groupId from 1-on-1 chat: $groupId',
                );
                return false;
              }

              // Filter 3: Group call messages (callId starting with "group_")
              if (callId != null && callId.startsWith('group_')) {
                debugPrint(
                  '  Filtering out group call message from 1-on-1 chat: callId=$callId',
                );
                return false;
              }

              // Filter 4: Text-based filtering for group-related keywords
              if (text != null) {
                final lowerText = text.toLowerCase();

                // List of group-related keywords
                final groupKeywords = [
                  'group created',
                  'joined the group',
                  'left the group',
                  'added you',
                  'removed from',
                  'group call',
                  'joined', // Group calls have "joined" count
                  'participants',
                ];

                for (final keyword in groupKeywords) {
                  if (lowerText.contains(keyword)) {
                    debugPrint(
                      '  Filtering out message with keyword "$keyword": $text',
                    );
                    return false;
                  }
                }

                // Special case: Call messages with "joined" (group-specific)
                if (actionType == 'call' && lowerText.contains('joined')) {
                  debugPrint(
                    '  Filtering out group call message from 1-on-1 chat: $text',
                  );
                  return false;
                }
              }

              return true;
            })
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isDeleted = data['isDeleted'] == true;
              return MessageModel(
                id: doc.id,
                senderId: data['senderId'] as String? ?? '',
                receiverId: data['receiverId'] as String? ?? '',
                chatId: _conversationId!,
                text: data['text'] as String?,
                mediaUrl: isDeleted
                    ? null
                    : (data['mediaUrl'] as String? ??
                          data['imageUrl'] as String?),
                localPath:
                    data['localPath']
                        as String?, // For WhatsApp-style preview during upload
                audioUrl: isDeleted ? null : data['audioUrl'] as String?,
                audioDuration: _parseIntFromDynamic(data['audioDuration']),
                timestamp: data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp).toDate()
                    : DateTime.now(),
                status: _parseMessageStatusFromInt(
                  data['status'],
                  isRead: data['read'] == true || data['isRead'] == true,
                ),
                type: _parseMessageType(data['type']),
                replyToMessageId: data['replyToMessageId'] as String?,
                isEdited: data['isEdited'] ?? false,
                isDeleted: isDeleted,
                reactions: data['reactions'] != null
                    ? List<String>.from(data['reactions'])
                    : null,
                metadata: data['uploadProgress'] != null
                    ? {'uploadProgress': data['uploadProgress']}
                    : null,
              );
            })
            .toList();

        // Update _allMessages after build using post-frame callback to avoid state mutation in build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _allMessages.length != messages.length) {
            _allMessages = List.from(messages);
          }
        });

        // Combine optimistic messages (newest) with real messages
        final allDisplayMessages = <MessageModel>[
          // Convert optimistic messages to MessageModel
          ..._optimisticMessages.map((optimisticData) {
            return MessageModel(
              id: optimisticData['id'] as String,
              senderId: optimisticData['senderId'] as String,
              receiverId: optimisticData['receiverId'] as String,
              chatId: _conversationId!,
              text: optimisticData['text'] as String? ?? '',
              mediaUrl:
                  optimisticData['imageUrl'] as String? ??
                  optimisticData['videoUrl'] as String?,
              audioUrl: optimisticData['voiceUrl'] as String?,
              audioDuration: optimisticData['voiceDuration'] as int?,
              timestamp: (optimisticData['timestamp'] as Timestamp).toDate(),
              status: MessageStatus.sending,
              type: optimisticData['imageUrl'] != null
                  ? MessageType.image
                  : optimisticData['videoUrl'] != null
                  ? MessageType.video
                  : optimisticData['voiceUrl'] != null
                  ? MessageType.audio
                  : MessageType.text,
              isEdited: false,
              isDeleted: false,
              metadata: {
                'isOptimistic': true,
                'isLocalFile': optimisticData['isLocalFile'] == true,
              },
            );
          }),
          // Add real messages
          ...messages,
        ];

        // Add older loaded messages (avoiding duplicates)
        // Also filter out messages deleted for current user and uploading media from receiver
        for (final doc in _loadedMessages) {
          final data = doc.data() as Map<String, dynamic>;
          final messageId = doc.id;

          // Check if message is deleted for current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null &&
              currentUserId != null &&
              deletedFor.contains(currentUserId)) {
            continue; // Skip this message - deleted for current user
          }

          // Hide videos/images that are still uploading from receiver
          final senderId = data['senderId'] as String?;
          final messageTypeEnum = _parseMessageType(data['type']);
          final messageStatusEnum = _parseMessageStatusFromInt(data['status']);
          final mediaUrl = data['mediaUrl'] as String?;

          if (messageTypeEnum == MessageType.video ||
              messageTypeEnum == MessageType.image) {
            if (messageStatusEnum == MessageStatus.sending ||
                (mediaUrl == null || mediaUrl.isEmpty)) {
              if (senderId != currentUserId) {
                continue; // Hide from receiver
              }
            }
          }

          if (!allDisplayMessages.any((m) => m.id == messageId)) {
            final isDeleted = data['isDeleted'] == true;
            allDisplayMessages.add(
              MessageModel(
                id: messageId,
                senderId: data['senderId'] as String? ?? '',
                receiverId: data['receiverId'] as String? ?? '',
                chatId: _conversationId!,
                text: data['text'] as String?,
                mediaUrl: isDeleted
                    ? null
                    : (data['mediaUrl'] as String? ??
                          data['imageUrl'] as String?),
                audioUrl: isDeleted ? null : data['audioUrl'] as String?,
                audioDuration: _parseIntFromDynamic(data['audioDuration']),
                timestamp: data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp).toDate()
                    : DateTime.now(),
                status: _parseMessageStatusFromInt(
                  data['status'],
                  isRead: data['read'] == true || data['isRead'] == true,
                ),
                type: _parseMessageType(data['type']),
                replyToMessageId: data['replyToMessageId'] as String?,
                isEdited: data['isEdited'] ?? false,
                isDeleted: isDeleted,
                reactions: data['reactions'] != null
                    ? List<String>.from(data['reactions'])
                    : null,
              ),
            );
          }
        }

        // Sort by timestamp descending
        allDisplayMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return _buildMessageListView(isDarkMode, allDisplayMessages);
      },
    );
  }

  // Empty chat state - simple message icon
  Widget _buildEmptyChatState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple chat bubble icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to parse int from dynamic (handles int, string, or null) - static so it can be used by nested classes
  static int? _parseIntFromDynamic(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // Helper to parse message type
  MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    if (type is int) {
      return MessageType.values[type.clamp(0, MessageType.values.length - 1)];
    }
    // Handle string type (from Firestore)
    if (type is String) {
      final intType = int.tryParse(type);
      if (intType != null) {
        return MessageType.values[intType.clamp(
          0,
          MessageType.values.length - 1,
        )];
      }
    }
    return MessageType.text;
  }

  // Helper to parse message status from int, string, or isRead field
  MessageStatus _parseMessageStatusFromInt(dynamic status, {bool? isRead}) {
    // If isRead is explicitly true, return read status
    if (isRead == true) {
      return MessageStatus.read;
    }

    if (status == null) {
      return MessageStatus.sent;
    }

    // Handle int status
    if (status is int) {
      return MessageStatus.values[status.clamp(
        0,
        MessageStatus.values.length - 1,
      )];
    }

    // Handle string status
    if (status is String) {
      // Try parsing as numeric string first
      final intStatus = int.tryParse(status);
      if (intStatus != null) {
        return MessageStatus.values[intStatus.clamp(
          0,
          MessageStatus.values.length - 1,
        )];
      }
      // Otherwise try parsing as text
      switch (status.toLowerCase()) {
        case 'sending':
          return MessageStatus.sending;
        case 'sent':
          return MessageStatus.sent;
        case 'delivered':
          return MessageStatus.delivered;
        case 'read':
          return MessageStatus.read;
        case 'failed':
          return MessageStatus.failed;
        default:
          return MessageStatus.sent;
      }
    }

    return MessageStatus.sent;
  }

  Widget _buildMessageListView(bool isDarkMode, List<MessageModel> messages) {
    // Filter messages if searching
    final displayMessages = _isSearching && _searchQuery.isNotEmpty
        ? messages
              .where(
                (msg) =>
                    msg.text != null &&
                    msg.text!.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList()
        : messages;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Loading indicator for pagination
          if (_isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              key: const PageStorageKey('message_list'),
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: displayMessages.length,
              itemBuilder: (context, index) {
                final message = displayMessages[index];
                final currentUserId = _currentUserId;
                final isMe =
                    currentUserId != null && message.senderId == currentUserId;
                final showAvatar =
                    !isMe &&
                    (index == displayMessages.length - 1 ||
                        displayMessages[index + 1].senderId !=
                            message.senderId);

                final isHighlighted =
                    _isSearching &&
                    _searchResults.contains(message) &&
                    _searchResults.indexOf(message) == _currentSearchIndex;

                // Check if we need to show date separator
                Widget? dateSeparator;
                if (index == displayMessages.length - 1 ||
                    !_isSameDay(
                      message.timestamp,
                      displayMessages[index + 1].timestamp,
                    )) {
                  dateSeparator = _buildDateSeparator(
                    message.timestamp,
                    isDarkMode,
                  );
                }

                return Column(
                  key: ValueKey(message.id),
                  children: [
                    if (dateSeparator != null) dateSeparator,
                    _buildMessageBubble(
                      message,
                      isMe,
                      showAvatar,
                      isDarkMode,
                      isHighlighted: isHighlighted,
                      searchQuery: _isSearching ? _searchQuery : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Check if two dates are the same day
  bool _isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Build date separator widget - Premium iOS style
  Widget _buildDateSeparator(DateTime? date, bool isDarkMode) {
    if (date == null) return const SizedBox.shrink();

    String dateText;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      // Day of the week for last 7 days
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      dateText = days[date.weekday - 1];
    } else {
      // Full date for older messages - iOS style format
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dateText = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppColors.iosGrayDark.withValues(alpha: 0.8)
                : AppColors.backgroundDark.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.iosGray : AppColors.iosGray,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMe,
    bool showAvatar,
    bool isDarkMode, {
    bool isHighlighted = false,
    String? searchQuery,
  }) {
    // Handle deleted messages first (WhatsApp-style "This message was deleted")
    // This applies to ALL message types including calls
    if (message.isDeleted) {
      return _buildDeletedMessageBubble(message, isMe, isDarkMode);
    }

    // Handle call messages (WhatsApp-style centered call events)
    if (message.type == MessageType.voiceCall ||
        message.type == MessageType.missedCall ||
        message.type == MessageType.videoCall) {
      return _buildCallMessageBubble(message, isMe, isDarkMode);
    }

    final isSelected = _selectedMessageIds.contains(message.id);

    // Wrap in multi-select container
    Widget messageWidget = Dismissible(
      key: Key(message.id),
      direction: _isMultiSelectMode
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        HapticFeedback.lightImpact();
        setState(() {
          _editingMessage = null;
          _messageController.clear();
          _replyToMessage = message;
        });
        FocusScope.of(context).requestFocus(_messageFocusNode);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          Icons.reply,
          color: Colors.white.withValues(alpha: 0.7),
          size: 24,
        ),
      ),
      child: GestureDetector(
        onLongPress: _isMultiSelectMode
            ? null
            : () => _showMessageOptions(message, isMe),
        onTap: _isMultiSelectMode
            ? () => _toggleMessageSelection(message.id)
            : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 6,
              left: isMe ? 60 : 0,
              right: isMe ? 0 : 60,
            ),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe && showAvatar)
                  Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withValues(alpha: 0.15),
                      //     blurRadius: 8,
                      //     offset: const Offset(0, 2),
                      //   ),
                      // ],
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.iosBlue.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage:
                          PhotoUrlHelper.isValidUrl(
                            widget.otherUser.profileImageUrl,
                          )
                          ? CachedNetworkImageProvider(
                              widget.otherUser.profileImageUrl!,
                            )
                          : null,
                      child:
                          !PhotoUrlHelper.isValidUrl(
                            widget.otherUser.profileImageUrl,
                          )
                          ? Text(
                              widget.otherUser.name.isNotEmpty
                                  ? widget.otherUser.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.iosBlue,
                              ),
                            )
                          : null,
                    ),
                  )
                else if (!isMe)
                  const SizedBox(width: 40),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.5,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  (message.type == MessageType.image ||
                                      message.type == MessageType.video)
                                  ? 4
                                  : (message.replyToMessageId != null ? 6 : 4),
                              vertical:
                                  (message.type == MessageType.image ||
                                      message.type == MessageType.video)
                                  ? 4
                                  : (message.replyToMessageId != null ? 4 : 2),
                            ),
                            decoration: BoxDecoration(
                              gradient:
                                  isMe &&
                                      message.type != MessageType.audio &&
                                      message.type != MessageType.video &&
                                      message.type != MessageType.image
                                  ? LinearGradient(
                                      colors:
                                          chatThemeColors[_selectedTheme] ??
                                          chatThemeColors['default']!,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color:
                                  !isMe &&
                                      message.type != MessageType.audio &&
                                      message.type != MessageType.video &&
                                      message.type != MessageType.image
                                  ? (isDarkMode
                                        ? const Color.fromARGB(255, 32, 32, 32)
                                        : Colors.grey[200])
                                  : null, // Grey for received text only, not audio/video/image
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(isMe ? 12 : 5),
                                bottomRight: Radius.circular(isMe ? 5 : 12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.start,
                              children: [
                                // Reply bubble inside message card (card within card) - always on left
                                if (message.replyToMessageId != null) ...[
                                  _buildReplyBubble(
                                    message.replyToMessageId!,
                                    isMe,
                                    isDarkMode,
                                  ),
                                  SizedBox(height: 5),
                                ],
                                if (message.type == MessageType.image &&
                                    (message.mediaUrl != null ||
                                        message.localPath != null))
                                  _buildImageMessage(message, isMe, isDarkMode),
                                // Video message player UI
                                if (message.type == MessageType.video &&
                                    message.mediaUrl != null)
                                  _buildVideoMessagePlayer(
                                    message,
                                    isMe,
                                    isDarkMode,
                                  ),
                                // Audio message player UI with time/status below
                                if (message.type == MessageType.audio &&
                                    message.audioUrl != null)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildAudioMessagePlayer(
                                        message,
                                        isMe,
                                        isDarkMode: isDarkMode,
                                      ),
                                      // Time and status below audio player (always show time, hide ticks when sending)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (message.isEdited == true) ...[
                                              Text(
                                                'edited ',
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white.withValues(
                                                          alpha: 0.55,
                                                        )
                                                      : (isDarkMode
                                                            ? Colors.grey[500]
                                                            : Colors.grey[600]),
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                            // Time (always show)
                                            Text(
                                              _formatMessageTime(
                                                message.timestamp,
                                              ),
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white.withValues(
                                                        alpha: 0.55,
                                                      )
                                                    : (isDarkMode
                                                          ? Colors.grey[500]
                                                          : Colors.grey[600]),
                                                fontSize: 11,
                                              ),
                                            ),
                                            // Status tick (only for my messages, hide when sending)
                                            if (isMe &&
                                                message.status !=
                                                    MessageStatus.sending &&
                                                message.audioUrl != null &&
                                                message
                                                    .audioUrl!
                                                    .isNotEmpty) ...[
                                              const SizedBox(width: 4),
                                              _buildMessageStatusIcon(
                                                message.status,
                                                isMe,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                if (message.text != null &&
                                    message.text!.isNotEmpty)
                                  Padding(
                                    padding:
                                        (message.type == MessageType.image ||
                                            message.type == MessageType.video)
                                        ? const EdgeInsets.only(
                                            left: 10,
                                            right: 10,
                                            top: 8,
                                            bottom: 4,
                                          )
                                        : EdgeInsets.all(
                                            message.replyToMessageId != null
                                                ? 0
                                                : 10,
                                          ),
                                    child:
                                        searchQuery != null &&
                                            searchQuery.isNotEmpty
                                        ? _buildHighlightedText(
                                            message.text!,
                                            searchQuery,
                                            TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : (isDarkMode
                                                        ? Colors.white
                                                        : AppColors
                                                              .iosGrayDark),
                                              fontSize: 16,
                                              height: 1.35,
                                              letterSpacing: -0.2,
                                            ),
                                          )
                                        : _buildTextWithMentions(
                                            message.text!,
                                            isMe,
                                            isDarkMode,
                                            false, // isDeleted is already handled separately
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Time and status row outside card (skip for audio - it has its own)
                      if (message.type != MessageType.audio)
                        Padding(
                          padding: EdgeInsets.only(
                            top: message.replyToMessageId != null ? 4 : 1,
                            left: 4,
                            right: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isEdited == true) ...[
                                Text(
                                  'edited ',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              // Time
                              Text(
                                _formatMessageTime(message.timestamp),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                              // Status tick (only for my messages)
                              if (isMe &&
                                  !(message.status == MessageStatus.sending &&
                                      (message.type == MessageType.image ||
                                          message.type == MessageType.video ||
                                          message.type ==
                                              MessageType.audio))) ...[
                                const SizedBox(width: 4),
                                _buildMessageStatusIcon(message.status, isMe),
                              ],
                            ],
                          ),
                        ),
                      if (message.reactions != null &&
                          message.reactions!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.backgroundDarkTertiary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message.reactions!.join(' '),
                            style: const TextStyle(fontSize: 16),
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

    // Wrap with multi-select UI if in selection mode
    if (_isMultiSelectMode) {
      return GestureDetector(
        onTap: () => _toggleMessageSelection(message.id),
        child: Container(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.15)
              : Colors.transparent,
          child: Row(
            children: [
              // Selection checkbox
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blue : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.white54,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              // Message content
              Expanded(child: messageWidget),
            ],
          ),
        ),
      );
    }

    return messageWidget;
  }

  // Toggle message selection for multi-select mode
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        // Exit multi-select if no messages selected
        if (_selectedMessageIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  // Enter multi-select mode
  void _enterMultiSelectMode(String initialMessageId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(initialMessageId);
    });
  }

  // Exit multi-select mode
  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  /// Common delete dialog builder to avoid duplicate code
  Future<String?> _showDeleteDialog({
    required String title,
    required bool showDeleteForEveryone,
    Widget? extraWidget,
  }) async {
    return showDialog<String>(
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
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how to delete',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (showDeleteForEveryone) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context, 'for_everyone'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.redAccent,
                        ),
                        child: const Center(
                          child: Text(
                            'Delete for everyone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (extraWidget != null) ...[
                    extraWidget,
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, null),
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
                                  fontSize: 13,
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
                          onTap: () => Navigator.pop(context, 'for_me'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.redAccent,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete for me',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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

  // Show delete options dialog for selected messages
  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final count = _selectedMessageIds.length;

    // Check if all selected messages are sent by current user
    bool allMyMessages = true;
    for (final messageId in _selectedMessageIds) {
      final message = _allMessages.where((m) => m.id == messageId).firstOrNull;
      if (message != null && message.senderId != _currentUserId) {
        allMyMessages = false;
        break;
      }
    }

    final result = await _showDeleteDialog(
      title: 'Delete $count message${count > 1 ? 's' : ''}?',
      showDeleteForEveryone: allMyMessages,
    );

    if (result == null) return;

    if (result == 'for_me') {
      await _deleteSelectedMessagesForMe();
    } else if (result == 'for_everyone') {
      await _deleteSelectedMessagesForEveryone();
    }
  }

  // Delete selected messages for me only (adds to deletedFor array) - FAST batch
  Future<void> _deleteSelectedMessagesForMe() async {
    final messagesToDelete = _selectedMessageIds.toList();

    // Remove from local lists immediately for instant UI update
    _loadedMessages.removeWhere((doc) => messagesToDelete.contains(doc.id));
    _allMessages.removeWhere((m) => messagesToDelete.contains(m.id));

    // Exit multi-select mode immediately
    _exitMultiSelectMode();

    // Force rebuild instantly
    if (mounted) setState(() {});

    // Batch update in background
    try {
      final batch = _firestore.batch();
      for (final messageId in messagesToDelete) {
        final docRef = _firestore
            .collection('conversations')
            .doc(_conversationId!)
            .collection('messages')
            .doc(messageId);
        batch.update(docRef, {
          'deletedFor': FieldValue.arrayUnion([_currentUserId]),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting messages for me: $e');
    }
  }

  // Delete selected messages for everyone - FAST with parallel execution
  Future<void> _deleteSelectedMessagesForEveryone() async {
    final messagesToDelete = _selectedMessageIds.toList();

    // Exit multi-select mode immediately
    _exitMultiSelectMode();

    // Force rebuild instantly
    if (mounted) setState(() {});

    try {
      // Get all messages in parallel
      final futures = messagesToDelete.map(
        (messageId) => _firestore
            .collection('conversations')
            .doc(_conversationId!)
            .collection('messages')
            .doc(messageId)
            .get(),
      );
      final docs = await Future.wait(futures);

      // Prepare batch operations
      final batch = _firestore.batch();
      final mediaDeleteFutures = <Future>[];

      for (final messageDoc in docs) {
        if (!messageDoc.exists) continue;

        final data = messageDoc.data()!;
        final isAlreadyDeleted = data['isDeleted'] == true;

        // Queue media deletion (run in parallel later)
        final mediaUrl =
            data['mediaUrl'] as String? ?? data['imageUrl'] as String?;
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          mediaDeleteFutures.add(
            _storage.refFromURL(mediaUrl).delete().catchError((_) {}),
          );
        }
        final audioUrl = data['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          mediaDeleteFutures.add(
            _storage.refFromURL(audioUrl).delete().catchError((_) {}),
          );
        }

        // Add to batch
        if (isAlreadyDeleted) {
          batch.delete(messageDoc.reference);
        } else {
          batch.update(messageDoc.reference, {
            'isDeleted': true,
            'text': 'This message was deleted',
            'mediaUrl': null,
            'imageUrl': null,
            'audioUrl': null,
            'type': MessageType.text.index,
            'deletedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Execute batch commit and media deletions in parallel
      await Future.wait([batch.commit(), ...mediaDeleteFutures]);

      // Update last message
      await _updateLastMessageAfterDelete();
    } catch (e) {
      debugPrint('Error deleting messages for everyone: $e');
    }
  }

  // Forward selected messages to other contacts
  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    // Get selected messages data
    final List<MessageModel> selectedMessages = [];
    for (final messageId in _selectedMessageIds) {
      final msg = _allMessages.where((m) => m.id == messageId).firstOrNull;
      if (msg != null) {
        selectedMessages.add(msg);
      }
    }

    if (selectedMessages.isEmpty) {
      return;
    }

    // Show forward screen
    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ForwardMessageScreen(currentUserId: _currentUserId!),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Forward each selected message to each selected recipient
      for (final recipient in result) {
        for (final message in selectedMessages) {
          try {
            await _sendForwardedMessage(recipient, message);
          } catch (e) {
            debugPrint('Failed to forward message: $e');
          }
        }
      }

      // Exit multi-select mode
      _exitMultiSelectMode();
    }
  }

  // Format message time - always show actual time (HH:MM AM/PM)
  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    // Always show actual time like WhatsApp/iMessage
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // Build message status icon with premium visuals
  // Single tick = sent, Double tick grey = delivered, Double tick blue = read
  Widget _buildMessageStatusIcon(MessageStatus status, bool isMe) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.5),
            ),
          ),
        );
      case MessageStatus.sent:
        // Single tick - message sent to server
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.delivered:
        // Double tick grey - message delivered but not read
        return Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.read:
        // Double tick blue - message seen/read
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Colors.blue, // Blue tick for read
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.iosRed,
        );
    }
  }

  Widget _buildReplyBubble(String messageId, bool isMe, bool isDarkMode) {
    if (_conversationId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(messageId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final replyData = snapshot.data!.data() as Map<String, dynamic>?;
        if (replyData == null) return const SizedBox.shrink();

        // Determine who sent the original message
        final replySenderId = replyData['senderId'] as String?;
        final bool isReplyToSelf = replySenderId == _currentUserId;
        final String replyToName = isReplyToSelf
            ? 'You'
            : widget.otherUser.name;

        return Container(
          margin: const EdgeInsets.only(left: 2, right: 5, top: 2, bottom: 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: (isMe ? Colors.white : Theme.of(context).primaryColor)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 1),
              bottomRight: Radius.circular(isMe ? 1 : 12),
            ),
            border: Border(
              left: BorderSide(
                color: isMe ? Colors.white70 : Theme.of(context).primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyToName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              Text(
                replyData['text'] ?? 'Photo',
                style: TextStyle(
                  fontSize: 12,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(bool isDarkMode) {
    final bool isReplyingToSelf = _replyToMessage!.senderId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(left: 40, right: 80, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x80000000), // Fixed black with 50% opacity
            Color(0x99000000), // Fixed black with 60% opacity
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE91E63), // Pink border
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63), // Pink color
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReplyingToSelf ? 'You' : widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE91E63), // Pink color
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!.text ?? 'Photo',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[300], // Always light for dark background
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyToMessage = null),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: Colors.grey[400], // Always light for dark background
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(left: 40, right: 80, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x80000000), // Fixed black with 50% opacity
            Color(0x99000000), // Fixed black with 60% opacity
          ],
        ),
        border: Border.all(
          color: Colors.orange, // Orange border matching edit theme
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _editingMessage!.text ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[300], // Always light for dark background
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: Colors.grey[400], // Always light for dark background
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _conversationId != null
          ? _firestore
                .collection('conversations')
                .doc(_conversationId!)
                .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isTyping = data['isTyping']?[widget.otherUser.uid] ?? false;

        if (!isTyping) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDarkMode
                    ? AppColors.iosGrayDark
                    : AppColors.iosGrayLight,
                backgroundImage:
                    PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                    ? CachedNetworkImageProvider(
                        widget.otherUser.profileImageUrl!,
                      )
                    : null,
                child:
                    !PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                    ? Text(
                        widget.otherUser.name.isNotEmpty
                            ? widget.otherUser.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.iosBlue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.iosGrayDark
                      : AppColors.iosGrayTertiary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypingDot(0, isDarkMode),
                    const SizedBox(width: 3),
                    _buildTypingDot(1, isDarkMode),
                    const SizedBox(width: 3),
                    _buildTypingDot(2, isDarkMode),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingDot(int index, bool isDarkMode) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: (isDarkMode ? AppColors.iosGray : AppColors.iosGray)
                .withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildMentionSuggestions() {
    if (!_showMentionSuggestions || _filteredUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _filteredUsers.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final name = user['name'] as String;
          final photo = user['photo'] as String?;
          final userId = user['id'] as String;

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: PhotoUrlHelper.isValidUrl(photo)
                  ? CachedNetworkImageProvider(photo!)
                  : null,
              child: !PhotoUrlHelper.isValidUrl(photo)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => _insertMention(userId, name),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // White border line at the top
        Container(
          height: 0.5,
          color: const Color(0x4DFFFFFF),
        ), // Fixed white with 30% opacity
        // Input Area - Premium iMessage style
        Container(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 5, bottom: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000), // Fixed black with 40% opacity
                Color(0x80000000), // Fixed black with 50% opacity
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Camera/Gallery button - iOS style
                GestureDetector(
                  onTap: _showCameraGalleryOptions,
                  child: Container(
                    height: 52,
                    width: 52,
                    margin: const EdgeInsets.only(bottom: 0, right: 8),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_circle,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 44,
                    ),
                  ),
                ),
                // Message input field - Premium rounded design
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: GlassTextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            autofocus: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.send,
                            hintText: 'Message',
                            showBlur: false,
                            decoration: const BoxDecoration(),
                            contentPadding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 22,
                              bottom: 2,
                            ),
                            onChanged: (text) {
                              setState(() {
                                _updateTypingStatus(text.isNotEmpty);
                              });
                              // Handle @ mention detection
                              _handleMentionDetection(text);
                            },
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty) {
                                _sendMessage();
                              }
                            },
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                          ),
                        ),
                        // Emoji button
                        Padding(
                          padding: const EdgeInsets.only(right: 4, bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                                if (_showEmojiPicker) {
                                  _messageFocusNode.unfocus();
                                } else {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_messageFocusNode);
                                }
                              });
                            },
                            child: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_rounded
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send / Mic button - Premium animated
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: hasText
                      ? GestureDetector(
                          key: const ValueKey('send'),
                          onTap: _sendMessage,
                          child: Container(
                            height: 42,
                            width: 42,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('mic'),
                          // Tap to toggle recording
                          onTap: () async {
                            if (_isRecording) {
                              // Show confirmation popup
                              await _showVoiceRecordingPopup();
                            } else {
                              // Start recording
                              await _startRecording();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 42,
                            width: _isRecording ? 90 : 42,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                              boxShadow: _isRecording
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: _isRecording
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Recording timer
                                        Text(
                                          _formatRecordingTime(
                                            _recordingDuration,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        // Stop icon
                                        const Icon(
                                          Icons.stop_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.mic_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 28,
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Emoji Picker - Premium styling with dynamic height
        if (_showEmojiPicker)
          Builder(
            builder: (context) {
              // Calculate dynamic height based on screen size (max 35% of screen height)
              final screenHeight = MediaQuery.of(context).size.height;
              final emojiPickerHeight = (screenHeight * 0.35).clamp(
                200.0,
                350.0,
              );

              return Container(
                height: emojiPickerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _messageController.text += emoji.emoji;
                          _messageController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _messageController.text.length,
                                ),
                              );
                          setState(() {});
                        },
                        onBackspacePressed: () {
                          if (_messageController.text.isNotEmpty) {
                            _messageController.text = _messageController
                                .text
                                .characters
                                .skipLast(1)
                                .toString();
                            setState(() {});
                          }
                        },
                        config: Config(
                          height: emojiPickerHeight - 20,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 28,
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            backgroundColor: Colors.white,
                            recentsLimit: 28,
                            noRecents: Text(
                              'No Recents',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            loadingIndicator: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.iosBlue,
                              ),
                            ),
                            buttonMode: ButtonMode.MATERIAL,
                          ),
                          skinToneConfig: const SkinToneConfig(),
                          categoryViewConfig: const CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: Colors.white,
                            indicatorColor: AppColors.iosBlue,
                            iconColor: Colors.grey,
                            iconColorSelected: AppColors.iosBlue,
                            categoryIcons: CategoryIcons(),
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(
                            enabled: false,
                          ),
                          searchViewConfig: const SearchViewConfig(
                            backgroundColor: Colors.white,
                            buttonIconColor: AppColors.iosBlue,
                            hintText: 'Search emoji...',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildScrollToBottomButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showScrollButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.iosGrayDark.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isDarkMode
                    ? AppColors.iosGraySecondary
                    : AppColors.iosGrayLight,
                width: 0.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.iosBlue,
                  size: 24,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.iosRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
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

  // Removed: Empty chat state UI with "Say Hello" button
  // Now returns an empty widget instead

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) {
      return;
    }

    // Check if we're editing a message
    if (_editingMessage != null) {
      _saveEditedMessage();
      return;
    }

    final text = _messageController.text.trim();
    final replyToMessage = _replyToMessage;

    _messageController.clear();
    setState(() {
      _replyToMessage = null;
    });
    _updateTypingStatus(false);

    // Haptic feedback for sending
    HapticFeedback.lightImpact();

    try {
      // Use HybridChatService - saves to local SQLite first (instant!)
      // then uploads to Firebase for delivery
      await _hybridChatService.sendMessage(
        conversationId: _conversationId!,
        receiverId: widget.otherUser.uid,
        text: text,
        replyToMessageId: replyToMessage?.id,
        replyToText: replyToMessage?.text,
        replyToSenderId: replyToMessage?.senderId,
      );

      // Reload messages to show the new message instantly
      setState(() {});

      // Send push notification to the other user
      final currentUserProfile = ref
          .read(currentUserProfileProvider)
          .valueOrNull;
      final currentUserName = currentUserProfile?.name ?? 'Someone';

      NotificationService().sendNotificationToUser(
        userId: widget.otherUser.uid,
        title: 'New Message from $currentUserName',
        body: text,
        type: 'message',
        data: {'conversationId': _conversationId},
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      SnackBarHelper.showError(context, 'Failed to send message: $e');
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_conversationId == null || _currentUserId == null) return;

    _typingTimer?.cancel();

    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      _firestore.collection('conversations').doc(_conversationId!).update({
        'isTyping.$_currentUserId': isTyping,
      });
    }

    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _updateTypingStatus(false);
      });
    }
  }

  void _markMessagesAsRead() async {
    if (_conversationId == null || _currentUserId == null) return;

    try {
      // Use HybridChatService - updates both local DB and Firebase
      await _hybridChatService.markMessagesAsRead(_conversationId!);

      // Update conversation unread count
      await _firestore.collection('conversations').doc(_conversationId!).update(
        {'unreadCount.$_currentUserId': 0},
      );
    } catch (e) {
      // Only log non-critical errors, don't show to user
      debugPrint('Error marking messages as read: $e');
      // Silently fail - this is not critical for chat functionality
    }
  }

  // Sync messages from Firebase to local database in background
  Future<void> _syncMessagesInBackground() async {
    if (_conversationId == null) return;

    try {
      await _hybridChatService.syncMessages(_conversationId!);

      // Refresh UI with synced messages
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Non-fatal - messages will sync next time
    }
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    HapticFeedback.mediumImpact();

    final hasText = message.text != null && message.text!.isNotEmpty;
    final hasImage = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on popup
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                      // Reply option
                      _buildPopupOption(
                        icon: Icons.reply,
                        label: 'Reply',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            // Clear other actions first
                            _editingMessage = null;
                            _messageController.clear();
                            _replyToMessage = message;
                          });
                          FocusScope.of(
                            this.context,
                          ).requestFocus(_messageFocusNode);
                        },
                      ),

                      // Forward option
                      _buildPopupOption(
                        icon: Icons.forward,
                        label: 'Forward',
                        onTap: () {
                          Navigator.pop(context);
                          // Clear other actions first
                          setState(() {
                            _editingMessage = null;
                            _replyToMessage = null;
                            _messageController.clear();
                          });
                          _forwardMessage(message);
                        },
                      ),

                      // Copy option (only if has text)
                      if (hasText)
                        _buildPopupOption(
                          icon: Icons.copy,
                          label: 'Copy',
                          onTap: () {
                            Navigator.pop(context);
                            Clipboard.setData(
                              ClipboardData(text: message.text ?? ''),
                            );
                            SnackBarHelper.showSuccess(
                              this.context,
                              'Copied to clipboard',
                            );
                          },
                        ),

                      // Save Image option (only if has image)
                      if (hasImage)
                        _buildPopupOption(
                          icon: Icons.download,
                          label: 'Save Image',
                          onTap: () {
                            Navigator.pop(context);
                            _saveImage(message.mediaUrl!);
                          },
                        ),

                      // Edit option (only for own text messages)
                      if (isMe && hasText)
                        _buildPopupOption(
                          icon: Icons.edit,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(context);
                            // Clear other actions first
                            setState(() {
                              _replyToMessage = null;
                            });
                            _editMessage(message);
                          },
                        ),

                      // Select option - enter multi-select mode
                      _buildPopupOption(
                        icon: Icons.check_circle_outline,
                        label: 'Select',
                        onTap: () {
                          Navigator.pop(context);
                          _enterMultiSelectMode(message.id);
                        },
                      ),

                      // Delete option (for all messages - own and received)
                      _buildPopupOption(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(message);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _forwardMessage(MessageModel message) async {
    // Show WhatsApp-style forward screen
    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ForwardMessageScreen(currentUserId: _currentUserId!),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Forward message to all selected contacts
      for (final recipient in result) {
        try {
          await _sendForwardedMessage(recipient, message);
        } catch (e) {
          debugPrint('Failed to forward to ${recipient.name}: $e');
        }
      }
    }
  }

  Future<void> _sendForwardedMessage(
    UserProfile recipient,
    MessageModel originalMessage,
  ) async {
    try {
      // Get or create conversation with recipient
      final conversationId = await _conversationService.getOrCreateConversation(
        recipient,
      );

      // Prepare forwarded message
      String? forwardedText = originalMessage.text;
      if (forwardedText != null && forwardedText.isNotEmpty) {
        forwardedText = forwardedText;
      }

      // Send message to new conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': _currentUserId,
            'receiverId': recipient.uid,
            'text': forwardedText,
            'mediaUrl': originalMessage.mediaUrl,
            'type': originalMessage.type.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.delivered.index, // Double grey tick
            'read': false,
            'isRead': false,
            'isForwarded': true, // Mark as forwarded
          });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage':
            forwardedText ?? (originalMessage.mediaUrl != null ? ' Photo' : ''),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId,
      });
    } catch (e) {
      debugPrint('Failed to forward message: $e');
      rethrow;
    }
  }

  Future<void> _saveImage(String imageUrl) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Try photos permission for Android 13+
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Storage permission required to save image',
            );
          }
          return;
        }
      }

      if (mounted) {
        SnackBarHelper.showInfo(context, 'Saving image...');
      }

      // Download image using Dio
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get the Pictures directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Pictures/Plink');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Create directory if not exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save file
      final fileName = 'plink_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      // Notify media scanner on Android to show in gallery
      if (Platform.isAndroid) {
        await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$filePath',
        ]);
      }

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Image saved to Pictures/Plink');
      }
    } catch (e) {
      debugPrint('Failed to save image: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to save image: $e');
      }
    }
  }

  void _editMessage(MessageModel message) {
    setState(() {
      // Clear reply first - only one action at a time
      _replyToMessage = null;
      _editingMessage = message;
      _messageController.text = message.text ?? '';
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _saveEditedMessage() async {
    if (_editingMessage == null || _messageController.text.trim().isEmpty) {
      return;
    }

    final newText = _messageController.text.trim();
    final messageId = _editingMessage!.id;

    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });

    try {
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to edit message: $e');
      }
    }
  }

  void _showDeleteConfirmation(MessageModel message) async {
    final isMyMessage = message.senderId == _currentUserId;

    final result = await _showDeleteDialog(
      title: 'Delete Message',
      showDeleteForEveryone: isMyMessage,
    );

    if (result == 'for_me') {
      _deleteMessageForMe(message);
    } else if (result == 'for_everyone') {
      _deleteMessageForEveryone(message);
    }
  }

  /// Show call back confirmation dialog when tapping on call history
  void _showCallBackConfirmation({bool isVideoCall = false}) {
    HapticFeedback.lightImpact();

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
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Call icon (voice only)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Call ${widget.otherUser.name}?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a voice call',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Buttons row
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Call button (voice only)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _startAudioCall();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.green,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

  /// Show delete confirmation dialog for call messages
  void _showCallDeleteConfirmation(MessageModel message) {
    HapticFeedback.mediumImpact();
    final isMyMessage = message.senderId == _currentUserId;

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
                color: Colors.white.withValues(alpha: 0.15),
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
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Call Options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Delete and Select buttons in a row
                  Row(
                    children: [
                      // Delete button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showDeleteCallOptions(message, isMyMessage);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.red.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Select button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _enterMessageSelectionMode(message);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blue.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.checklist,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Select',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Cancel button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }

  // Show delete options for call message
  void _showDeleteCallOptions(MessageModel message, bool isMyMessage) {
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
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Red circle icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how to delete',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Delete for everyone button (full width, only for caller's own calls)
                  if (isMyMessage) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessageForEveryone(message);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.redAccent,
                        ),
                        child: const Center(
                          child: Text(
                            'Delete for everyone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Cancel and Delete for me buttons in row
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
                                  fontSize: 13,
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
                          onTap: () {
                            Navigator.pop(context);
                            _deleteMessageForMe(message);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.redAccent,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete for me',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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

  // Enter message selection mode starting with the given message
  void _enterMessageSelectionMode(MessageModel message) {
    HapticFeedback.lightImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(message.id);
    });
  }

  /// Delete message for current user only (WhatsApp-style "Delete for me")
  /// The message is hidden for current user but still visible to other user
  Future<void> _deleteMessageForMe(MessageModel message) async {
    try {
      if (_conversationId == null || _conversationId!.isEmpty) {
        SnackBarHelper.showError(
          context,
          'Cannot delete: Invalid conversation',
        );
        return;
      }

      if (message.id.isEmpty) {
        SnackBarHelper.showError(context, 'Cannot delete: Invalid message');
        return;
      }

      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      // Add current user to deletedFor array (message is hidden only for this user)
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(message.id)
          .update({
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          });

      // Remove from local cached messages to update UI immediately
      _loadedMessages.removeWhere((doc) => doc.id == message.id);
      _allMessages.removeWhere((m) => m.id == message.id);

      // Force UI rebuild
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
    }
  }

  /// Delete message for everyone - WhatsApp style "This message was deleted"
  /// Message is marked as deleted, content cleared, but document remains
  Future<void> _deleteMessageForEveryone(MessageModel message) async {
    try {
      if (_conversationId == null || _conversationId!.isEmpty) {
        SnackBarHelper.showError(
          context,
          'Cannot delete: Invalid conversation',
        );
        return;
      }

      if (message.id.isEmpty) {
        SnackBarHelper.showError(context, 'Cannot delete: Invalid message');
        return;
      }

      // Delete media from Firebase Storage if exists
      if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(message.mediaUrl!);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting media file: $e');
        }
      }

      // Delete audio from Firebase Storage if exists
      if (message.audioUrl != null && message.audioUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(message.audioUrl!);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting audio file: $e');
        }
      }

      // Mark message as deleted (WhatsApp style - shows "This message was deleted")
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(message.id)
          .update({
            'isDeleted': true,
            'text': 'This message was deleted',
            'mediaUrl': null,
            'imageUrl': null,
            'audioUrl': null,
            'type': MessageType.text.index,
            'deletedAt': FieldValue.serverTimestamp(),
          });

      // Update last message if this was the last one
      await _updateLastMessageAfterDelete();

      // Force UI rebuild
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
    }
  }

  /// Update conversation's last message after a deletion
  Future<void> _updateLastMessageAfterDelete() async {
    if (_conversationId == null) return;

    try {
      // Get the most recent message (message is now fully deleted, not just marked)
      final allMessages = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (allMessages.docs.isNotEmpty) {
        final lastMessageDoc = allMessages.docs.first;
        final lastMessageData = lastMessageDoc.data();

        String lastMessageText = '';
        final messageType = lastMessageData['type'] ?? 0;

        if (messageType == MessageType.text.index) {
          lastMessageText = lastMessageData['text'] ?? '';
        } else if (messageType == MessageType.image.index) {
          lastMessageText = ' Photo';
        } else if (messageType == MessageType.video.index) {
          lastMessageText = ' Video';
        } else if (messageType == MessageType.audio.index) {
          lastMessageText = ' Audio';
        } else if (messageType == MessageType.file.index) {
          lastMessageText = ' File';
        } else {
          lastMessageText = lastMessageData['text'] ?? '';
        }

        await _firestore
            .collection('conversations')
            .doc(_conversationId!)
            .update({
              'lastMessage': lastMessageText,
              'lastMessageTime':
                  lastMessageData['timestamp'] ?? FieldValue.serverTimestamp(),
              'lastMessageSenderId': lastMessageData['senderId'],
            });
      }
    } catch (e) {
      debugPrint('Error updating last message: $e');
    }
  }

  void _showCameraGalleryOptions() {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on popup
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                      // Camera Photo option
                      _buildPopupOption(
                        icon: Icons.camera_alt,
                        label: 'Take Photo',
                        onTap: () {
                          Navigator.pop(context);
                          _takePhoto();
                        },
                      ),
                      // Camera Video option
                      _buildPopupOption(
                        icon: Icons.videocam,
                        label: 'Record Video',
                        onTap: () {
                          Navigator.pop(context);
                          _recordVideo();
                        },
                      ),
                      // Gallery Photo option
                      _buildPopupOption(
                        icon: Icons.image,
                        label: 'Photo from Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      // Gallery Video option
                      _buildPopupOption(
                        icon: Icons.video_library,
                        label: 'Video from Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Check daily media limit (4 images or 4 videos per day)
  void _pickImage() async {
    // LOCK: Check if another media operation is in progress
    if (_isMediaOperationInProgress) {
      debugPrint('⏸️ Media operation already in progress, blocking...');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Please wait for previous upload to complete',
        );
      }
      return;
    }

    try {
      _isMediaOperationInProgress = true; // Acquire lock
      debugPrint('🔐 Lock acquired for image picker');

      // Check daily limit first (1 image)
      final wouldExceed = await _wouldExceedLimit('image', 1);
      if (wouldExceed) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye.',
          );
        }
        return;
      }

      // ⚠️ Don't increment counter yet - wait for user to actually pick images!

      // Pick multiple images (max 4) like WhatsApp
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (images.isEmpty) {
        // User cancelled - NO counter increment needed!
        if (mounted) {
          FocusScope.of(context).requestFocus(_messageFocusNode);
        }
        return;
      }

      // ✅ User picked images - NOW increment counter for 1 image
      await _incrementMediaCounter('image', 1);
      debugPrint(
        '✅ Counter incremented for image upload (user confirmed selection)',
      );

      // Limit to max 4 images
      final selectedImages = images.take(4).toList();

      if (images.length > 4 && mounted) {
        SnackBarHelper.showInfo(
          context,
          'Maximum 4 images allowed. First 4 images selected.',
        );
      }

      // Show preview screen for multiple images
      if (mounted) {
        _showMediaPreviewScreen(
          selectedImages.map((x) => File(x.path)).toList(),
          isVideo: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _pickImage: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to pick image');
      }
    } finally {
      _isMediaOperationInProgress = false; // Always release lock
      debugPrint('🔓 Lock released for image picker');
    }
  }

  void _takePhoto() async {
    // LOCK: Check if another media operation is in progress
    if (_isMediaOperationInProgress) {
      debugPrint('⏸️ Media operation already in progress, blocking...');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Please wait for previous upload to complete',
        );
      }
      return;
    }

    try {
      _isMediaOperationInProgress = true; // Acquire lock
      debugPrint('🔐 Lock acquired for camera');

      // Check daily limit first
      final wouldExceed = await _wouldExceedLimit('image', 1);
      if (wouldExceed) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye.',
          );
        }
        return;
      }

      // ⚠️ Don't increment counter yet - wait for user to actually take photo!

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (photo != null) {
        // ✅ User took photo - NOW increment counter
        await _incrementMediaCounter('image', 1);

        _uploadAndSendImage(File(photo.path));
      } else {
        // User cancelled camera - NO counter increment
        debugPrint('📷 Camera cancelled by user, no counter increment');
      }

      // Restore focus to message input
      if (mounted) {
        FocusScope.of(context).requestFocus(_messageFocusNode);
      }
    } catch (e) {
      debugPrint('❌ Error in _takePhoto: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to take photo');
      }
    } finally {
      _isMediaOperationInProgress = false; // Always release lock
      debugPrint('🔓 Lock released for camera');
    }
  }

  void _recordVideo() async {
    // Use a flag to prevent multiple simultaneous calls
    if (_isRecordingVideo) return;

    // LOCK: Check if another media operation is in progress
    if (_isMediaOperationInProgress) {
      debugPrint('⏸️ Media operation already in progress, blocking...');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Please wait for previous upload to complete',
        );
      }
      return;
    }

    // Check daily limit first
    final wouldExceed = await _wouldExceedLimit('video', 1);
    if (wouldExceed) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye.',
        );
      }
      return;
    }

    // ⚠️ Don't increment counter yet - wait for user to actually record video!

    _isRecordingVideo = true;
    _isMediaOperationInProgress = true; // Acquire lock
    debugPrint('🔐 Lock acquired for video recording');

    try {
      // Request camera permission first
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Camera permission required to record video',
          );
        }
        return;
      }

      // Request microphone permission for audio in video
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Microphone permission required to record video with audio',
          );
        }
        return;
      }

      if (!mounted) {
        _isRecordingVideo = false;
        return;
      }

      String? videoPath;
      try {
        final video = await _imagePicker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 28), // Max 28 seconds
          preferredCameraDevice: CameraDevice.rear,
        );
        videoPath = video?.path;
      } on PlatformException catch (e) {
        debugPrint('Platform exception: $e');
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(context, 'Camera error: ${e.message}');
        }
        return;
      } catch (cameraError) {
        debugPrint('Camera error: $cameraError');
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Camera not available. Please try again.',
          );
        }
        return;
      }

      // Critical: Wait for camera to fully release before any file operations
      await Future.delayed(const Duration(milliseconds: 1000));

      _isRecordingVideo = false;

      if (!mounted) return;

      if (videoPath != null && videoPath.isNotEmpty) {
        final videoFile = File(videoPath);

        // Small delay before accessing file
        await Future.delayed(const Duration(milliseconds: 200));

        // Check if file exists and is valid
        bool fileExists = false;
        try {
          fileExists = await videoFile.exists();
        } catch (e) {
          debugPrint('File check error: $e');
        }

        if (!fileExists) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video recording failed. Please try again.',
            );
          }
          return;
        }

        // Check file size before processing
        int fileSize = 0;
        try {
          fileSize = await videoFile.length();
        } catch (e) {
          debugPrint('File size check error: $e');
          if (mounted) {
            SnackBarHelper.showError(context, 'Error reading video file.');
          }
          return;
        }

        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 50) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video too large (${fileSizeMB.toStringAsFixed(1)}MB). Please record a shorter video.',
            );
          }
          return;
        }

        if (fileSizeMB == 0) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video recording failed. Empty file.',
            );
          }
          return;
        }

        // ✅ Video is valid - NOW increment counter before upload
        await _incrementMediaCounter('video', 1);
        debugPrint(
          '✅ Counter incremented for video recording (user confirmed)',
        );

        if (mounted) {
          _uploadAndSendVideo(videoFile);
        }
      } else {
        // User cancelled or video not recorded - NO counter increment
        debugPrint('📹 Video recording cancelled/failed, no counter increment');
      }

      // Restore focus to message input
      if (mounted) {
        FocusScope.of(context).requestFocus(_messageFocusNode);
      }
    } catch (e) {
      _isRecordingVideo = false;
      debugPrint('Video recording error: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to record video. Please try again.',
        );
      }
    } finally {
      _isRecordingVideo = false;
      _isMediaOperationInProgress = false; // Always release lock
      debugPrint('🔓 Lock released for video recording');
    }
  }

  void _pickVideo() async {
    // LOCK: Check if another media operation is in progress
    if (_isMediaOperationInProgress) {
      debugPrint('⏸️ Media operation already in progress, blocking...');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Please wait for previous upload to complete',
        );
      }
      return;
    }

    try {
      _isMediaOperationInProgress = true; // Acquire lock
      debugPrint('🔐 Lock acquired for video picker');

      // Check daily limit first
      final wouldExceed = await _wouldExceedLimit('video', 1);
      if (wouldExceed) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye.',
          );
        }
        return;
      }

      // ⚠️ Don't increment counter yet - wait for user to actually pick videos!

      // Pick multiple videos using pickMultipleMedia (max 4)
      final List<XFile> mediaFiles = await _imagePicker.pickMultipleMedia(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );

      if (!mounted) return;

      if (mediaFiles.isEmpty) {
        // Restore focus to message input
        if (mounted) {
          FocusScope.of(context).requestFocus(_messageFocusNode);
        }
        return;
      }

      // Filter only video files
      final List<File> videoFiles = [];
      for (final media in mediaFiles) {
        final path = media.path.toLowerCase();
        if (path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm') ||
            path.endsWith('.3gp')) {
          videoFiles.add(File(media.path));
        }
      }

      if (videoFiles.isEmpty) {
        if (mounted) {
          SnackBarHelper.showError(context, 'No video files selected');
        }
        return;
      }

      // Limit to max 4 videos
      final selectedVideos = videoFiles.take(4).toList();

      if (videoFiles.length > 4 && mounted) {
        SnackBarHelper.showInfo(
          context,
          'Maximum 4 videos allowed. First 4 videos selected.',
        );
      }

      // Validate each video (size + duration)
      final List<File> validVideos = [];
      for (final videoFile in selectedVideos) {
        // Small delay before file operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Check if file exists
        bool fileExists = false;
        try {
          fileExists = await videoFile.exists();
        } catch (e) {
          debugPrint('File exists check error: $e');
          continue;
        }

        if (!fileExists) continue;

        // Check file size before upload
        int fileSize = 0;
        try {
          fileSize = await videoFile.length();
        } catch (e) {
          debugPrint('File size check error: $e');
          continue;
        }

        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 25) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video "${videoFile.path.split('/').last}" too large (${fileSizeMB.toStringAsFixed(1)}MB). Max 25MB.',
            );
          }
          continue;
        }

        if (fileSizeMB == 0) continue;

        // Check video duration (max 28 seconds)
        final controller = VideoPlayerController.file(videoFile);
        try {
          await controller.initialize();
          final duration = controller.value.duration;

          if (duration.inSeconds > 28) {
            if (mounted) {
              SnackBarHelper.showError(
                context,
                'Video too long (${duration.inSeconds}s). Maximum 28 seconds allowed.',
              );
            }
            await controller.dispose();
            continue;
          }

          await controller.dispose();
          debugPrint(
            'Video validated: ${duration.inSeconds}s, ${fileSizeMB.toStringAsFixed(1)}MB',
          );

          validVideos.add(videoFile);
        } catch (e) {
          debugPrint('Error checking video duration: $e');
          await controller.dispose();
          continue;
        }
      }

      if (validVideos.isEmpty) {
        if (mounted) {
          SnackBarHelper.showError(context, 'No valid videos to send');
        }
        return;
      }

      // ✅ Valid videos found - NOW increment counter
      await _incrementMediaCounter('video', 1);
      debugPrint(
        '✅ Counter incremented for video upload (user confirmed selection)',
      );

      // Show preview screen for multiple videos
      if (mounted) {
        _showMediaPreviewScreen(validVideos, isVideo: true);
      }
    } catch (e) {
      debugPrint('Video pick error: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to pick video. Please try again.',
        );
      }
    } finally {
      _isMediaOperationInProgress = false; // Always release lock
      debugPrint('🔓 Lock released for video picker');
    }
  }

  /// Show media preview screen (WhatsApp-style) before sending multiple images/videos
  void _showMediaPreviewScreen(List<File> mediaFiles, {required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MediaPreviewScreen(
          mediaFiles: mediaFiles,
          isVideo: isVideo,
          onSend: (filesToSend) {
            // Send each file
            for (final file in filesToSend) {
              if (isVideo) {
                _uploadAndSendVideo(file);
              } else {
                _uploadAndSendImage(file);
              }
            }
          },
        ),
      ),
    ).then((_) {
      // Restore focus to message input
      if (mounted) {
        FocusScope.of(context).requestFocus(_messageFocusNode);
      }
    });
  }

  Future<void> _uploadAndSendVideo(File videoFile) async {
    final currentUserId = _currentUserId;
    final conversationId = _conversationId;
    if (currentUserId == null || conversationId == null) return;

    final optimisticId =
        'optimistic_video_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = {
      'id': optimisticId,
      'senderId': currentUserId,
      'receiverId': widget.otherUser.uid,
      'text': '',
      'videoUrl': videoFile.path,
      'isLocalFile': true,
      'timestamp': Timestamp.now(),
      'isOptimistic': true,
    };

    setState(() {
      _optimisticMessages.add(optimisticMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _uploadAndSendVideoBackground(
      videoFile,
      optimisticId,
      currentUserId,
      conversationId,
    );
  }

  Future<void> _uploadAndSendVideoBackground(
    File videoFile,
    String optimisticId,
    String currentUserId,
    String conversationId,
  ) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.mp4';
      final ref = _storage.ref().child('chat_videos/$conversationId/$fileName');

      final uploadTask = ref.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );
      final snapshot = await uploadTask;

      if (!mounted) return;
      final videoUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'receiverId': widget.otherUser.uid,
            'text': '',
            'mediaUrl': videoUrl,
            'type': MessageType.video.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.delivered.index,
            'read': false,
            'isRead': false,
          });

      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });

      final currentUserProfile = this.ref
          .read(currentUserProfileProvider)
          .valueOrNull;
      final currentUserName = currentUserProfile?.name ?? 'Someone';
      NotificationService()
          .sendNotificationToUser(
            userId: widget.otherUser.uid,
            title: 'New Video from $currentUserName',
            body: '🎥 Video',
            type: 'message',
            data: {'conversationId': conversationId},
          )
          .catchError((_) {});

      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
      }

      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (videoFile.path.contains('cache') && await videoFile.exists()) {
            await videoFile.delete();
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error uploading video: $e');
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
        if (context.mounted) {
          SnackBarHelper.showError(context, 'Failed to send video');
        }
      }
    }
  }

  // Send image message with optimistic update
  Future<void> _uploadAndSendImage(File imageFile) async {
    final currentUserId = _currentUserId;
    final conversationId = _conversationId;
    if (currentUserId == null || conversationId == null) return;

    // Create optimistic message ID
    final optimisticId =
        'optimistic_image_${DateTime.now().millisecondsSinceEpoch}';

    // Create optimistic message - show immediately with local file
    final optimisticMessage = {
      'id': optimisticId,
      'senderId': currentUserId,
      'receiverId': widget.otherUser.uid,
      'text': '',
      'imageUrl': imageFile.path, // Local file path for immediate display
      'isLocalFile': true, // Flag to indicate this is a local file
      'timestamp': Timestamp.now(),
      'isOptimistic': true,
    };

    // Add optimistic message and show immediately
    setState(() {
      _optimisticMessages.add(optimisticMessage);
    });

    // Scroll to show the new message immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Start upload in background (don't block UI)
    _uploadAndSendImageBackground(
      imageFile,
      optimisticId,
      currentUserId,
      conversationId,
    );
  }

  // Separate method to handle image upload in background
  Future<void> _uploadAndSendImageBackground(
    File imageFile,
    String optimisticId,
    String currentUserId,
    String conversationId,
  ) async {
    try {
      debugPrint('Starting image upload...');
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final storageRef = _storage.ref().child(
        'chat_images/$conversationId/$fileName',
      );

      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;

      if (!mounted) return;
      final imageUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Image uploaded, URL: $imageUrl');

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'receiverId': widget.otherUser.uid,
            'text': '',
            'mediaUrl': imageUrl,
            'type': MessageType.image.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.delivered.index,
            'read': false,
            'isRead': false,
          });

      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });

      final currentUserProfile = this.ref
          .read(currentUserProfileProvider)
          .valueOrNull;
      final currentUserName = currentUserProfile?.name ?? 'Someone';
      NotificationService()
          .sendNotificationToUser(
            userId: widget.otherUser.uid,
            title: 'New Photo from $currentUserName',
            body: '📷 Photo',
            type: 'message',
            data: {'conversationId': conversationId},
          )
          .catchError((_) {});

      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
      }

      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (imageFile.path.contains('cache') && await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
        if (context.mounted) {
          SnackBarHelper.showError(context, 'Failed to send image');
        }
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Microphone permission is required for voice messages',
          );
        }
        return;
      }

      // Initialize recorder if not already
      if (!_isRecorderInitialized || _audioRecorder == null) {
        try {
          _audioRecorder = FlutterSoundRecorder();
          await _audioRecorder!.openRecorder();
          _isRecorderInitialized = true;
        } catch (e) {
          debugPrint('Error opening recorder: $e');
          if (mounted) {
            SnackBarHelper.showError(context, 'Failed to initialize recorder');
          }
          return;
        }
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_message_$timestamp.aac';

      // Start recording with optimized bitrate for faster upload
      await _audioRecorder!.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacADTS,
        bitRate: 64000, // 64kbps - good quality voice, smaller file size
        sampleRate: 22050, // 22kHz - sufficient for voice
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to start recording');
      }
    }
  }

  Future<void> _showVoiceRecordingPopup() async {
    // Stop the timer but keep recording state
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = _recordingDuration;

    // Stop recorder and get path safely
    String? path;
    try {
      path = await _audioRecorder?.stopRecorder();
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
    }

    if (path == null || path.isEmpty) return;

    // Store non-nullable reference for use in closures
    final audioPath = path;

    // Initialize player if needed
    _audioPlayer ??= FlutterSoundPlayer();

    // Show small centered popup with audio preview
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _VoicePreviewPopup(
        audioPath: audioPath,
        duration: duration,
        audioPlayer: _audioPlayer!,
        isPlayerInitialized: _isPlayerInitialized,
        onInitializePlayer: () async {
          if (!_isPlayerInitialized && _audioPlayer != null) {
            await _audioPlayer!.openPlayer();
            await _audioPlayer!.setSubscriptionDuration(
              const Duration(milliseconds: 100),
            );
            _isPlayerInitialized = true;
          }
        },
        onSend: () async {
          Navigator.pop(context);
          await _sendVoiceMessage(audioPath, duration);
        },
        onCancel: () {
          Navigator.pop(context);
          try {
            File(audioPath).deleteSync();
          } catch (_) {}
        },
      ),
    );
  }

  String _formatRecordingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendVoiceMessage(String filePath, int audioDuration) async {
    final currentUserId = _currentUserId;
    final conversationId = _conversationId;
    if (currentUserId == null || conversationId == null) return;

    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Recording file not found');
      }
      return;
    }

    // 🔒 LOCK: Check if another media operation is in progress
    if (_isMediaOperationInProgress) {
      debugPrint('⏸️ Media operation already in progress, blocking audio...');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Please wait for previous upload to complete',
        );
      }
      return;
    }

    // 📊 Check daily limit BEFORE uploading (4 audio messages per day)
    final wouldExceed = await _wouldExceedLimit('audio', 1);
    if (wouldExceed) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye.',
        );
      }
      // Delete the recorded file since we're not sending it
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Error deleting audio file: $e');
      }
      return;
    }

    // ✅ Passed limit check - increment counter
    await _incrementMediaCounter('audio', 1);

    // 🔐 Acquire media operation lock
    _isMediaOperationInProgress = true;
    debugPrint('🔐 Lock acquired for audio upload');

    final optimisticId =
        'optimistic_voice_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = {
      'id': optimisticId,
      'senderId': currentUserId,
      'receiverId': widget.otherUser.uid,
      'text': '',
      'voiceUrl': filePath,
      'voiceDuration': audioDuration,
      'isLocalFile': true,
      'timestamp': Timestamp.now(),
      'isOptimistic': true,
    };

    setState(() {
      _optimisticMessages.add(optimisticMessage);
      _recordingDuration = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _uploadAndSendVoiceBackground(
      file,
      optimisticId,
      currentUserId,
      conversationId,
      audioDuration,
    );
  }

  Future<void> _uploadAndSendVoiceBackground(
    File file,
    String optimisticId,
    String currentUserId,
    String conversationId,
    int audioDuration,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_${currentUserId}_$timestamp.aac';
      final storageRef = _storage
          .ref()
          .child('voice_messages')
          .child(conversationId)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );
      final snapshot = await uploadTask;
      final audioUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'receiverId': widget.otherUser.uid,
            'text': '',
            'audioUrl': audioUrl,
            'audioDuration': audioDuration,
            'type': MessageType.audio.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.delivered.index,
            'read': false,
          });

      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      NotificationService()
          .sendNotificationToUser(
            userId: widget.otherUser.uid,
            title: 'New Voice Message',
            body: 'You received a voice message',
            type: 'message',
            data: {'conversationId': conversationId},
          )
          .catchError((_) {});

      await file.delete();

      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
      }
    } catch (e) {
      debugPrint('Error uploading voice message: $e');
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticId);
        });
        if (context.mounted) {
          SnackBarHelper.showError(context, 'Failed to send voice message');
        }
      }
    } finally {
      // 🔓 Always release the media operation lock
      _isMediaOperationInProgress = false;
      debugPrint('🔓 Lock released for audio upload');
    }
  }

  // Audio playback methods
  Future<void> _playAudio(String messageId, String audioUrl) async {
    try {
      // Initialize player if null
      _audioPlayer ??= FlutterSoundPlayer();

      // If same message is playing, toggle pause/resume
      if (_currentlyPlayingMessageId == messageId && _isPlaying) {
        await _audioPlayer!.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      // If different message or not playing, stop current and play new
      if (_isPlaying) {
        await _audioPlayer!.stopPlayer();
      }

      // Initialize player if needed
      if (!_isPlayerInitialized) {
        await _audioPlayer!.openPlayer();
        _isPlayerInitialized = true;
      }

      // Set fast subscription for smooth waveform animation
      await _audioPlayer!.setSubscriptionDuration(
        const Duration(milliseconds: 50),
      );

      // Subscribe to playback progress BEFORE starting
      _playerSubscription?.cancel();
      _playerSubscription = _audioPlayer!.onProgress!.listen((e) {
        if (mounted && e.duration.inMilliseconds > 0) {
          setState(() {
            _playbackProgress =
                e.position.inMilliseconds / e.duration.inMilliseconds;
          });
        }
      });

      setState(() {
        _currentlyPlayingMessageId = messageId;
        _isPlaying = true;
        _playbackProgress = 0.0;
      });

      await _audioPlayer!.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingMessageId = null;
              _playbackProgress = 0.0;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to play audio');
      }
    }
  }

  /// Build image message with WhatsApp-style upload preview
  /// Shows local image immediately with blur/progress overlay while uploading
  Widget _buildImageMessage(MessageModel message, bool isMe, bool isDarkMode) {
    final hasMediaUrl =
        message.mediaUrl != null && message.mediaUrl!.isNotEmpty;
    final isLocalFile = message.metadata?['isLocalFile'] == true;
    final isOptimistic = message.metadata?['isOptimistic'] == true;

    // Use local file for optimistic messages, network URL for delivered messages
    final imageSource = isLocalFile
        ? message.mediaUrl
        : hasMediaUrl
        ? message.mediaUrl
        : null;

    if (imageSource == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF007AFF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
          child: Stack(
            children: [
              // Show local file or network image
              isLocalFile
                  ? Image.file(File(imageSource), width: 200, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: imageSource,
                      width: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 200,
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 200,
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
              // Upload overlay for optimistic messages
              if (isOptimistic)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessagePlayer(
    MessageModel message,
    bool isMe,
    bool isDarkMode,
  ) {
    final isOptimistic = message.metadata?['isOptimistic'] == true;
    final videoUrl = message.mediaUrl;

    return GestureDetector(
      onTap: isOptimistic
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _VideoPlayerScreen(videoUrl: videoUrl!),
                ),
              );
            },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isOptimistic
                ? Colors.orange.withOpacity(0.5)
                : const Color(0xFF007AFF),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Video thumbnail or placeholder
            Container(
              width: 200,
              height: 150,
              color: Colors.black,
              child: const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
            // Upload overlay
            if (isOptimistic)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Uploading...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build deleted message bubble (WhatsApp-style "This message was deleted")
  Widget _buildDeletedMessageBubble(
    MessageModel message,
    bool isMe,
    bool isDarkMode,
  ) {
    final isSelected = _selectedMessageIds.contains(message.id);

    Widget deletedBubble = Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: _isMultiSelectMode
                ? null
                : () => _showDeletedMessageOptions(message),
            onTap: _isMultiSelectMode
                ? () => _toggleMessageSelection(message.id)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.5)
                    : Colors.grey.shade300.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700.withValues(alpha: 0.5)
                      : Colors.grey.shade400.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 14,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'This message was deleted',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Wrap with multi-select UI if in selection mode
    if (_isMultiSelectMode) {
      return GestureDetector(
        onTap: () => _toggleMessageSelection(message.id),
        child: Container(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.15)
              : Colors.transparent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blue : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.white54,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              Expanded(child: deletedBubble),
            ],
          ),
        ),
      );
    }

    return deletedBubble;
  }

  /// Show options for deleted message (delete for me, delete for everyone, select)
  void _showDeletedMessageOptions(MessageModel message) async {
    HapticFeedback.mediumImpact();
    final isMyMessage = message.senderId == _currentUserId;

    // Create select button as extra widget
    final selectButton = GestureDetector(
      onTap: () {
        Navigator.pop(context, 'select');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Text(
            'Select',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    final result = await _showDeleteDialog(
      title: 'Delete message?',
      showDeleteForEveryone: isMyMessage,
      extraWidget: selectButton,
    );

    if (result == 'for_me') {
      _deleteMessageForMe(message);
    } else if (result == 'for_everyone') {
      _deleteAlreadyDeletedMessageForEveryone(message);
    } else if (result == 'select') {
      _enterMultiSelectMode(message.id);
    }
  }

  /// Delete already deleted message completely for everyone
  Future<void> _deleteAlreadyDeletedMessageForEveryone(
    MessageModel message,
  ) async {
    if (_conversationId == null) return;

    // Remove from UI immediately
    _loadedMessages.removeWhere((doc) => doc.id == message.id);
    _allMessages.removeWhere((m) => m.id == message.id);
    if (mounted) setState(() {});

    try {
      // Completely delete from Firestore
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(message.id)
          .delete();

      // Update last message if needed
      await _updateLastMessageAfterDelete();
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
    }
  }

  /// Build WhatsApp-style call message UI (left for incoming, right for outgoing)
  Widget _buildCallMessageBubble(
    MessageModel message,
    bool isMe,
    bool isDarkMode,
  ) {
    //  Filter out empty/invalid call messages to prevent blank UI
    if (message.text == null ||
        message.text!.isEmpty ||
        message.text!.trim().isEmpty) {
      debugPrint(
        ' Skipping empty call message: id=${message.id}, text="${message.text}"',
      );
      return const SizedBox.shrink(); // Return empty widget (no UI)
    }

    debugPrint(
      ' Call message alignment: isMe=$isMe (${isMe ? "OUTGOING-RIGHT" : "INCOMING-LEFT"}), senderId=${message.senderId}, currentUserId=$_currentUserId',
    );

    final isMissed = message.type == MessageType.missedCall;
    bool isVideoCall = message.type == MessageType.videoCall;
    final isVoiceCall = message.type == MessageType.voiceCall;

    // For missed calls, check text content to determine if video or audio
    if (isMissed && message.text != null) {
      final textLower = message.text!.toLowerCase();
      if (textLower.contains('video')) {
        isVideoCall = true;
      }
    }

    // Debug: Print message type details
    debugPrint(
      ' Message Type: ${message.type}, isMissed: $isMissed, isVideoCall: $isVideoCall, isVoiceCall: $isVoiceCall, text: ${message.text}',
    );

    final isSelected = _selectedMessageIds.contains(message.id);

    // isMe means current user was the CALLER (senderId = current user)
    // !isMe means current user was the RECEIVER

    // Determine call text, icon, and color based on call type (WhatsApp style)
    String callLabel; // "Incoming" or "Outgoing" or "Missed"
    String callDurationText; // Duration like "0:45" or status text
    IconData callIcon;
    IconData directionIcon; // Arrow icon for direction
    Color iconColor;

    if (isMissed) {
      //   Missed call - RED color for all missed calls
      iconColor = Colors.red;

      if (isMe) {
        // Caller viewing their outgoing missed call (cancelled/no answer)
        callLabel = 'Outgoing';
        callDurationText = isVideoCall ? 'Video call, cancelled' : 'Cancelled';
        callIcon = isVideoCall ? Icons.videocam : Icons.phone;
        directionIcon = Icons.call_made; // Outgoing arrow
      } else {
        // Receiver viewing their missed incoming call
        callLabel = 'Missed';
        callDurationText = isVideoCall ? 'Video call' : 'Voice call';
        callIcon = Icons.phone_missed;
        directionIcon = Icons.call_received; // Incoming arrow
      }
    } else {
      //   Answered call - GREEN color for all answered calls
      iconColor = const Color(0xFF25D366); // WhatsApp green

      debugPrint(
        '  Setting GREEN color for answered call: isVideoCall=$isVideoCall',
      );

      // Determine if incoming or outgoing
      callLabel = isMe ? 'Outgoing' : 'Incoming';
      directionIcon = isMe ? Icons.call_made : Icons.call_received;

      // Extract duration from stored text or show default
      final storedText = message.text ?? '';
      if (storedText.isNotEmpty && !storedText.contains('call')) {
        callDurationText = storedText; // Duration like "0:45" or "1:23"
      } else {
        callDurationText = isVideoCall ? 'Video call' : 'Voice call';
      }

      // Set GREEN icons for answered calls
      if (isVideoCall) {
        callIcon = Icons.videocam;
      } else {
        callIcon = Icons.phone;
      }
    }

    // Debug: Print complete icon details with actual color values
    final colorHex = iconColor == Colors.red
        ? 'RED'
        : (iconColor == const Color(0xFF25D366) ? 'GREEN(#25D366)' : 'UNKNOWN');
    debugPrint(
      '  Call Icon: $callIcon, Color: $colorHex, isMissed: $isMissed, isVideoCall: $isVideoCall, isMe: $isMe, label: "$callLabel", duration: "$callDurationText"',
    );

    // Sanity check: Verify iconColor is actually set
    assert(
      iconColor == Colors.red || iconColor == const Color(0xFF25D366),
      'Icon color must be either RED or GREEN, but got: $iconColor',
    );

    // WhatsApp-style call widget (exact replica)
    final callWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1F2C33)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Call icon inside circular background (WhatsApp style)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              callIcon,
              size: 20,
              color: iconColor,
              semanticLabel: 'Call icon',
            ),
          ),
          const SizedBox(width: 10),
          // WhatsApp-style call info: direction + label, duration, time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // First line: Direction arrow + Call label (Incoming/Outgoing/Missed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(directionIcon, size: 14, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    callLabel,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Second line: Call duration or status
              Text(
                callDurationText,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : const Color(0xFF667781),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              // Third line: Time
              Text(
                _formatMessageTime(message.timestamp),
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFF8696A0)
                      : const Color(0xFF667781),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // If in multi-select mode, show checkbox
    if (_isMultiSelectMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: GestureDetector(
          onTap: () => _toggleMessageSelection(message.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.blue : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.white54,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
                callWidget,
              ],
            ),
          ),
        ),
      );
    }

    // Normal mode - WhatsApp style: outgoing (right), incoming (left)
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 60 : 16,
        right: isMe ? 16 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              // Tap to call back
              _showCallBackConfirmation(isVideoCall: isVideoCall);
            },
            onLongPress: () => _showCallDeleteConfirmation(message),
            child: callWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessagePlayer(
    MessageModel message,
    bool isMe, {
    bool isDarkMode = true,
  }) {
    final isOptimistic = message.metadata?['isOptimistic'] == true;
    final isCurrentlyPlaying =
        _currentlyPlayingMessageId == message.id && _isPlaying;
    final isThisMessage = _currentlyPlayingMessageId == message.id;
    final progress = isThisMessage ? _playbackProgress : 0.0;
    final duration = message.audioDuration ?? 0;

    // Format duration
    String formatDuration(int seconds) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    // Waveform bar heights pattern (30 bars for WhatsApp style)
    final heights = [
      6.0,
      10.0,
      8.0,
      14.0,
      10.0,
      16.0,
      12.0,
      14.0,
      8.0,
      18.0,
      14.0,
      10.0,
      16.0,
      6.0,
      12.0,
      10.0,
      14.0,
      8.0,
      10.0,
      8.0,
      12.0,
      14.0,
      10.0,
      16.0,
      12.0,
      8.0,
      14.0,
      10.0,
      12.0,
      8.0,
    ];

    // Audio player WhatsApp style - gradient background
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMe
              ? [const Color(0xFF5856D6), const Color(0xFF007AFF)]
              : [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button (or loading indicator)
          GestureDetector(
            onTap: isOptimistic
                ? null
                : () => _playAudio(message.id, message.audioUrl!),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isOptimistic
                    ? Colors.orange.withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: isOptimistic
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      isCurrentlyPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: isMe
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF3A3A3A),
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // Waveform bars
          Expanded(
            child: SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(25, (index) {
                  final barProgress = index / 25;
                  final isActive = barProgress <= progress;
                  // Use modulo to cycle through heights array
                  final heightIndex = index % heights.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 2,
                    height: heights[heightIndex] * 0.8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Duration
          Text(
            formatDuration(duration),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _startAudioCall() async {
    // Prevent multiple rapid clicks
    if (_isStartingCall) {
      debugPrint('  Call already being initiated, ignoring duplicate request');
      return;
    }

    setState(() => _isStartingCall = true);

    try {
      // Check if user already has an active call (single device/call restriction)
      final activeCallsQuery = await _firestore
          .collection('calls')
          .where('participants', arrayContains: _currentUserId)
          .where('status', whereIn: ['calling', 'ringing', 'connected'])
          .limit(1)
          .get();

      if (activeCallsQuery.docs.isNotEmpty) {
        // User already has an active call
        debugPrint('  User already has an active call, cannot start new call');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active call'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() => _isStartingCall = false);
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking active calls: $e');
      if (mounted) {
        setState(() => _isStartingCall = false);
      }
      return; // Don't continue if check fails
    }

    final currentUserProfile = ref.read(currentUserProfileProvider).valueOrNull;
    final callerName = currentUserProfile?.name ?? 'Someone';

    // Create a call document in Firestore
    debugPrint(
      '  Creating call: Caller=$_currentUserId -> Receiver=${widget.otherUser.uid}',
    );
    final callDoc = await _firestore.collection('calls').add({
      'callerId': _currentUserId,
      'receiverId': widget.otherUser.uid,
      'callerName': callerName,
      'callerPhoto': currentUserProfile?.photoUrl,
      'receiverName': widget.otherUser.name,
      'receiverPhoto': widget.otherUser.photoUrl,
      'participants': [
        _currentUserId,
        widget.otherUser.uid,
      ], // Required for Calls tab query
      'status': 'calling',
      'type': 'audio',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('  Call document created with ID: ${callDoc.id}');

    if (!mounted) return;

    // Send call notification to receiver (don't await - fire and forget for speed)
    NotificationService().sendNotificationToUser(
      userId: widget.otherUser.uid,
      title: 'Incoming Call',
      body: '$callerName is calling you',
      type: 'call',
      data: {
        'callId': callDoc.id,
        'callerId': _currentUserId,
        'callerName': callerName,
        'callerPhoto': currentUserProfile?.photoUrl,
      },
    );

    // Navigate to voice call screen and wait for result
    debugPrint(
      '  EnhancedChatScreen: Starting voice call - otherUser: ${widget.otherUser.name} (${widget.otherUser.uid}), currentUserId: $_currentUserId',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callId: callDoc.id,
          otherUser: widget.otherUser,
          isOutgoing: true,
        ),
      ),
    );

    if (mounted) {
      setState(() => _isStartingCall = false);
      _checkCallStatusAndAddMessage(callDoc.id, isVideo: false);
    }
  }

  void _startVideoCall() async {
    // Video calling functionality disabled - silently ignore
    return;

    // Original code kept for reference (disabled)
    /*
    final currentUserProfile = ref.read(currentUserProfileProvider).valueOrNull;
    final callerName = currentUserProfile?.name ?? 'Someone';

    // Create a call document in Firestore
    final callDoc = await _firestore.collection('calls').add({
      'callerId': _currentUserId,
      'receiverId': widget.otherUser.uid,
      'callerName': callerName,
      'callerPhoto': currentUserProfile?.photoUrl,
      'receiverName': widget.otherUser.name,
      'receiverPhoto': widget.otherUser.photoUrl,
      'participants': [
        _currentUserId,
        widget.otherUser.uid,
      ], // Required for Calls tab query
      'status': 'calling',
      'type': 'video',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    // Send call notification to receiver (don't await - fire and forget for speed)
    NotificationService().sendNotificationToUser(
      userId: widget.otherUser.uid,
      title: 'Incoming Video Call',
      body: '$callerName is video calling you',
      type: 'video_call',
      data: {
        'callId': callDoc.id,
        'callerId': _currentUserId,
        'callerName': callerName,
        'callerPhoto': currentUserProfile?.photoUrl,
        'isVideo': true,
      },
    );

    // Navigate to video call screen and wait for result
    debugPrint(
      '  EnhancedChatScreen: Starting video call - otherUser: ${widget.otherUser.name} (${widget.otherUser.uid}), currentUserId: $_currentUserId',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: callDoc.id,
          otherUser: widget.otherUser,
          isOutgoing: true,
        ),
      ),
    );

    if (mounted) {
      _checkCallStatusAndAddMessage(callDoc.id, isVideo: true);
    }
    */
  }

  Future<void> _checkCallStatusAndAddMessage(
    String callId, {
    required bool isVideo,
  }) async {
    if (_conversationId == null || _currentUserId == null) return;

    try {
      // Small delay to ensure Firestore update from call screen has propagated
      await Future.delayed(const Duration(milliseconds: 500));

      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        debugPrint('  Call document not found: $callId');
        return;
      }

      final data = callDoc.data()!;
      final status = data['status'] as String?;
      final duration = data['duration']; // dynamic
      final callerId = data['callerId'] as String?;
      final receiverId = data['receiverId'] as String?;

      //   CRITICAL FIX: Only create message if current user is the CALLER
      // This prevents duplicate messages from being created on both devices
      // The receiver should NOT create a message - only the caller creates it
      if (callerId != _currentUserId) {
        debugPrint(
          '  BLOCKED: Not creating call message because current user ($_currentUserId) is NOT the caller ($callerId)',
        );
        return;
      }

      debugPrint(
        '  Call Status: $status, Duration: $duration, isVideo: $isVideo, CallId: $callId',
      );
      debugPrint('  Full call data: $data');
      debugPrint(
        '  CallerId: $callerId, ReceiverId: $receiverId, CurrentUserId: $_currentUserId',
      );

      int durationSeconds = 0;
      if (duration is int) {
        durationSeconds = duration;
      } else if (duration is double) {
        durationSeconds = duration.toInt();
      }

      MessageType msgType;
      String msgText;

      //   Safety check: if status is null/empty, don't create message
      if (status == null || status.isEmpty) {
        debugPrint(
          '  Call status is null/empty, skipping message creation for callId: $callId',
        );
        return;
      }

      // Determine message type and text based on status
      if (status == 'ended' || status == 'completed') {
        // Call was answered/connected - always voiceCall or videoCall type (GREEN)
        msgType = isVideo ? MessageType.videoCall : MessageType.voiceCall;
        msgText = durationSeconds > 0
            ? _formatCallDuration(durationSeconds)
            : (isVideo ? 'Video call' : 'Voice call');
      } else if (status == 'rejected' ||
          status == 'declined' ||
          status == 'busy') {
        // Call was rejected - missedCall type (RED)
        msgType = MessageType.missedCall;
        msgText = isVideo ? 'Video call declined' : 'Voice call declined';
      } else if (status == 'missed' ||
          status == 'timeout' ||
          status == 'canceled' ||
          status == 'no_answer') {
        // Call was not answered - missedCall type (RED)
        msgType = MessageType.missedCall;
        msgText = isVideo ? 'Missed video call' : 'Missed voice call';
      } else {
        // Fallback - if duration > 0, treat as answered call (GREEN)
        if (durationSeconds > 0) {
          msgType = isVideo ? MessageType.videoCall : MessageType.voiceCall;
          msgText = _formatCallDuration(durationSeconds);
        } else {
          // No duration and unknown status - treat as missed (RED)
          msgType = MessageType.missedCall;
          msgText = isVideo ? 'Missed video call' : 'Missed voice call';
        }
      }

      //   Final safety check: ensure msgText is not empty
      if (msgText.isEmpty) {
        debugPrint(
          '  msgText is empty after status check, status=$status, skipping message creation',
        );
        return;
      }

      //   Use deterministic message ID to prevent duplicates
      // If this function is called multiple times for same call, it will update instead of creating duplicates
      final messageId = 'call_$callId';

      //   CRITICAL: Triple-check msgText before saving (prevent empty messages)
      if (msgText.trim().isEmpty) {
        debugPrint(
          '  BLOCKED: Attempted to save call message with empty text! callId=$callId, status=$status',
        );
        return;
      }

      // Add message to conversation
      debugPrint(
        '💾 Saving call message: id=$messageId, type=${msgType.index}, text="$msgText", status=$status',
      );

      //   Determine correct senderId based on who initiated the call
      // If current user is the caller, they are the sender
      // If current user is the receiver, the other person is the sender
      final messageSenderId = (callerId == _currentUserId)
          ? _currentUserId
          : widget.otherUser.uid;
      final messageReceiverId = (callerId == _currentUserId)
          ? widget.otherUser.uid
          : _currentUserId;

      debugPrint(
        '💡 Message will be saved with senderId=$messageSenderId (caller=$callerId, currentUser=$_currentUserId)',
      );

      //   Use merge: true to avoid overwriting existing data if message already exists
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(messageId) // Use deterministic ID instead of .add()
          .set({
            'senderId': messageSenderId, //   FIXED: Use caller as sender
            'receiverId': messageReceiverId,
            'chatId': _conversationId,
            'text':
                msgText, // This will NEVER be empty due to triple-check above
            'type': msgType.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.sent.index,
            'read': false,
            'isRead': false,
            'callId': callId,
            'callDuration': durationSeconds,
          }, SetOptions(merge: true)); // Merge to avoid data loss if doc exists
      debugPrint('  Call message saved successfully with ID: $messageId');

      // Update last message in conversation
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .update({
            'lastMessage': isVideo ? '📹 Video call' : '  Voice call',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': _currentUserId,
          });
    } catch (e) {
      debugPrint('Error adding call message: $e');
    }
  }

  ///   Real-time guard: Delete empty call messages as soon as they appear
  void _setupEmptyMessageGuard() {
    if (_conversationId == null) return;

    // Listen to all new call messages in real-time
    _firestore
        .collection('conversations')
        .doc(_conversationId!)
        .collection('messages')
        .where(
          'type',
          whereIn: [
            MessageType.voiceCall.index,
            MessageType.videoCall.index,
            MessageType.missedCall.index,
          ],
        )
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            // Check only newly added or modified messages
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final doc = change.doc;
              final data = doc.data();
              if (data != null) {
                final text = data['text'] as String?;

                // If empty call message detected, delete it immediately
                if (text == null || text.trim().isEmpty) {
                  debugPrint(
                    '🚨 GUARD: Empty call message detected! Deleting immediately: ${doc.id}',
                  );
                  doc.reference
                      .delete()
                      .then((_) {
                        debugPrint('  GUARD: Empty message deleted: ${doc.id}');
                      })
                      .catchError((e) {
                        debugPrint(
                          '  GUARD: Failed to delete empty message: $e',
                        );
                      });
                }
              }
            }
          }
        });
  }

  // ========== DAILY MEDIA COUNTER METHODS (SharedPreferences-based) ==========

  /// Initialize counter with smart retry mechanism
  void _initializeCounterWithRetry() {
    debugPrint('🔄 ========== COUNTER INITIALIZATION STARTED ==========');
    debugPrint('🔄 Attempting to load counters with retry mechanism...');

    // Attempt 1: Immediate (likely to fail on cold start)
    debugPrint('🔄 Attempt 1: Immediate load');
    _loadDailyMediaCounts();

    // Attempt 2: After first frame (auth might be ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCounterLoaded && mounted) {
        debugPrint(
          '🔄 Attempt 2: Post-frame callback (userId may be ready now)',
        );
        _loadDailyMediaCounts();
      } else if (_isCounterLoaded) {
        debugPrint('✅ Counter already loaded in Attempt 1, skipping retry');
      }
    });

    // Attempt 3: After 300ms (auth should definitely be ready)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isCounterLoaded && mounted) {
        debugPrint('🔄 Attempt 3: 300ms delayed retry (auth should be ready)');
        _loadDailyMediaCounts();
      } else if (_isCounterLoaded) {
        debugPrint('✅ Counter already loaded, skipping 300ms retry');
      }
    });

    // Attempt 4: Final retry after 1 second (fallback)
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isCounterLoaded && mounted) {
        debugPrint('🔄 Attempt 4: 1s delayed retry (FINAL ATTEMPT)');
        _loadDailyMediaCounts();
      } else if (_isCounterLoaded) {
        debugPrint('✅ Counter already loaded, no need for final retry');
      }

      // After final attempt, report status
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isCounterLoaded) {
          debugPrint('🎉 🎉 COUNTER SUCCESSFULLY LOADED! 🎉 🎉');
        } else {
          debugPrint('⚠️ ⚠️ COUNTER FAILED TO LOAD AFTER ALL RETRIES! ⚠️ ⚠️');
        }
      });
    });
  }

  /// Load daily media counts from SharedPreferences
  Future<void> _loadDailyMediaCounts() async {
    debugPrint('📂 ========== LOADING COUNTERS (Enhanced Chat) ==========');
    final currentUserId = _currentUserId;
    final otherUserId =
        widget.otherUser.uid; // Use otherUser.uid instead of conversationId!
    debugPrint('📂 CurrentUserId: $currentUserId, OtherUserId: $otherUserId');
    debugPrint('📂 _isCounterLoaded: $_isCounterLoaded');
    debugPrint('📂 _isCounterLoading: $_isCounterLoading');

    if (currentUserId == null) {
      debugPrint('⚠️ ❌ Cannot load: currentUserId is null');
      _isCounterLoaded = false;
      return;
    }

    // Prevent duplicate loads - already loaded
    if (_isCounterLoaded) {
      debugPrint('⚠️ Counter already loaded, skipping');
      return;
    }

    // Prevent concurrent loads - already loading
    if (_isCounterLoading) {
      debugPrint('⚠️ Counter load in progress, skipping');
      return;
    }

    // Acquire loading lock
    _isCounterLoading = true;
    debugPrint('🔐 Counter loading lock acquired');

    try {
      final prefs = await SharedPreferences.getInstance();
      // Use sorted user IDs to ensure consistent key regardless of who opens chat first
      final key = currentUserId.compareTo(otherUserId) < 0
          ? '${currentUserId}_$otherUserId'
          : '${otherUserId}_$currentUserId';
      debugPrint('📂 Loading with key: $key');

      final imageCount = prefs.getInt('${key}_imageCount') ?? 0;
      final videoCount = prefs.getInt('${key}_videoCount') ?? 0;
      final audioCount = prefs.getInt('${key}_audioCount') ?? 0;
      final lastResetStr = prefs.getString('${key}_lastReset');

      debugPrint('📂 Raw values from SharedPreferences:');
      debugPrint('📂   Images: $imageCount');
      debugPrint('📂   Videos: $videoCount');
      debugPrint('📂   Audios: $audioCount');
      debugPrint('📂   LastReset: $lastResetStr');

      // Set loaded values
      _todayImageCount = imageCount;
      _todayVideoCount = videoCount;
      _todayAudioCount = audioCount;

      if (lastResetStr != null) {
        _lastMediaCountReset = DateTime.parse(lastResetStr);
        debugPrint('📂   Parsed lastReset: $_lastMediaCountReset');
      } else {
        debugPrint('📂   No lastReset found');
      }

      debugPrint(
        '📂 BEFORE reset check - Images=$_todayImageCount, Videos=$_todayVideoCount, Audios=$_todayAudioCount',
      );

      // Check if 24 hours passed and reset if needed
      await _resetDailyCountersIfNeeded();

      debugPrint(
        '📂 AFTER reset check - Images=$_todayImageCount, Videos=$_todayVideoCount, Audios=$_todayAudioCount',
      );

      _isCounterLoaded = true;
    } catch (e) {
      debugPrint('❌ ❌ Error loading media counts: $e');
      _isCounterLoaded = true; // Set to true even on error to prevent blocking
    } finally {
      // Always release the loading lock
      _isCounterLoading = false;
      debugPrint('🔓 Counter loading lock released');
    }
  }

  /// Save daily media counts to SharedPreferences
  Future<void> _saveDailyMediaCounts() async {
    final currentUserId = _currentUserId;
    final otherUserId = widget.otherUser.uid;
    if (currentUserId == null) {
      debugPrint('⚠️ Cannot save counts: currentUserId is null');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Use sorted user IDs to ensure consistent key (same as load)
      final key = currentUserId.compareTo(otherUserId) < 0
          ? '${currentUserId}_$otherUserId'
          : '${otherUserId}_$currentUserId';

      debugPrint('💾 SAVING to SharedPreferences:');
      debugPrint('💾   Key: $key');
      debugPrint('💾   Images: $_todayImageCount');
      debugPrint('💾   Videos: $_todayVideoCount');
      debugPrint('💾   Audios: $_todayAudioCount');

      await prefs.setInt('${key}_imageCount', _todayImageCount);
      await prefs.setInt('${key}_videoCount', _todayVideoCount);
      await prefs.setInt('${key}_audioCount', _todayAudioCount);

      if (_lastMediaCountReset != null) {
        await prefs.setString(
          '${key}_lastReset',
          _lastMediaCountReset!.toIso8601String(),
        );
        debugPrint('💾   LastReset: $_lastMediaCountReset');
      }
    } catch (e) {
      debugPrint('❌ ❌ Error saving media counts: $e');
      debugPrint('❌ Stack: ${StackTrace.current}');
    }
  }

  /// Reset daily counters if 24 hours passed
  Future<void> _resetDailyCountersIfNeeded() async {
    final now = DateTime.now();
    debugPrint('🕐 _resetDailyCountersIfNeeded called');
    debugPrint('🕐   Current time: $now');
    debugPrint('🕐   Last reset: $_lastMediaCountReset');

    // First time: just set the timestamp, don't reset counters
    if (_lastMediaCountReset == null) {
      debugPrint(
        '🕐   First time - setting timestamp (NOT resetting counters)',
      );
      debugPrint(
        '🕐   Current counters: Images=$_todayImageCount, Videos=$_todayVideoCount, Audios=$_todayAudioCount',
      );
      _lastMediaCountReset = now;
      await _saveDailyMediaCounts();
      debugPrint('🕐   ✅ Media counter timer started (counters preserved)');
      return;
    }

    final hoursSinceReset = now.difference(_lastMediaCountReset!).inHours;
    debugPrint('🕐   Hours since last reset: $hoursSinceReset');

    // After 24 hours: reset counters
    if (hoursSinceReset >= 24) {
      debugPrint('🔄   ⚠️ 24 hours passed - RESETTING COUNTERS');
      debugPrint(
        '🔄   Old values: Images=$_todayImageCount, Videos=$_todayVideoCount, Audios=$_todayAudioCount',
      );
      _todayImageCount = 0;
      _todayVideoCount = 0;
      _todayAudioCount = 0;
      _lastMediaCountReset = now;
      await _saveDailyMediaCounts();
      debugPrint('🔄   ✅ Daily media counters reset to 0');
    } else {
      debugPrint('🕐   ✅ Within 24 hours - counters preserved');
    }
  }

  /// Check if adding 'count' items would exceed daily limit (4 per day)
  Future<bool> _wouldExceedLimit(String mediaType, int count) async {
    debugPrint('🔍 ========== WOULD EXCEED CHECK START ==========');
    debugPrint('🔍 MediaType: $mediaType, Trying to add: $count');

    // Load counter if not loaded
    if (!_isCounterLoaded) {
      debugPrint('⚠️ Counter not loaded, loading now...');
      await _loadDailyMediaCounts();

      // CRITICAL: If still not loaded after retry, userId is still null
      // Block upload to prevent bypassing limit with counter = 0
      if (!_isCounterLoaded) {
        debugPrint('❌ BLOCKING: Counter still not loaded (userId likely null)');
        return true; // Block upload if we can't verify counter
      }
    }

    // Verify userId is available before proceeding
    if (_currentUserId == null) {
      debugPrint('❌ BLOCKING: userId is null, cannot verify limit');
      return true; // Block upload if userId is null
    }

    await _resetDailyCountersIfNeeded();

    final currentCount = mediaType == 'image'
        ? _todayImageCount
        : mediaType == 'video'
        ? _todayVideoCount
        : _todayAudioCount;

    final newTotal = currentCount + count;
    final wouldExceed = newTotal > 4;

    debugPrint('📊 WOULD EXCEED RESULT:');
    debugPrint('📊   - Current $mediaType count: $currentCount');
    debugPrint('📊   - Trying to add: $count');
    debugPrint('📊   - New total would be: $newTotal');
    debugPrint('📊   - Would exceed limit of 4? $wouldExceed ($newTotal > 4)');
    debugPrint('🔍 ========== WOULD EXCEED CHECK END ==========');

    return wouldExceed;
  }

  /// Increment media counter and save to SharedPreferences
  Future<void> _incrementMediaCounter(String mediaType, int count) async {
    final oldCount = mediaType == 'image'
        ? _todayImageCount
        : mediaType == 'video'
        ? _todayVideoCount
        : _todayAudioCount;

    if (mediaType == 'image') {
      _todayImageCount += count;
      debugPrint(
        '📈 INCREMENT: Image counter: $oldCount → $_todayImageCount (+$count)',
      );
    } else if (mediaType == 'video') {
      _todayVideoCount += count;
      debugPrint(
        '📈 INCREMENT: Video counter: $oldCount → $_todayVideoCount (+$count)',
      );
    } else if (mediaType == 'audio') {
      _todayAudioCount += count;
      debugPrint(
        '📈 INCREMENT: Audio counter: $oldCount → $_todayAudioCount (+$count)',
      );
    }

    await _saveDailyMediaCounts();
    debugPrint('✅ Counter saved to SharedPreferences');
  }

  // ========== END DAILY MEDIA COUNTER METHODS ==========

  ///   Cleanup empty and duplicate call messages from Firestore
  Future<void> _cleanupEmptyCallMessages() async {
    if (_conversationId == null) return;

    try {
      debugPrint('  Starting cleanup of empty and duplicate call messages...');

      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .get();

      int deletedCount = 0;
      final Map<String, List<String>> callIdToMessageIds = {};

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final messageType = _parseMessageType(data['type']);

        // Check if this is a call message
        if (messageType == MessageType.voiceCall ||
            messageType == MessageType.videoCall ||
            messageType == MessageType.missedCall) {
          final text = data['text'] as String?;

          // Delete if text is null, empty, or whitespace only
          if (text == null || text.isEmpty || text.trim().isEmpty) {
            await doc.reference.delete();
            deletedCount++;
            debugPrint('🗑️ Deleted empty call message: ${doc.id}');
            continue;
          }

          // Track duplicate call messages by callId
          final callId = data['callId'] as String?;
          if (callId != null) {
            if (!callIdToMessageIds.containsKey(callId)) {
              callIdToMessageIds[callId] = [];
            }
            callIdToMessageIds[callId]!.add(doc.id);
          }
        }
      }

      // Delete duplicate call messages (keep only the one with proper ID format 'call_<callId>')
      for (final entry in callIdToMessageIds.entries) {
        final callId = entry.key;
        final messageIds = entry.value;

        if (messageIds.length > 1) {
          // Keep the message with ID 'call_<callId>', delete others
          final properMessageId = 'call_$callId';
          for (final msgId in messageIds) {
            if (msgId != properMessageId) {
              await _firestore
                  .collection('conversations')
                  .doc(_conversationId!)
                  .collection('messages')
                  .doc(msgId)
                  .delete();
              deletedCount++;
              debugPrint(
                '🗑️ Deleted duplicate call message: $msgId (keeping $properMessageId)',
              );
            }
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint(
          '  Cleanup complete: Deleted $deletedCount empty/duplicate call messages',
        );
      } else {
        debugPrint(
          '  Cleanup complete: No empty/duplicate call messages found',
        );
      }
    } catch (e) {
      debugPrint('  Error cleaning up call messages: $e');
    }
  }

  String _formatCallDuration(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;

    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
  }

  void _showChatInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatInfoScreen(
          otherUser: widget.otherUser,
          conversationId: _conversationId!,
          onSearchTap: () {
            Navigator.pop(context);
            _toggleSearch();
          },
          onThemeTap: () {
            Navigator.pop(context);
            _showThemePickerDialog();
          },
          onDeleteConversation: () {
            // Close info screen and show dialog on chat screen
            Navigator.of(context).pop();
            // Use post frame callback to ensure info screen is fully popped
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showDeleteConversationDialog();
              }
            });
          },
          onNavigateToMessage: (messageId) {
            // Close info screen first
            Navigator.of(context).pop();
            // Scroll to the message after navigation completes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToMessageById(messageId);
              }
            });
          },
        ),
      ),
    );
  }

  void _scrollToMessageById(String messageId) {
    // Find the message in the list by ID
    final targetMessage = _allMessages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (targetMessage != null) {
      _scrollToMessage(targetMessage);
    }
  }

  // Search-related methods
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults.clear();
        _currentSearchIndex = 0;
      } else {
        // Request focus for search field after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
        });
      }
    });
  }

  Widget _buildSearchField(bool isDarkMode) {
    return GlassTextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      hintText: 'Search messages...',
      showBlur: false,
      decoration: const BoxDecoration(),
      contentPadding: EdgeInsets.zero,
      textAlign: TextAlign.center,
      onChanged: (value) {
        _performSearch(value);
      },
    );
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults.clear();
        _currentSearchIndex = 0;
      } else {
        _searchResults = _allMessages
            .where(
              (message) =>
                  message.text != null &&
                  message.text!.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        _currentSearchIndex = _searchResults.isNotEmpty ? 0 : -1;

        // Scroll to first result if found
        if (_searchResults.isNotEmpty) {
          _scrollToMessage(_searchResults[_currentSearchIndex]);
        }
      }
    });
  }

  Widget _buildSearchResultsBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 0),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          Text(
            _searchResults.isEmpty && _searchQuery.isNotEmpty
                ? 'No results'
                : _searchResults.isEmpty
                ? 'Type to search'
                : '${_currentSearchIndex + 1} of ${_searchResults.length}',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (_searchResults.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: _searchResults.isEmpty ? null : _previousSearchResult,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: _searchResults.isEmpty ? null : _nextSearchResult,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      if (_currentSearchIndex > 0) {
        _currentSearchIndex--;
      } else {
        _currentSearchIndex = _searchResults.length - 1;
      }
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;

    setState(() {
      if (_currentSearchIndex < _searchResults.length - 1) {
        _currentSearchIndex++;
      } else {
        _currentSearchIndex = 0;
      }
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }

  void _scrollToMessage(MessageModel targetMessage) {
    // Find the index of the message in the full list
    final index = _allMessages.indexOf(targetMessage);
    if (index != -1) {
      // Calculate approximate scroll position (reverse list)
      final position =
          (_allMessages.length - index - 1) * 100.0; // Approximate item height

      _scrollController.animateTo(
        position.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Mention-related methods
  // Handle mention (@) detection
  void _handleMentionDetection(String text) {
    final cursorPosition = _messageController.selection.baseOffset;

    // Find the last @ before cursor
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // Check if @ is at start or preceded by space
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atIndex = i;
          break;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        // Stop at space before finding @
        break;
      }
    }

    if (atIndex != -1 && atIndex < cursorPosition) {
      // Extract query after @
      final query = text.substring(atIndex + 1, cursorPosition).toLowerCase();

      // For 1-to-1 chat, only show the other user
      final otherUserName = widget.otherUser.name;
      final otherUserPhoto = widget.otherUser.profileImageUrl;

      if (otherUserName.toLowerCase().contains(query)) {
        setState(() {
          _mentionStartIndex = atIndex;
          _filteredUsers = [
            {
              'id': widget.otherUser.uid,
              'name': otherUserName,
              'photo': otherUserPhoto,
            },
          ];
          _showMentionSuggestions = true;
        });
      } else {
        setState(() {
          _showMentionSuggestions = false;
          _filteredUsers = [];
          _mentionStartIndex = -1;
        });
      }
    } else {
      setState(() {
        _showMentionSuggestions = false;
        _filteredUsers = [];
        _mentionStartIndex = -1;
      });
    }
  }

  // Insert mention when user selects from suggestions
  void _insertMention(String userId, String userName) {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;

    // Replace from @ to cursor with @UserName
    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterMention = text.substring(cursorPosition);
    final mentionText = '@$userName ';

    final newText = beforeMention + mentionText + afterMention;
    final newCursorPosition = beforeMention.length + mentionText.length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    setState(() {
      _showMentionSuggestions = false;
      _filteredUsers = [];
      _mentionStartIndex = -1;
    });

    // Keep focus on text field
    _messageFocusNode.requestFocus();
  }

  // Build text with highlighted mentions
  Widget _buildTextWithMentions(
    String text,
    bool isMe,
    bool isDarkMode,
    bool isDeleted,
  ) {
    final regex = RegExp(r'@(\w+(?:\s+\w+)*)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      // No mentions, return simple text
      return Text(
        text,
        style: TextStyle(
          color: isDeleted
              ? (isDarkMode ? Colors.grey[600] : Colors.grey[500])
              : (isMe
                    ? Colors.white
                    : (isDarkMode ? Colors.white : AppColors.iosGrayDark)),
          fontSize: 16,
          height: 1.35,
          letterSpacing: -0.2,
          fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
        ),
      );
    }

    // Build rich text with highlighted mentions
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before mention
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              color: isDeleted
                  ? (isDarkMode ? Colors.grey[600] : Colors.grey[500])
                  : (isMe
                        ? Colors.white
                        : (isDarkMode ? Colors.white : AppColors.iosGrayDark)),
            ),
          ),
        );
      }

      // Add highlighted mention
      spans.add(
        TextSpan(
          text: match.group(0), // @Username
          style: TextStyle(
            color: isMe
                ? Colors.white
                : (isDarkMode
                      ? const Color(0xFF64B5F6)
                      : const Color(0xFF1976D2)),
            fontWeight: FontWeight.w600,
            backgroundColor: isMe
                ? Colors.white.withValues(alpha: 0.2)
                : (isDarkMode
                      ? const Color(0xFF1976D2).withValues(alpha: 0.2)
                      : const Color(0xFF64B5F6).withValues(alpha: 0.2)),
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            color: isDeleted
                ? (isDarkMode ? Colors.grey[600] : Colors.grey[500])
                : (isMe
                      ? Colors.white
                      : (isDarkMode ? Colors.white : AppColors.iosGrayDark)),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 16,
          height: 1.35,
          letterSpacing: -0.2,
          fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) return Text(text, style: baseStyle);

    final matches = query.toLowerCase();
    final textLower = text.toLowerCase();

    if (!textLower.contains(matches)) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final index = textLower.indexOf(matches, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showThemePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Chat Theme',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // None button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTheme = 'default';
                  });
                  _saveThemeToFirestore('default');
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedTheme == 'default'
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedTheme == 'default'
                          ? Colors.white
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'None (Default)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedTheme == 'default') ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Theme Colors',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: chatThemeColors.entries.map((entry) {
                  final isSelected = _selectedTheme == entry.key;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTheme = entry.key;
                      });
                      _saveThemeToFirestore(entry.key);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: entry.value,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: entry.value.first.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveThemeToFirestore(String theme) async {
    if (_conversationId == null) return;
    try {
      await _firestore.collection('conversations').doc(_conversationId).update({
        'chatTheme': theme,
      });
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<void> _loadThemeFromFirestore() async {
    if (_conversationId == null) return;
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .get();
      if (doc.exists && mounted) {
        final theme = doc.data()?['chatTheme'] as String?;
        if (theme != null && chatThemeColors.containsKey(theme)) {
          setState(() {
            _selectedTheme = theme;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clear Chat?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This will clear all messages from this chat for you. ${widget.otherUser.name} will still see all messages.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
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
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteConversation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Future<void> _deleteConversation() async {
    debugPrint('🗑️ CLEAR CHAT STARTED');
    debugPrint('📝 Conversation ID: $_conversationId');

    if (_conversationId == null) {
      debugPrint('  No conversation ID, returning');
      return;
    }

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      debugPrint('  No current user ID, returning');
      return;
    }

    try {
      debugPrint('📡 Fetching messages from Firestore...');

      // Get all messages in the conversation
      final messagesRef = _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages');

      final messagesSnapshot = await messagesRef.get();
      debugPrint(
        '  Found ${messagesSnapshot.docs.length} messages to mark as deleted',
      );

      if (messagesSnapshot.docs.isEmpty) {
        debugPrint('  No messages to clear');
        return;
      }

      // Mark messages as deleted for current user only (not actually delete them)
      final batch = _firestore.batch();

      for (final doc in messagesSnapshot.docs) {
        // Use set with merge to avoid errors if field doesn't exist
        batch.set(doc.reference, {
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
        }, SetOptions(merge: true));
      }

      // Don't delete the conversation - just mark messages as deleted for this user
      // Other user will still see all messages
      debugPrint('💾 Committing batch update...');
      await batch.commit();
      debugPrint('  BATCH UPDATE SUCCESSFUL!');

      debugPrint('🎉 CLEAR CHAT COMPLETED SUCCESSFULLY');

      // Force UI rebuild to show empty chat immediately
      if (mounted) {
        setState(() {
          debugPrint('  Forcing UI rebuild after clear chat');
        });
      }

      // User stays on chat screen - no navigation
      debugPrint('  User stays on chat screen');
    } catch (e, stackTrace) {
      debugPrint('  CLEAR CHAT ERROR: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
  }
}

/// Full-page Chat Info Screen with feed-like background
class _ChatInfoScreen extends StatefulWidget {
  final UserProfile otherUser;
  final String conversationId;
  final VoidCallback onSearchTap;
  final VoidCallback onThemeTap;
  final VoidCallback onDeleteConversation;
  final void Function(String messageId) onNavigateToMessage;

  const _ChatInfoScreen({
    required this.otherUser,
    required this.conversationId,
    required this.onSearchTap,
    required this.onThemeTap,
    required this.onDeleteConversation,
    required this.onNavigateToMessage,
  });

  @override
  State<_ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<_ChatInfoScreen> {
  bool _isMuted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMuteStatus();
  }

  Future<void> _loadMuteStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _isMuted = doc.data()?['isMuted'] ?? false;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleMute(bool value) async {
    setState(() {
      _isMuted = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'isMuted': value});
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isMuted = !value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image (same as feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay with more opacity
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Chat Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Spacer to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Divider line
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Profile Card with avatar, name, and location
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Column(
                                children: [
                                  // Profile avatar
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(
                                          widget.otherUser.profileImageUrl,
                                        )
                                        ? CachedNetworkImageProvider(
                                            widget.otherUser.profileImageUrl!,
                                          )
                                        : null,
                                    child:
                                        !PhotoUrlHelper.isValidUrl(
                                          widget.otherUser.profileImageUrl,
                                        )
                                        ? Text(
                                            widget.otherUser.name.isNotEmpty
                                                ? widget.otherUser.name[0]
                                                      .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 48,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),

                                  const SizedBox(height: 20),

                                  // Name
                                  Text(
                                    widget.otherUser.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  if (widget.otherUser.location != null &&
                                      widget
                                          .otherUser
                                          .location!
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            widget.otherUser.location!,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 16,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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

                        const SizedBox(height: 30),

                        // Options
                        _buildOptionTile(
                          icon: _isMuted
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_rounded,
                          title: _isMuted
                              ? 'Unmute Notifications'
                              : 'Mute Notifications',
                          trailing: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.iosBlue,
                                  ),
                                )
                              : Switch(
                                  value: _isMuted,
                                  onChanged: _toggleMute,
                                  activeTrackColor: AppColors.iosBlue
                                      .withValues(alpha: 0.5),
                                  activeThumbColor: AppColors.iosBlue,
                                ),
                        ),

                        _buildOptionTile(
                          icon: Icons.search_rounded,
                          title: 'Search in Conversation',
                          onTap: widget.onSearchTap,
                        ),

                        _buildOptionTile(
                          icon: Icons.color_lens_rounded,
                          title: 'Change Theme',
                          onTap: widget.onThemeTap,
                        ),

                        _buildOptionTile(
                          icon: Icons.photo_library_rounded,
                          title: 'Media Gallery',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MediaGalleryScreen(
                                  conversationId: widget.conversationId,
                                  otherUserName: widget.otherUser.name,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Danger options (white text like others)
                        _buildOptionTile(
                          icon: Icons.block_rounded,
                          title: 'Block User',
                          onTap: () => _showBlockUserDialog(),
                        ),

                        _buildOptionTile(
                          icon: Icons.delete_rounded,
                          title: 'Delete Conversation',
                          onTap: widget.onDeleteConversation,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            leading: Icon(
              icon,
              color: iconColor ?? Colors.white.withValues(alpha: 0.8),
            ),
            title: Text(
              title,
              style: TextStyle(color: textColor ?? Colors.white, fontSize: 16),
            ),
            trailing:
                trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      )
                    : null),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Block ${widget.otherUser.name}?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Blocked users cannot send you messages or see your profile. You can unblock them later from settings.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
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
                      onPressed: () {
                        Navigator.pop(context);
                        _blockUser();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Block',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Future<void> _blockUser() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Add to blocked_users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(widget.otherUser.uid)
          .set({
            'blockedUserId': widget.otherUser.uid,
            'blockedUserName': widget.otherUser.name,
            'blockedUserPhoto': widget.otherUser.profileImageUrl,
            'blockedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          '${widget.otherUser.name} has been blocked',
        );
        // Go back to chat screen
        Navigator.pop(context); // Close info screen
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to block user');
      }
    }
  }
}

// WhatsApp-style Forward Message Screen
class _ForwardMessageScreen extends StatefulWidget {
  final String currentUserId;

  const _ForwardMessageScreen({required this.currentUserId});

  @override
  State<_ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<_ForwardMessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Set<UserProfile> _selectedUsers = {};
  String _searchQuery = '';
  List<Map<String, dynamic>> _allContacts = [];
  bool _isLoading = true;

  // Voice search
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _stopVoiceSearch();
          }
        }
      },
      onError: (error) {
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

  void _startVoiceSearch() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Request microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Microphone permission is required for voice search',
        );
      }
      return;
    }

    // Check if speech is available
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {},
        onError: (error) {
          if (mounted && _isListening) {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!_speechEnabled) {
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

          // Update search query and force rebuild
          setState(() {
            _searchQuery = result.recognizedWords;
          });

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _stopVoiceSearch();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
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

  Future<void> _loadContacts() async {
    try {
      // Query without orderBy to avoid composite index requirement
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .limit(50)
          .get();

      // Sort locally by lastMessageTime
      final sortedDocs = conversationsSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime =
              (a.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          final bTime =
              (b.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          return bTime.compareTo(aTime); // Descending order
        });

      final contacts = <Map<String, dynamic>>[];

      for (final doc in sortedDocs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != widget.currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          contacts.add({
            'uid': otherUserId,
            'name': userData['name'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
            'email': userData['email'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    // Filter out current user so they can't forward to themselves
    final contactsWithoutSelf = _allContacts.where((contact) {
      return contact['uid'] != widget.currentUserId;
    }).toList();

    if (_searchQuery.isEmpty) return contactsWithoutSelf;
    return contactsWithoutSelf.where((contact) {
      final name = (contact['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSelection(Map<String, dynamic> contact) {
    setState(() {
      // Get display name - fallback to phone for phone login users
      String displayName = contact['name'] ?? contact['displayName'] ?? '';
      if (displayName.isEmpty || displayName == 'User') {
        displayName = contact['phone'] ?? 'User';
      }
      final userProfile = UserProfile(
        uid: contact['uid'],
        name: displayName,
        email: contact['email'] ?? '',
        profileImageUrl: contact['photoUrl'],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      final existingUser = _selectedUsers
          .where((u) => u.uid == contact['uid'])
          .firstOrNull;
      if (existingUser != null) {
        _selectedUsers.remove(existingUser);
      } else {
        _selectedUsers.add(userProfile);
      }
    });
  }

  bool _isSelected(String uid) {
    return _selectedUsers.any((u) => u.uid == uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Forward to...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_selectedUsers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedUsers.length} selected',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Search bar - Glass style with mic
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlassSearchField(
                    controller: _searchController,
                    hintText: 'Search...',
                    showMic: true,
                    isListening: _isListening,
                    onMicTap: _startVoiceSearch,
                    onStopListening: _stopVoiceSearch,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onClear: () {
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),

                // Selected users chips
                if (_selectedUsers.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _selectedUsers.elementAt(index);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.2,
                            ),
                            side: BorderSide(
                              color: Colors.green.withValues(alpha: 0.5),
                            ),
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  PhotoUrlHelper.isValidUrl(
                                    user.profileImageUrl,
                                  )
                                  ? CachedNetworkImageProvider(
                                      user.profileImageUrl!,
                                    )
                                  : null,
                              child:
                                  !PhotoUrlHelper.isValidUrl(
                                    user.profileImageUrl,
                                  )
                                  ? Text(
                                      user.name[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    )
                                  : null,
                            ),
                            label: Text(
                              user.name.split(' ').first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white70,
                            ),
                            onDeleted: () {
                              setState(() => _selectedUsers.remove(user));
                            },
                          ),
                        );
                      },
                    ),
                  ),

                if (_selectedUsers.isNotEmpty) const SizedBox(height: 8),

                // Contacts list
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _filteredContacts.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No conversations yet'
                                : 'No results found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final isSelected = _isSelected(contact['uid']);

                            return ListTile(
                              onTap: () => _toggleSelection(contact),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(
                                          contact['photoUrl'],
                                        )
                                        ? CachedNetworkImageProvider(
                                            contact['photoUrl'],
                                          )
                                        : null,
                                    child:
                                        !PhotoUrlHelper.isValidUrl(
                                          contact['photoUrl'],
                                        )
                                        ? Text(
                                            (contact['name'] as String)[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                contact['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Bottom send button
          if (_selectedUsers.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context, _selectedUsers.toList());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Forward to ${_selectedUsers.length} ${_selectedUsers.length == 1 ? 'chat' : 'chats'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Plink-style Media Gallery Screen
class _SharedMediaScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;

  const _SharedMediaScreen({
    required this.conversationId,
    required this.otherUserName,
  });

  @override
  State<_SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<_SharedMediaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedFilter = 0; // 0: All, 1: Photos, 2: Links, 3: Files

  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> _linkItems = [];
  List<Map<String, dynamic>> _docItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> media = [];
      final List<Map<String, dynamic>> links = [];
      final List<Map<String, dynamic>> docs = [];

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final mediaUrl =
            data['mediaUrl'] as String? ?? data['imageUrl'] as String?;
        final text = data['text'] as String?;
        final type =
            _EnhancedChatScreenState._parseIntFromDynamic(data['type']) ?? 0;
        final timestamp = data['timestamp'] as Timestamp?;

        // Check for media (images/videos)
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          if (type == MessageType.image.index ||
              mediaUrl.contains('.jpg') ||
              mediaUrl.contains('.jpeg') ||
              mediaUrl.contains('.png') ||
              mediaUrl.contains('.gif') ||
              mediaUrl.contains('.webp')) {
            media.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'type': 'image',
              'id': doc.id,
            });
          } else if (type == MessageType.video.index ||
              mediaUrl.contains('.mp4') ||
              mediaUrl.contains('.mov') ||
              mediaUrl.contains('.avi')) {
            media.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'type': 'video',
              'id': doc.id,
            });
          } else if (type == MessageType.file.index ||
              mediaUrl.contains('.pdf') ||
              mediaUrl.contains('.doc') ||
              mediaUrl.contains('.xls')) {
            docs.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'name': data['fileName'] ?? 'Document',
              'size': data['fileSize'],
              'id': doc.id,
            });
          }
        }

        // Check for links in text
        if (text != null && text.isNotEmpty) {
          final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
          final matches = urlRegex.allMatches(text);
          for (final match in matches) {
            links.add({
              'url': match.group(0),
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'text': text,
              'id': doc.id,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _mediaItems = media;
          _linkItems = links;
          _docItems = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Media Gallery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Empty space to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Divider line below AppBar
                Container(
                  height: 1,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Segmented Control
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildSegment('All', 0),
                      _buildSegment('Photos', 1),
                      _buildSegment('Links', 2),
                      _buildSegment('Files', 3),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedFilter) {
      case 1:
        return _buildMediaGrid();
      case 2:
        return _buildLinksList();
      case 3:
        return _buildDocsList();
      default:
        return _buildAllContent();
    }
  }

  Widget _buildAllContent() {
    if (_mediaItems.isEmpty && _linkItems.isEmpty && _docItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No Shared Content',
        subtitle: 'Media, links and files shared in this chat will appear here',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Photos section
        if (_mediaItems.isNotEmpty) ...[
          _buildSectionHeader(
            'Photos',
            _mediaItems.length,
            Icons.image_outlined,
          ),
          const SizedBox(height: 12),
          _buildMediaGridCompact(),
          const SizedBox(height: 24),
        ],

        // Links section
        if (_linkItems.isNotEmpty) ...[
          _buildSectionHeader('Links', _linkItems.length, Icons.link_rounded),
          const SizedBox(height: 12),
          ..._linkItems.take(3).map((item) => _buildLinkItem(item)),
          if (_linkItems.length > 3)
            _buildShowMoreButton(() => setState(() => _selectedFilter = 2)),
          const SizedBox(height: 24),
        ],

        // Files section
        if (_docItems.isNotEmpty) ...[
          _buildSectionHeader(
            'Files',
            _docItems.length,
            Icons.insert_drive_file_outlined,
          ),
          const SizedBox(height: 12),
          ..._docItems.take(3).map((item) => _buildDocItem(item)),
          if (_docItems.length > 3)
            _buildShowMoreButton(() => setState(() => _selectedFilter = 3)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show more',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGridCompact() {
    final displayItems = _mediaItems.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        return _buildMediaTile(displayItems[index], index);
      },
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.image_outlined,
        title: 'No Photos',
        subtitle: 'Photos shared in this chat will appear here',
      );
    }

    // Group media by date
    final groupedMedia = <String, List<Map<String, dynamic>>>{};
    for (final item in _mediaItems) {
      final date = item['timestamp'] as DateTime;
      final key = _getDateKey(date);
      groupedMedia.putIfAbsent(key, () => []).add(item);
    }

    // Sort keys to maintain order (most recent first)
    final sortedKeys = groupedMedia.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final items = groupedMedia[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header like WhatsApp
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (context, gridIndex) {
                final item = items[gridIndex];
                return _buildMediaTile(item, _mediaItems.indexOf(item));
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildMediaTile(Map<String, dynamic> item, int index) {
    final isVideo = item['type'] == 'video';

    return GestureDetector(
      onTap: () => _openMediaViewer(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item['url'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                  ),
                ),
              ),
              if (isVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem(Map<String, dynamic> item) {
    final url = item['url'] as String;
    final timestamp = item['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.link_rounded,
            color: Color(0xFF2563EB),
            size: 20,
          ),
        ),
        title: Text(
          url,
          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(timestamp),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        onTap: () => _openLink(url),
      ),
    );
  }

  Widget _buildDocItem(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final timestamp = item['timestamp'] as DateTime;
    final size = _EnhancedChatScreenState._parseIntFromDynamic(item['size']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.iosOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.iosOrange,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${size != null ? '${_formatFileSize(size)} • ' : ''}${_formatDate(timestamp)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        onTap: () => _downloadDoc(item),
      ),
    );
  }

  Widget _buildLinksList() {
    if (_linkItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_off_rounded,
        title: 'No Links',
        subtitle: 'Links shared in this chat will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _linkItems.length,
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        final url = item['url'] as String;
        final timestamp = item['timestamp'] as DateTime;
        final messageId = item['id'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: Text(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (messageId != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _navigateToMessage(messageId),
                        tooltip: 'Go to message',
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _openLink(url),
                      tooltip: 'Open link',
                    ),
                  ],
                ),
                onTap: () => _openLink(url),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocsList() {
    if (_docItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off_rounded,
        title: 'No Documents',
        subtitle: 'Documents shared in this chat will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _docItems.length,
      itemBuilder: (context, index) {
        final item = _docItems[index];
        final name = item['name'] as String;
        final timestamp = item['timestamp'] as DateTime;
        final size = _EnhancedChatScreenState._parseIntFromDynamic(
          item['size'],
        );
        final messageId = item['id'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.iosOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppColors.iosOrange,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${size != null ? '${_formatFileSize(size)} • ' : ''}${_formatDate(timestamp)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (messageId != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _navigateToMessage(messageId),
                        tooltip: 'Go to message',
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.download_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _downloadDoc(item),
                      tooltip: 'Download',
                    ),
                  ],
                ),
                onTap: () => _downloadDoc(item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _openMediaViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMediaViewer(
          mediaItems: _mediaItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openLink(String url) async {
    // Ensure URL has proper scheme
    String urlToLaunch = url.trim();
    if (!urlToLaunch.startsWith('http://') &&
        !urlToLaunch.startsWith('https://')) {
      urlToLaunch = 'https://$urlToLaunch';
    }

    final uri = Uri.parse(urlToLaunch);
    try {
      // Try to launch URL directly without checking canLaunchUrl first
      // canLaunchUrl often returns false even when URL can be opened
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Try with inAppWebView as fallback
        final launchedInApp = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );

        if (!launchedInApp) {
          // Final fallback: copy to clipboard
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            SnackBarHelper.showWarning(
              context,
              'Could not open link. Copied to clipboard.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error opening link: $e');
      // Error fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to open link. Copied to clipboard.',
        );
      }
    }
  }

  void _downloadDoc(Map<String, dynamic> item) async {
    final url = item['url'] as String;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document link copied to clipboard'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _navigateToMessage(String messageId) {
    // Pop back to chat screen with the messageId to scroll to
    Navigator.pop(context, messageId);
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];

    if (dateOnly == today) {
      return 'Today, $dayName';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, $dayName';
    } else if (date.year == now.year) {
      // Same year - show day name, date and month
      return '$dayName, ${date.day} $monthName';
    } else {
      // Different year - show full date with year
      return '$dayName, ${date.day} $monthName ${date.year}';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Full-screen media viewer with swipe navigation
class _FullScreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;

  const _FullScreenMediaViewer({
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<_FullScreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => _saveCurrentImage(),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () => _shareCurrentImage(),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          final isVideo = item['type'] == 'video';

          if (isVideo) {
            return _VideoPlayerWidget(
              videoUrl: item['url'] as String,
              isCurrentPage: index == _currentIndex,
            );
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: item['url'],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Text(
            _formatTimestamp(widget.mediaItems[_currentIndex]['timestamp']),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  Future<void> _saveCurrentImage() async {
    try {
      final url = widget.mediaItems[_currentIndex]['url'] as String;

      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission required'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }
      }

      // Download image
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get the Pictures directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Pictures/Plink');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save the file
      final fileName = 'plink_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved to gallery'),
            backgroundColor: AppColors.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save image'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _shareCurrentImage() async {
    final url = widget.mediaItems[_currentIndex]['url'] as String;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image link copied to clipboard'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

// Video Player Widget for Media Gallery
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isCurrentPage;

  const _VideoPlayerWidget({
    required this.videoUrl,
    required this.isCurrentPage,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(_VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause when not current page
    if (!widget.isCurrentPage && _videoController?.value.isPlaying == true) {
      _videoController?.pause();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint(
        '📹 _VideoPlayerWidget: Initializing with URL: ${widget.videoUrl}',
      );

      // Validate URL
      if (widget.videoUrl.isEmpty) {
        throw Exception('Video URL is empty');
      }

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // Add error listener
      _videoController!.addListener(() {
        if (_videoController!.value.hasError) {
          debugPrint(
            '📹 _VideoPlayerWidget: Video error - ${_videoController!.value.errorDescription}',
          );
        }
      });

      await _videoController!.initialize();
      debugPrint(
        '📹 _VideoPlayerWidget: Video initialized - duration: ${_videoController!.value.duration}',
      );

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF2563EB),
            handleColor: const Color(0xFF2563EB),
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            ),
          ),
          errorBuilder: (context, errorMessage) {
            debugPrint('📹 _VideoPlayerWidget: Chewie error - $errorMessage');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error playing video',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('📹 _VideoPlayerWidget: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_errorMessage != null || _chewieController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _errorMessage = null;
                });
                _initializeVideo();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

// Voice Recording Preview Popup with audio playback
class _VoicePreviewPopup extends StatefulWidget {
  final String audioPath;
  final int duration;
  final FlutterSoundPlayer audioPlayer;
  final bool isPlayerInitialized;
  final Future<void> Function() onInitializePlayer;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _VoicePreviewPopup({
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
    required this.isPlayerInitialized,
    required this.onInitializePlayer,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<_VoicePreviewPopup> createState() => _VoicePreviewPopupState();
}

class _VoicePreviewPopupState extends State<_VoicePreviewPopup> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  StreamSubscription? _playerSubscription;

  @override
  void dispose() {
    _stopPreview();
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      } else {
        // Initialize player if needed
        await widget.onInitializePlayer();

        // Set fast subscription for smooth waveform animation
        await widget.audioPlayer.setSubscriptionDuration(
          const Duration(milliseconds: 50),
        );

        // Subscribe to progress BEFORE starting
        _playerSubscription?.cancel();
        _playerSubscription = widget.audioPlayer.onProgress!.listen((e) {
          if (mounted && e.duration.inMilliseconds > 0) {
            setState(() {
              _playbackProgress =
                  e.position.inMilliseconds / e.duration.inMilliseconds;
            });
          }
        });

        setState(() {
          _isPlaying = true;
          _playbackProgress = 0.0;
        });

        await widget.audioPlayer.startPlayer(
          fromURI: widget.audioPath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error playing preview: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPreview() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
      }
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
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
              // Audio Player UI - WhatsApp style
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF007AFF), width: 2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause button
                      GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF5856D6,
                                ).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Waveform / Progress bar
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Waveform visualization with animation
                            SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(20, (index) {
                                  final isActive =
                                      index / 20 <= _playbackProgress;
                                  final heights = [
                                    8.0,
                                    14.0,
                                    10.0,
                                    18.0,
                                    12.0,
                                    20.0,
                                    14.0,
                                    16.0,
                                    10.0,
                                    22.0,
                                    18.0,
                                    12.0,
                                    20.0,
                                    8.0,
                                    16.0,
                                    14.0,
                                    18.0,
                                    10.0,
                                    14.0,
                                    12.0,
                                  ];
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 3,
                                    height: heights[index],
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF5856D6)
                                          : Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Duration text
                            Text(
                              _formatTime(widget.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mic icon
                      const Icon(Icons.mic, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onCancel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Send button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onSend();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF5856D6,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Send',
                            style: TextStyle(
                              color: Colors.white,
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
}

/// Full screen video player screen
class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerScreen({required this.videoUrl});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint(
        '📹 VideoPlayerScreen: Initializing with URL: ${widget.videoUrl}',
      );

      // Validate URL
      if (widget.videoUrl.isEmpty) {
        throw Exception('Video URL is empty');
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController = controller;

      // Add listener for errors
      controller.addListener(() {
        if (controller.value.hasError) {
          debugPrint(
            '📹 VideoPlayerScreen: Video error - ${controller.value.errorDescription}',
          );
          if (mounted && _error == null) {
            setState(() {
              _error =
                  controller.value.errorDescription ?? 'Video playback error';
            });
          }
        }
      });

      await controller.initialize();
      debugPrint(
        '📹 VideoPlayerScreen: Video initialized - duration: ${controller.value.duration}',
      );

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF007AFF),
          handleColor: const Color(0xFF007AFF),
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          debugPrint('📹 VideoPlayerScreen: Chewie error - $errorMessage');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error playing video',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('📹 VideoPlayerScreen: Exception - $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _videoPlayerController?.dispose();
    } catch (_) {}
    try {
      _chewieController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Video', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              )
            : _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Colors.grey[400])),
                ],
              )
            : _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// WhatsApp-style media preview screen for multiple images/videos
class _MediaPreviewScreen extends StatefulWidget {
  final List<File> mediaFiles;
  final bool isVideo;
  final Function(List<File>) onSend;

  const _MediaPreviewScreen({
    required this.mediaFiles,
    required this.isVideo,
    required this.onSend,
  });

  @override
  State<_MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<_MediaPreviewScreen> {
  late List<File> _selectedFiles;
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedFiles = List.from(widget.mediaFiles);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _removeFile(int index) {
    if (_selectedFiles.length <= 1) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _selectedFiles.removeAt(index);
      if (_currentIndex >= _selectedFiles.length) {
        _currentIndex = _selectedFiles.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${_selectedFiles.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          // Delete current media button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _removeFile(_currentIndex),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main preview area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _selectedFiles.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                if (widget.isVideo) {
                  return _buildVideoPreview(file);
                } else {
                  return _buildImagePreview(file);
                }
              },
            ),
          ),

          // Thumbnail strip at bottom
          if (_selectedFiles.length > 1)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: widget.isVideo
                            ? Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.videocam,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              )
                            : Image.file(
                                _selectedFiles[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Send button
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Media count indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedFiles.length} ${widget.isVideo ? 'video' : 'image'}${_selectedFiles.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Send button
                  GestureDetector(
                    onTap: () {
                      widget.onSend(_selectedFiles);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Send ${_selectedFiles.length > 1 ? '(${_selectedFiles.length})' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(File file) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPreview(File file) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white70,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            file.path.split('/').last,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: file.length(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final sizeMB = snapshot.data! / (1024 * 1024);
                return Text(
                  '${sizeMB.toStringAsFixed(1)} MB',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
