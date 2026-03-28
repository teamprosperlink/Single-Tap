import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shimmer/shimmer.dart';
import 'api_create_post_screen.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/see_all_products_screen.dart';
import '../../services/product_api_service.dart';
import '../../services/ip_location_service.dart';
import '../../services/notification_service.dart';
import '../../res/utils/snackbar_helper.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/common widgets/app_drawer.dart';
import '../../services/unified_post_service.dart';
import '../../services/location_services/gemini_service.dart';
import '../business/simple/public_business_profile_screen.dart';

@immutable
class HomeScreen extends StatefulWidget {
  /// Global key to access HomeScreenState from outside
  static final GlobalKey<HomeScreenState> globalKey =
      GlobalKey<HomeScreenState>();

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();

  bool _isSearchFocused = false;
  bool _isProcessing = false;

  final List<String> _suggestions = [];
  String _currentUserName = '';
  String? _currentUserPhotoUrl;
  double? _currentUserLat;
  double? _currentUserLng;

  late AnimationController _controller;
  Timer? _timer;

  final List<Map<String, dynamic>> _conversation = [];

  // Current chat ID for auto-save (Single Tap style)
  String? _currentChatId;

  // Current project context (for Library/Projects feature)
  String? _currentProjectId;

  // Voice recording state
  bool _isRecording = false;
  bool _isVoiceProcessing = false;
  Timer? _recordingTimer;

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;

  // Text to speech (listen to messages)
  final FlutterTts _tts = FlutterTts();
  String? _currentlyPlayingKey;
  bool _isTtsSpeaking = false;

  // Single Tap-style action states
  final Set<String> _likedMessages = {};
  final Set<String> _dislikedMessages = {};
  String _currentSpeechText = '';

  // Saved posts tracking
  final Set<String> _savedPostIds = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Navigate to create post screen
  void _navigateToCreatePost([String? initialDescription]) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => ApiCreatePostScreen(
        initialDescription: initialDescription,
        isPopup: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initSpeech();
    _initTts();
    _loadSavedPosts();
    // Clear old cache for fresh results (warmUp already called in main.dart)
    ProductApiService().resetCache();

    _controller = AnimationController(vsync: this);

    _searchFocusNode.addListener(_onFocusChange);

    _conversation.add({
      'text':
          'Hi! I\'m your Single Tap assistant. What would you like to find today?',
      'isUser': false,
      'timestamp': DateTime.now(),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  void _initTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isTtsSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _currentlyPlayingKey = null;
        });
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _currentlyPlayingKey = null;
        });
      }
    });
  }

  Future<void> _toggleTts(String key, String text) async {
    if (_currentlyPlayingKey == key && _isTtsSpeaking) {
      await _tts.stop();
      setState(() {
        _isTtsSpeaking = false;
        _currentlyPlayingKey = null;
      });
    } else {
      if (_isTtsSpeaking) await _tts.stop();
      setState(() => _currentlyPlayingKey = key);
      await _tts.speak(text);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _intentController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    _timer?.cancel();
    _recordingTimer?.cancel();
    _chatScrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  /// Reset for new chat (Single Tap style - conversation is auto-saved)
  Future<void> saveConversationAndReset() async {
    debugPrint('Starting new chat (previous auto-saved)');
    _resetConversation();
  }

  /// Start a new chat linked to a project
  void startNewChatInProject(String projectId) {
    _resetConversation();
    _currentProjectId = projectId;
    debugPrint('New chat started in project: $projectId');
  }

  /// Load a conversation from chat history
  Future<void> loadConversation(String chatId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(chatId)
          .get();

      if (!doc.exists) {
        debugPrint('Chat not found: $chatId');
        return;
      }

      final data = doc.data()!;
      final messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);

      setState(() {
        _conversation.clear();
        _intentController.clear();
        _currentChatId = chatId;
        _currentProjectId = null; // Clear project context when loading a chat

        // Restore messages
        for (var msg in messages) {
          final text =
              (msg['text'] as String?)?.replaceAll('Supper', 'Single Tap') ?? '';
          _conversation.add({
            'text': text,
            'isUser': msg['isUser'],
            'timestamp': msg['timestamp'] is Timestamp
                ? (msg['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            'type': msg['type'],
            'data': msg['data'],
          });
        }
      });

      debugPrint(
        'Loaded conversation: $chatId with ${messages.length} messages',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Error loading conversation: $e');
    }
  }

  /// Reset conversation to initial state
  void _resetConversation() {
    setState(() {
      _conversation.clear();
      _intentController.clear();
      _currentChatId = null; // Reset chat ID for new conversation
      _currentProjectId = null; // Reset project context

      // Add welcome message
      _conversation.add({
        'text':
            'Hi! I\'m your Single Tap assistant. What would you like to find today?',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// Check if there's an active conversation worth saving
  bool get hasActiveConversation {
    return _conversation.any((msg) => msg['isUser'] == true);
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data();
          final city = (data?['city'] as String? ?? '').toLowerCase();
          final lat = (data?['latitude'] as num?)?.toDouble();
          final lng = (data?['longitude'] as num?)?.toDouble();
          final isMVCoords = (lat != null && lng != null &&
              (lat - 37.422).abs() < 0.05 && (lng + 122.084).abs() < 0.05);
          final isStale = city.contains('mountain view') || isMVCoords ||
              (lat != null && lng != null && lat.abs() < 0.01 && lng.abs() < 0.01);
          setState(() {
            _currentUserName = data?['name'] ?? 'User';
            _currentUserPhotoUrl = data?['photoUrl'] as String?;
            _currentUserLat = isStale ? null : lat;
            _currentUserLng = isStale ? null : lng;
          });
        }
      } catch (e) {
        debugPrint('Error loading user profile from Firestore: $e');
        // Continue to GPS/IP fallback below
      }
    }

    // Fallback: get device location if Firestore doesn't have it
    if (_currentUserLat == null || _currentUserLng == null) {
      // Try GPS first
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
          if (mounted) {
            setState(() {
              _currentUserLat = pos.latitude;
              _currentUserLng = pos.longitude;
            });
          }
        }
      } catch (_) {}

      // If GPS also failed, try IP location
      if (_currentUserLat == null || _currentUserLng == null) {
        try {
          final ipResult = await IpLocationService.detectLocation();
          if (ipResult != null && mounted) {
            setState(() {
              _currentUserLat = (ipResult['lat'] as num?)?.toDouble();
              _currentUserLng = (ipResult['lng'] as num?)?.toDouble();
            });
            debugPrint('HomeScreen: using IP location: $_currentUserLat, $_currentUserLng');
          }
        } catch (_) {}
      }
    }
  }

  /// Haversine formula — returns distance in km between two lat/lng points.
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  void _processIntent() async {
    if (_isProcessing) return; // Prevent concurrent operations

    final userMessage = _intentController.text.trim();
    if (_intentController.text.isEmpty) return;
    if (userMessage.isEmpty) return;

    setState(() {
      _conversation.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isProcessing = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _intentController.clear();

    try {
      if (_shouldProcessForMatches(userMessage)) {
        // Call backend API — adds AI message + product cards to conversation
        await _processWithIntent(userMessage);
      } else {
        // Conversational messages (hi, thanks, etc.) — simple local response
        final aiResponse = _generateConversationalResponse(userMessage);
        if (mounted) {
          setState(() {
            _conversation.add({
              'text': aiResponse,
              'isUser': false,
              'timestamp': DateTime.now(),
            });
          });
        }
      }
    } finally {
      _isProcessing = false;
      if (mounted) {
        setState(() {});
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Auto-save conversation to chat history (fire-and-forget — don't block UI)
    _autoSaveConversation(userMessage);
  }

  /// Auto-save conversation after each message (Single Tap style)
  Future<void> _autoSaveConversation(String userMessage) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final messagesToSave = _conversation
          // Skip skeleton/searching placeholders — they're transient UI states
          .where((msg) => msg['type'] != 'skeleton_results' && msg['type'] != 'searching_text')
          .map((msg) {
        // Convert DateTime to Timestamp for Firestore
        final timestamp = msg['timestamp'];
        final firestoreTimestamp = timestamp is DateTime
            ? Timestamp.fromDate(timestamp)
            : timestamp;

        // Sanitize `data` for Firestore: keep only lightweight fields for
        // match_results / no_results_create_post so the document stays small
        // and avoids serialisation failures on deeply-nested API card data.
        dynamic sanitizedData;
        final rawData = msg['data'];
        if (rawData is List) {
          sanitizedData = (rawData).map<Map<String, dynamic>>((card) {
            if (card is Map<String, dynamic>) {
              return <String, dynamic>{
                'name': card['name'],
                'image': card['image'],
                'price': card['price'],
                'listing_id': card['listing_id'],
                'user_id': card['user_id'],
                'match_score': card['match_score'],
                'match_type': card['match_type'],
                'location': card['location'],
              };
            }
            return <String, dynamic>{};
          }).toList();
        } else if (rawData is Map) {
          sanitizedData = Map<String, dynamic>.from(rawData);
        } else {
          sanitizedData = rawData;
        }

        return <String, dynamic>{
          'text': msg['text'],
          'isUser': msg['isUser'],
          'timestamp': firestoreTimestamp,
          'type': msg['type'],
          'data': sanitizedData,
          if (msg['query'] != null) 'query': msg['query'],
        };
      }).toList();

      // Get title from first user message
      final userMessages = _conversation
          .where((msg) => msg['isUser'] == true)
          .toList();
      final firstUserMessage = userMessages.isNotEmpty
          ? userMessages.first['text'] as String? ?? 'Chat'
          : userMessage;
      final title = firstUserMessage.length > 50
          ? '${firstUserMessage.substring(0, 50)}...'
          : firstUserMessage;

      if (_currentChatId == null) {
        // Create new chat history document
        // Use Timestamp.now() instead of FieldValue.serverTimestamp() so the
        // createdAt value is immediately available in the local Firestore cache
        // for drawer sorting (server timestamp is null until the server confirms).
        final now = Timestamp.now();
        final chatData = <String, dynamic>{
          'userId': userId,
          'title': title,
          'messages': messagesToSave,
          'createdAt': now,
          'updatedAt': now,
        };
        if (_currentProjectId != null) {
          chatData['projectId'] = _currentProjectId;
        }
        final docRef = await FirebaseFirestore.instance
            .collection('chat_history')
            .add(chatData);
        _currentChatId = docRef.id;
        debugPrint('ChatHistory: new chat created $_currentChatId (title="$title")');

        // If linked to a project, add chatId to the project's chatIds
        if (_currentProjectId != null) {
          try {
            await FirebaseFirestore.instance
                .collection('projects')
                .doc(_currentProjectId)
                .update({
                  'chatIds': FieldValue.arrayUnion([_currentChatId]),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
            debugPrint('Chat added to project: $_currentProjectId');
            // Clear project context after linking so future new chats
            // don't get auto-tagged to this project
            _currentProjectId = null;
          } catch (e) {
            debugPrint('Error adding chat to project: $e');
          }
        }
      } else {
        // Update existing chat history document
        await FirebaseFirestore.instance
            .collection('chat_history')
            .doc(_currentChatId)
            .update({
              'title': title,
              'messages': messagesToSave,
              'updatedAt': Timestamp.now(),
            });
        debugPrint('ChatHistory: updated $_currentChatId (${messagesToSave.length} msgs)');
      }

      // Refresh drawer's chat history list so new entry appears immediately
      AppDrawer.globalKey.currentState?.refreshChatHistory();
    } catch (e, stack) {
      debugPrint('Error auto-saving conversation: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// Generate a simple conversational response for non-search messages
  String _generateConversationalResponse(String userMessage) {
    final trimmed = userMessage.trim().toLowerCase();
    final userName = _currentUserName.split(' ')[0];

    if (RegExp(r'^(hi|hello|hey|hii+|helo|namaste|namaskar)\b').hasMatch(trimmed)) {
      return 'Hey $userName! How can I help you today?';
    }
    if (RegExp(r'^(thanks|thank you|thanku|shukriya|dhanyavad)').hasMatch(trimmed)) {
      return 'You\'re welcome, $userName! Let me know if you need anything else.';
    }
    if (RegExp(r'^(bye|goodbye|alvida|see you)').hasMatch(trimmed)) {
      return 'See you later, $userName! Have a great day!';
    }
    if (RegExp(r'^(ok|okay|accha|theek|thik)').hasMatch(trimmed)) {
      return 'Let me know if you want to search for something!';
    }
    if (RegExp(r'^(yes|no|haan|nahi|nah)$').hasMatch(trimmed)) {
      return 'Got it! Tell me what you\'re looking for and I\'ll find the best matches.';
    }
    if (RegExp(r'(help|madad|sahayata)').hasMatch(trimmed)) {
      return 'I can help you find products, services, jobs, friends and more. Just tell me what you need!';
    }
    return 'I\'m here to help! Tell me what you\'re looking for.';
  }





  // ── Saved Posts ──
  Future<void> _loadSavedPosts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .limit(200)
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
      debugPrint('Error loading saved posts: $e');
    }
  }

  Future<void> _toggleSaveProduct(String productId, Map<String, dynamic> productData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    try {
      final savedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(productId);
      if (_savedPostIds.contains(productId)) {
        await savedRef.delete();
        if (mounted) {
          setState(() => _savedPostIds.remove(productId));
          SnackBarHelper.showSuccess(context, 'Post unsaved');
        }
      } else {
        await savedRef.set({
          'postId': productId,
          'postData': {
            ...productData,
            'source': 'api_listing',
            'imageUrl': productData['image'] ?? '',
            'title': productData['name'] ?? '',
          },
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _savedPostIds.add(productId));
          SnackBarHelper.showSuccess(context, 'Post saved');
        }
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Failed to save post');
    }
  }

  // ── Inline Create Post (images in search field) ──

  bool _shouldProcessForMatches(String message) {
    final trimmed = message.trim().toLowerCase();
    if (trimmed.length < 3) return false;
    const conversational = [
      'hi', 'hello', 'hey', 'thanks', 'thank you',
      'ok', 'okay', 'yes', 'no', 'bye', 'goodbye',
    ];
    if (conversational.contains(trimmed)) return false;
    return true;
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Voice: status=$status, text="$_currentSpeechText"');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording) {
              _finishRecording();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted && _isRecording) {
            // Fall back to mock data on error
            _useMockVoiceResult();
          }
        },
      );
      debugPrint('Voice: initialized, speechEnabled=$_speechEnabled');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Voice: init error=$e');
    }
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _currentSpeechText = '';
    });

    if (_speechEnabled) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted && result.recognizedWords.isNotEmpty) {
              setState(() {
                _currentSpeechText = result.recognizedWords;
              });
              // Auto-finish when speech is final
              if (result.finalResult && _currentSpeechText.isNotEmpty) {
                _finishRecording();
              }
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      } catch (e) {
        debugPrint('Error starting speech: $e');
        // Fall back to mock after delay
        _recordingTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _isRecording) {
            _useMockVoiceResult();
          }
        });
      }
    } else {
      // Speech not available
      debugPrint('Voice: speech not enabled, falling back');
      setState(() {
        _isRecording = false;
        _isVoiceProcessing = false;
        _conversation.add({
          'text': 'Voice input is not available. Please type your query.',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _stopVoiceRecording() async {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();

    if (_speechEnabled) {
      await _speech.stop();
    }

    _finishRecording();
  }

  void _useMockVoiceResult() {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    debugPrint('Voice: speechEnabled=$_speechEnabled, currentText="$_currentSpeechText"');

    // If there's partial text captured, use it instead of showing error
    if (_currentSpeechText.trim().isNotEmpty) {
      final spokenText = _currentSpeechText.trim();
      setState(() {
        _isRecording = false;
        _isVoiceProcessing = false;
        _conversation.add({
          'text': spokenText,
          'isUser': true,
          'timestamp': DateTime.now(),
        });
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      _processVoiceMessage(spokenText);
      return;
    }

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = false;
      _conversation.add({
        'text': 'Sorry, I couldn\'t hear you. Please try again.',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _finishRecording() {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final spokenText = _currentSpeechText.trim();

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = spokenText.isNotEmpty;
    });

    // If no speech detected, use mock data
    if (spokenText.isEmpty) {
      _useMockVoiceResult();
      return;
    }

    // Add voice result to chat
    setState(() {
      _isVoiceProcessing = false;
      _conversation.add({
        'text': spokenText,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Process for AI response
    _processVoiceMessage(spokenText);
  }

  void _processVoiceMessage(String message) async {
    if (_isProcessing) return; // Prevent concurrent operations
    setState(() {
      _isProcessing = true;
    });

    if (_shouldProcessForMatches(message)) {
      // Call backend API — adds AI message + product cards to conversation
      await _processWithIntent(message);
    } else {
      // Conversational messages — simple local response
      final aiResponse = _generateConversationalResponse(message);
      if (mounted) {
        setState(() {
          _conversation.add({
            'text': aiResponse,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
        });
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Auto-save voice conversation to chat history
    _autoSaveConversation(message);
  }

  /// Process intent and find matches. Shows shimmer skeleton cards instantly
  /// (like Flipkart/Amazon) while fetching real data from backend.
  Future<void> _processWithIntent(String intent) async {
    // Show "Searching..." text bubble + shimmer skeleton cards immediately
    setState(() {
      _conversation.add({
        'text': 'Searching for "$intent"...',
        'isUser': false,
        'timestamp': DateTime.now(),
        'type': 'searching_text',
      });
      _conversation.add({
        'text': '',
        'isUser': false,
        'timestamp': DateTime.now(),
        'type': 'skeleton_results',
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      // Ensure location is loaded before searching — retry if still null
      if (_currentUserLat == null || _currentUserLng == null) {
        await _loadUserProfile();
      }

      // Run backend API search and Firestore business search in parallel
      final sw = Stopwatch()..start();

      // Business search: generate embedding then query Firestore business posts
      final businessFuture = () async {
        try {
          final emb = await GeminiService().generateEmbedding(intent);
          if (emb.every((v) => v == 0.0)) return <Map<String, dynamic>>[];
          return await UnifiedPostService().searchBusinessPosts(
            query: intent,
            queryEmbedding: emb,
            userLat: _currentUserLat,
            userLng: _currentUserLng,
          );
        } catch (e) {
          debugPrint('Business search error: $e');
          return <Map<String, dynamic>>[];
        }
      }();

      // Backend API search (existing)
      final apiFuture = ProductApiService()
          .searchWithResponse(intent, bidirectionalMatching: true, lat: _currentUserLat, lng: _currentUserLng)
          .timeout(const Duration(minutes: 5), onTimeout: () {
        debugPrint('ProductAPI: overall timeout for "$intent"');
        return <String, dynamic>{
          'products': <Map<String, dynamic>>[],
          'message': 'Search is taking too long. The server may be warming up — please try again in a moment.',
          '_error': true,
        };
      });

      // Await both in parallel
      final bothResults = await Future.wait<dynamic>([apiFuture, businessFuture]);
      final productResult = bothResults[0] as Map<String, dynamic>;
      final businessCards = bothResults[1] as List<Map<String, dynamic>>;

      final apiMessage = productResult['message'] as String? ?? '';
      final isApiError = productResult['_error'] == true;
      final productCards =
          productResult['products'] as List<Map<String, dynamic>>? ?? [];

      debugPrint(
          'ProductAPI: returned ${productCards.length} cards in ${sw.elapsedMilliseconds}ms');
      debugPrint('ProductAPI: apiMessage="$apiMessage"');
      for (int i = 0; i < productCards.length; i++) {
        final c = productCards[i];
        debugPrint('ProductAPI: RAW card[$i] name="${c['name']}" sim=${c['similarity_score']} match_type="${c['match_type']}" listing_id="${c['listing_id']}" user_id="${c['user_id']}"');
      }

      if (!mounted) return;

      final List<Map<String, dynamic>> apiCards = [];

      for (final card in productCards) {
        final loc = card['_raw_location'];
        final originalLocationName = card['location'] as String? ?? '';
        String displayLocation = originalLocationName;
        debugPrint('ProductAPI: card="${card['name']}" rawLoc type=${loc.runtimeType} userLat=$_currentUserLat userLng=$_currentUserLng image="${card['image']}" images=${(card['images'] as List?)?.length ?? 0}');
        if (loc is Map &&
            _currentUserLat != null &&
            _currentUserLng != null) {
          // Try coordinates directly or nested
          Map<String, dynamic>? coords;
          if (loc['coordinates'] is Map) {
            coords = Map<String, dynamic>.from(loc['coordinates'] as Map);
          } else if (loc['lat'] != null && loc['lng'] != null) {
            coords = {'lat': loc['lat'], 'lng': loc['lng']};
          }
          if (coords != null) {
            final lat = (coords['lat'] as num?)?.toDouble();
            final lng = (coords['lng'] as num?)?.toDouble();
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              final distKm = _haversineDistance(
                  _currentUserLat!, _currentUserLng!, lat, lng);
              // Home screen cards show distance only
              displayLocation = distKm < 1
                  ? '${(distKm * 1000).round()} m away'
                  : '${distKm.toStringAsFixed(1)} km away';
              debugPrint('ProductAPI: distance=${distKm.toStringAsFixed(1)}km for "${card['name']}"');
            }
          }
        }
        // Preserve original location name for detail screen
        card['_location_name'] = originalLocationName;
        card['location'] = displayLocation;

        // Use original similarity_score, or calculate locally if API returned very low
        double simScore = (card['similarity_score'] as num?)?.toDouble() ?? 0.0;
        if (simScore < 0.05) {
          simScore = _calculateLocalSimilarity(intent, card);
          card['similarity_score'] = simScore;
        }
        final scorePercent = (simScore * 100).toStringAsFixed(0);
        card['match_score'] = '$scorePercent%';

        // Keep API's match_type as source of truth; fallback to 'similar'
        final apiMatchType = card['match_type']?.toString() ?? '';
        if (apiMatchType.isEmpty) {
          card['match_type'] = 'similar';
        }

        apiCards.add(card);
      }

      // Use distance_km from nearby/feed as location fallback
      for (final card in apiCards) {
        if ((card['location'] as String? ?? '').isEmpty && card['distance_km'] != null) {
          final distKm = (card['distance_km'] as num).toDouble();
          card['location'] = distKm < 1
              ? '${(distKm * 1000).round()} m away'
              : '${distKm.toStringAsFixed(1)} km away';
        }
      }

      // ── Merge business cards from Firestore into apiCards ──
      for (final card in businessCards) {
        final lat = (card['latitude'] as num?)?.toDouble();
        final lng = (card['longitude'] as num?)?.toDouble();
        if (_currentUserLat != null && _currentUserLng != null && lat != null && lng != null) {
          final distKm = _haversineDistance(_currentUserLat!, _currentUserLng!, lat, lng);
          card['location'] = distKm < 1
              ? '${(distKm * 1000).round()} m away'
              : '${distKm.toStringAsFixed(1)} km away';
        }
      }
      // Deduplicate: skip business cards whose userId already appears in API results
      final seenUserIds = apiCards
          .map((c) => c['userId']?.toString() ?? c['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final card in businessCards) {
        final uid = card['_businessUserId']?.toString() ?? '';
        if (uid.isNotEmpty && !seenUserIds.contains(uid)) {
          apiCards.add(card);
          seenUserIds.add(uid);
        }
      }

      // Log card count before any filtering
      debugPrint('ProductAPI: apiCards count after processing = ${apiCards.length}');
      for (int i = 0; i < apiCards.length; i++) {
        debugPrint('ProductAPI: PROCESSED card[$i] name="${apiCards[i]['name']}" sim=${apiCards[i]['similarity_score']} match_score="${apiCards[i]['match_score']}"');
      }

      // Build result text with exact vs similar breakdown
      final String aiText;
      if (apiCards.isNotEmpty) {
        final exactCount = apiCards.where((c) => c['match_type'] == 'exact').length;
        final businessCount = apiCards.where((c) => c['_isBusinessCard'] == true).length;
        final similarCount = apiCards.length - exactCount - businessCount;
        final parts = <String>[];
        if (exactCount > 0) parts.add('$exactCount exact match${exactCount > 1 ? 'es' : ''}');
        if (similarCount > 0) parts.add('$similarCount similar listing${similarCount > 1 ? 's' : ''}');
        if (businessCount > 0) parts.add('$businessCount business${businessCount > 1 ? 'es' : ''}');
        aiText = 'Found ${parts.join(' and ')}';
      } else {
        aiText = apiMessage.isNotEmpty ? apiMessage : 'No matches found for "$intent".';
      }
      setState(() {
        // Remove ALL skeleton cards (reliable — no reference issues)
        _conversation.removeWhere((m) => m['type'] == 'skeleton_results' || m['type'] == 'searching_text');
        _conversation.add({
          'text': aiText,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isProcessing = false;
        if (apiCards.isNotEmpty) {
          _conversation.add({
            'text': '',
            'isUser': false,
            'timestamp': DateTime.now(),
            'type': 'match_results',
            'data': apiCards,
            'query': intent,
          });
        } else if (!isApiError) {
          // Suggest creating a post only when search succeeded but found no matches
          // Don't show this on connection/server errors (post wasn't stored)
          _conversation.add({
            'text': '',
            'isUser': false,
            'timestamp': DateTime.now(),
            'type': 'no_results_create_post',
            'data': {'query': intent},
          });
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // Notify matched post owners that their post was matched
      if (apiCards.isNotEmpty) {
        _notifyMatchedPostOwners(apiCards, intent);
      }
    } catch (e, stack) {
      debugPrint('Error processing intent: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          _conversation.removeWhere((m) => m['type'] == 'skeleton_results' || m['type'] == 'searching_text');
          _conversation.add({
            'text': _getHumanReadableError(e),
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isProcessing = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  String _getHumanReadableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('socket') || errorStr.contains('connection')) {
      return 'No internet connection. Please check your WiFi or mobile data and try again.';
    } else if (errorStr.contains('quota') || errorStr.contains('429') || errorStr.contains('rate limit')) {
      return 'Server is busy right now. Please try again in a few minutes.';
    } else if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Please try logging in again.';
    } else if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Service temporarily unavailable. Please try again later.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Notify post owners when their post is matched by another user's search.
  /// Runs in background (fire-and-forget) so it doesn't block the UI.
  void _notifyMatchedPostOwners(List<Map<String, dynamic>> matchedCards, String searchQuery) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final notificationService = NotificationService();
    final notifiedUserIds = <String>{};

    for (final card in matchedCards) {
      final postOwnerId = (card['user_id'] ?? '').toString();
      // Skip if no user_id, is current user, or already notified
      if (postOwnerId.isEmpty || postOwnerId == currentUserId || notifiedUserIds.contains(postOwnerId)) {
        continue;
      }
      notifiedUserIds.add(postOwnerId);

      final postTitle = (card['name'] ?? searchQuery).toString();
      notificationService.sendNotificationToUser(
        userId: postOwnerId,
        title: 'Your post got a match!',
        body: '$_currentUserName is looking for "$postTitle"',
        type: 'post_matched',
        data: {
          'searchQuery': searchQuery,
          'postTitle': postTitle,
          'listingId': card['listing_id'] ?? '',
        },
      );
    }

    if (notifiedUserIds.isNotEmpty) {
      debugPrint('Match notifications sent to ${notifiedUserIds.length} post owners');
    }
  }

  /// Calculate local text similarity when the API doesn't provide a score.
  /// Returns 0.0–1.0 based on how many query words appear in the card's fields.
  /// Ignores common filler words (price, want, need, etc.) for better accuracy.
  double _calculateLocalSimilarity(String query, Map<String, dynamic> card) {
    const fillerWords = {'i', 'want', 'need', 'looking', 'for', 'a', 'an', 'the', 'my',
      'me', 'price', 'rs', 'rupees', 'inr', 'under', 'below', 'above', 'around', 'about',
      'buy', 'sell', 'get', 'find', 'search', 'show', 'please', 'do', 'can', 'you', 'is', 'it'};
    final queryWords = query.toLowerCase().split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !fillerWords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
        .toSet();
    if (queryWords.isEmpty) return 0.0;

    final name = (card['name'] ?? '').toString().toLowerCase();
    final brand = (card['brand'] ?? '').toString().toLowerCase();
    final model = (card['model'] ?? '').toString().toLowerCase();
    final subintent = (card['subintent'] ?? '').toString().toLowerCase();
    final intent = (card['intent'] ?? '').toString().toLowerCase();
    final itemType = (card['item_type'] ?? '').toString().toLowerCase();
    final category = (card['category'] ?? '').toString().toLowerCase();
    final combined = '$name $brand $model $subintent $intent $itemType $category';

    int matched = 0;
    for (final word in queryWords) {
      if (combined.contains(word)) matched++;
    }

    return (matched / queryWords.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _buildChatState(isDarkMode),
                ),

                // Bottom input section (always visible, recording happens inline)
                _buildInputSection(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(bool isDarkMode) {
    // Add padding for safe area (no bottom nav bar anymore - it's now a top TabBar)
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding + 16,
        top: 16,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _intentController.text = _suggestions[index];
                        _processIntent();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2),
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _suggestions[index],
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Input container with glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                  children: [
                    // Text field OR Audio wave when recording
                    Expanded(
                      child: (_isRecording || _isVoiceProcessing)
                          ? Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  // Recording indicator dot
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Audio wave bars
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: List.generate(10, (index) {
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 3,
                                          height:
                                              6.0 +
                                              (index % 3 == 0
                                                  ? 18.0
                                                  : (index % 2 == 0
                                                        ? 12.0
                                                        : 8.0)),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Recording text - show real-time speech
                                  Flexible(
                                    child: Text(
                                      _isVoiceProcessing
                                          ? 'Processing...'
                                          : _currentSpeechText.isNotEmpty
                                          ? _currentSpeechText
                                          : 'Listening...',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: _currentSpeechText.isNotEmpty
                                            ? Colors.white
                                            : Colors.grey[400],
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(fontFamily: 'Poppins', 
                                color: _isSearchFocused
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontSize: _isSearchFocused ? 13 : 12.5,
                                fontWeight: _isSearchFocused
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                height: 1.4,
                              ),
                              child: TextField(
                                cursorHeight: 15,
                                controller: _intentController,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.search,
                                keyboardType: TextInputType.text,
                                maxLines: 4,
                                minLines: 1,
                                cursorWidth: 2,
                                cursorColor: Colors.white,
                                style: const TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search nearby...',
                                  hintStyle: TextStyle(fontFamily: 'Poppins',
                                    color: Colors.grey[300],
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 16,
                                    left: 6,
                                    right: 4,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                // Don't call setState on every keystroke - causes focus loss
                                onSubmitted: (_) {
                                  if (!_isProcessing) _processIntent();
                                },
                              ),
                            ),
                    ),

                    const SizedBox(width: 2),

                    // Stop button when recording, Mic button otherwise
                    if (_isRecording || _isVoiceProcessing) ...[
                      // Stop button
                      GestureDetector(
                        onTap: _stopVoiceRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Normal mic button
                      GestureDetector(
                        onTap: _startVoiceRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF007AFF),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),

                    // Send button
                    GestureDetector(
                      onTap: _isProcessing ? null : _processIntent,
                      child: Container(
                        width: 42,
                        height: 40,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF007AFF),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
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
        ],
      ),
    );
  }

  Widget _buildChatState(bool isDarkMode) {
    final topPadding = MediaQuery.of(context).padding.top + 16;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topPadding,
              bottom: 4,
            ),
            reverse: false,
            itemCount: _conversation.length,
            itemBuilder: (context, index) {
              final message = _conversation[index];
              return _buildMessageBubble(message, isDarkMode, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isDarkMode,
    int index,
  ) {
    final isUser = message['isUser'] as bool? ?? false;
    final text = message['text'] as String? ?? '';
    final type = message['type'] as String?;

    // Skeleton shimmer cards — show instantly while backend loads (like Flipkart/Amazon)
    if (type == 'skeleton_results') {
      return _buildSkeletonCards();
    }

    // "Create a post" suggestion when no results found
    if (type == 'no_results_create_post') {
      final query = (message['data'] as Map?)?['query'] as String? ?? '';
      return _buildCreatePostSuggestion(query);
    }

    // Result card types - wrap with action row below
    if (type != null && type.endsWith('_results')) {
      final rawData = message['data'];
      if (rawData == null || rawData is! List) return const SizedBox.shrink();
      final data = rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final category = type.replaceAll('_results', '');
      final query = message['query'] as String? ?? '';
      return _buildResultsWidget(data, isDarkMode, category, index, query);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/logo/SingleTap.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Flexible(
                child: Builder(
                  builder: (context) {
                    final maxBubbleWidth =
                        MediaQuery.of(context).size.width * 0.65;
                    const bubblePadding = 28.0; // 14 * 2 horizontal padding

                    final textStyle = TextStyle(fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                      height: 1.4,
                    );

                    // Measure actual text width for tight bubble
                    double bubbleWidth = maxBubbleWidth;
                    if (text.isNotEmpty) {
                      final textPainter = TextPainter(
                        text: TextSpan(text: text, style: textStyle),
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: maxBubbleWidth - bubblePadding);

                      // Find the actual longest line width
                      final lineMetrics = textPainter.computeLineMetrics();
                      double longestLineWidth = 0;
                      for (final line in lineMetrics) {
                        if (line.width > longestLineWidth) {
                          longestLineWidth = line.width;
                        }
                      }

                      bubbleWidth = (longestLineWidth + bubblePadding + 3)
                          .clamp(60.0, maxBubbleWidth);
                    }

                    return Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: bubbleWidth,
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: isUser
                                  ? const Radius.circular(20)
                                  : const Radius.circular(4),
                              bottomRight: isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isUser
                                      ? LinearGradient(
                                          colors: [
                                            Colors.blue.withValues(alpha: 0.6),
                                            Colors.purple.withValues(
                                              alpha: 0.4,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  border: Border.all(
                                    color: isUser
                                        ? Colors.blue.withValues(alpha: 0.4)
                                        : Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isUser
                                        ? const Radius.circular(20)
                                        : const Radius.circular(4),
                                    bottomRight: isUser
                                        ? const Radius.circular(4)
                                        : const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isUser
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(fontFamily: 'Poppins',
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: isUser
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                        height: 1.4,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUser) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            _toggleTts('user_$index', text),
                                        child: Icon(
                                          _currentlyPlayingKey ==
                                                      'user_$index' &&
                                                  _isTtsSpeaking
                                              ? Icons.stop_circle_rounded
                                              : Icons.volume_up_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (isUser)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _currentUserPhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_currentUserPhotoUrl!),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {
                              debugPrint('Error loading profile image: $exception');
                            },
                          )
                        : null,
                    color: _currentUserPhotoUrl == null
                        ? Colors.grey
                        : null,
                  ),
                  child: _currentUserPhotoUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 16)
                      : null,
                ),
            ],
          ),

          // Single Tap-style action icons row (assistant messages only, skip welcome)
          // Hide if next message is a product result card
          if (!isUser && index > 0 && !_hasResultCardAfter(index))
            _buildActionRow(
              'msg_$index',
              text,
              ttsIndex: index,
              showCopy: false,
              showRegenerate: false,
            ),
        ],
      ),
    );
  }

  bool _hasResultCardAfter(int index) {
    if (index + 1 >= _conversation.length) return false;
    final nextType = _conversation[index + 1]['type'] as String?;
    if (nextType == null) return false;
    return nextType.endsWith('_results');
  }

  /// Regenerate the assistant response at the given index
  void _regenerateResponse(int index) async {
    // Find the user message before this assistant message
    String? userMessage;
    for (int i = index - 1; i >= 0; i--) {
      if (_conversation[i]['isUser'] == true) {
        userMessage = _conversation[i]['text'] as String;
        break;
      }
    }
    if (userMessage == null) return;

    setState(() {
      // Remove old assistant response (and any result cards after it)
      while (_conversation.length > index) {
        _conversation.removeAt(index);
      }
      _isProcessing = true;
    });

    // Re-run the full search pipeline
    if (_shouldProcessForMatches(userMessage)) {
      await _processWithIntent(userMessage);
    } else {
      final newResponse = _generateConversationalResponse(userMessage);
      if (mounted) {
        setState(() {
          _conversation.add({
            'text': newResponse,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Auto-save regenerated conversation to chat history
    _autoSaveConversation(userMessage);
  }

  /// Reusable action row for assistant messages
  Widget _buildActionRow(
    String key,
    String textForTts, {
    int? ttsIndex,
    double leftPadding = 40,
    bool showCopy = true,
    bool showRegenerate = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy
          if (showCopy) ...[
            _buildActionIcon(
              icon: Icons.content_copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: textForTts));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
            ),
            const SizedBox(width: 6),
          ],
          // Thumbs up
          _buildActionIcon(
            icon: _likedMessages.contains(key)
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            color: _likedMessages.contains(key) ? Colors.greenAccent : null,
            onTap: () {
              setState(() {
                if (_likedMessages.contains(key)) {
                  _likedMessages.remove(key);
                } else {
                  _likedMessages.add(key);
                  _dislikedMessages.remove(key);
                }
              });
            },
          ),
          const SizedBox(width: 6),
          // Thumbs down
          _buildActionIcon(
            icon: _dislikedMessages.contains(key)
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            color: _dislikedMessages.contains(key) ? Colors.redAccent : null,
            onTap: () {
              setState(() {
                if (_dislikedMessages.contains(key)) {
                  _dislikedMessages.remove(key);
                } else {
                  _dislikedMessages.add(key);
                  _likedMessages.remove(key);
                }
              });
            },
          ),
          const SizedBox(width: 6),
          // TTS / Volume
          _buildActionIcon(
            icon: _currentlyPlayingKey == key && _isTtsSpeaking
                ? Icons.stop_circle_rounded
                : Icons.volume_up_rounded,
            color: _currentlyPlayingKey == key && _isTtsSpeaking
                ? Colors.orangeAccent
                : null,
            onTap: () => _toggleTts(key, textForTts),
          ),
          // Regenerate
          if (showRegenerate && ttsIndex != null) ...[
            const SizedBox(width: 6),
            _buildActionIcon(
              icon: Icons.refresh_rounded,
              onTap: () => _regenerateResponse(ttsIndex),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: color ?? Colors.white.withValues(alpha: 0.5),
          size: 16,
        ),
      ),
    );
  }

  /// "Create a post" + "Similar Matches" buttons shown when search returns no results
  Widget _buildCreatePostSuggestion(String query) {
    return Container(
      margin: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 16),
      child: _buildSearchActionButtons(query),
    );
  }

  /// "Create a post" button shown after search results
  Widget _buildSearchActionButtons(String query) {
    return Row(
      children: [
        Flexible(
          child: _buildPillButton(
            icon: Icons.add_circle_outline,
            label: 'Listing your post',
            iconColor: Colors.blue[300]!,
            bgColor: Colors.blue.withValues(alpha: 0.15),
            borderColor: Colors.blue.withValues(alpha: 0.35),
            onTap: () {
              HapticFeedback.lightImpact();
              _navigateToCreatePost(query);
            },
          ),
        ),
        const Spacer(),
      ],
    );
  }

  /// Reusable pill-shaped button widget
  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer skeleton cards — shown instantly while backend loads (like Flipkart/Amazon)
  Widget _buildSkeletonCards() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 178,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.1),
            highlightColor: Colors.white.withValues(alpha: 0.25),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Title placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      height: 12,
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      height: 10,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
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

  Widget _buildResultsWidget(
    List<Map<String, dynamic>> data,
    bool isDarkMode,
    String category,
    int msgIndex,
    String query,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.length > 2)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showSeeAllProducts(data, category),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    "See All",
                    style: TextStyle(fontFamily: 'Poppins',
                      color: Colors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (data.length > 2) const SizedBox(height: 2),
          SizedBox(
            height: 178,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return _buildItemCard(item, isDarkMode, category);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSeeAllProducts(List<Map<String, dynamic>> data, String category) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            SeeAllProductsScreen(products: data, category: category),
      ),
    );
  }

  /// Get category icon based on domain/category
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('technology') || cat.contains('electronic')) return Icons.devices;
    if (cat.contains('food') || cat.contains('restaurant')) return Icons.restaurant;
    if (cat.contains('real estate') || cat.contains('house') || cat.contains('property')) return Icons.home;
    if (cat.contains('vehicle') || cat.contains('car') || cat.contains('bike')) return Icons.directions_car;
    if (cat.contains('fashion') || cat.contains('cloth')) return Icons.checkroom;
    if (cat.contains('sport')) return Icons.sports;
    if (cat.contains('book') || cat.contains('education')) return Icons.menu_book;
    if (cat.contains('job') || cat.contains('service')) return Icons.work;
    return Icons.shopping_bag;
  }

  Widget _buildImagePlaceholder(String category) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[800]!, Colors.grey[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(_getCategoryIcon(category), color: Colors.white38, size: 40),
    );
  }

  Widget _buildUserInitialsPlaceholder(String name) {
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Generate a unique save ID for a product item
  String _productSaveId(Map<String, dynamic> item) {
    // Use postId if available (from API), otherwise hash from name+price
    final postId = item['listing_id'] ?? item['postId'] ?? item['id'] ?? item['_id'];
    if (postId != null && postId.toString().isNotEmpty) return postId.toString();
    final name = (item['name'] ?? '').toString();
    final price = (item['price'] ?? '').toString();
    return 'product_${name.hashCode}_${price.hashCode}';
  }

  Widget _buildSaveButton(Map<String, dynamic> item) {
    final saveId = _productSaveId(item);
    final isSaved = _savedPostIds.contains(saveId);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleSaveProduct(saveId, item),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF016CFF).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    String category,
  ) {
    final brand = item['brand'] as String? ?? '';
    final itemType = item['item_type'] as String? ?? '';
    final variant = item['variant'] as String? ?? '';
    final subVariant = item['sub_variant'] as String? ?? '';
    final domainList = item['domain'] as List<dynamic>? ?? [];
    final domainStr = domainList.isNotEmpty ? domainList.first.toString() : '';
    // Line 2: brand (+ variant) → domain → item type → category
    String subtitleLine = brand.isNotEmpty ? brand : (domainStr.isNotEmpty ? domainStr : (itemType.isNotEmpty ? itemType : category));
    // Append variant info if available (e.g., "Apple · Pro Max")
    if (variant.isNotEmpty || subVariant.isNotEmpty) {
      final variantStr = [variant, subVariant].where((v) => v.isNotEmpty).join(' ');
      if (subtitleLine.isNotEmpty) {
        subtitleLine = '$subtitleLine · $variantStr';
      } else {
        subtitleLine = variantStr;
      }
    }
    final imageUrl = item['image'] as String? ?? '';
    final matchType = item['match_type'] as String? ?? '';
    final price = item['price'] as String? ?? '';

    // Show distance in km instead of location name
    String location = '';
    final rawLoc = item['_raw_location'];
    if (_currentUserLat != null && _currentUserLng != null && rawLoc is Map) {
      Map<String, dynamic>? coords;
      if (rawLoc['coordinates'] is Map) {
        coords = Map<String, dynamic>.from(rawLoc['coordinates'] as Map);
      } else if (rawLoc['lat'] != null && rawLoc['lng'] != null) {
        coords = {'lat': rawLoc['lat'], 'lng': rawLoc['lng']};
      }
      if (coords != null) {
        final lat = (coords['lat'] as num?)?.toDouble();
        final lng = (coords['lng'] as num?)?.toDouble();
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          final distKm = _haversineDistance(_currentUserLat!, _currentUserLng!, lat, lng);
          location = distKm < 1
              ? '${(distKm * 1000).round()} m away'
              : '${distKm.toStringAsFixed(1)} km away';
        }
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Match results: navigate to chat with the matched user
        final matchData = item['_matchData'] as Map<String, dynamic>?;
        if (matchData != null) {
          final userProfile = matchData['userProfile'] as Map<String, dynamic>? ?? {};
          final otherUser = UserProfile.fromMap(userProfile, matchData['userId']);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser, source: 'Matching'),
            ),
          );
          return;
        }
        // Business card → navigate to PublicBusinessProfileScreen
        if (item['_isBusinessCard'] == true) {
          final uid = item['_businessUserId'] as String? ?? '';
          if (uid.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicBusinessProfileScreen(userId: uid),
              ),
            );
            return;
          }
        }
        // Product results: navigate to product detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailScreen(item: item, category: category),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image or placeholder
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 100,
                          width: double.infinity,
                          fit: (matchType == 'match' || matchType == 'business') ? BoxFit.contain : BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return (matchType == 'match' || matchType == 'business')
                                ? _buildUserInitialsPlaceholder(item['name'] as String? ?? '')
                                : _buildImagePlaceholder(itemType.isNotEmpty ? itemType : category);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 100,
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        )
                      : (matchType == 'match' || matchType == 'business')
                          ? _buildUserInitialsPlaceholder(item['name'] as String? ?? '')
                          : _buildImagePlaceholder(itemType.isNotEmpty ? itemType : category),
                ),
                // Match type badge
                () {
                  final simScore = (item['similarity_score'] as num?)?.toDouble() ?? 0.0;
                  final scorePercent = (simScore * 100).toStringAsFixed(0);
                  final isBusinessCard = item['_isBusinessCard'] == true;
                  final isExact = matchType == 'exact';
                  Color badgeColor;
                  String badgeText;
                  if (isBusinessCard) {
                    badgeColor = Colors.blue.withValues(alpha: 0.85);
                    badgeText = 'Business $scorePercent%';
                  } else if (isExact) {
                    badgeColor = Colors.green.withValues(alpha: 0.85);
                    badgeText = 'Exact Match';
                  } else {
                    badgeColor = Colors.orange.withValues(alpha: 0.85);
                    badgeText = 'Similar $scorePercent%';
                  }
                  return Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }(),
                // Save / Bookmark button (top-right)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _buildSaveButton(item),
                ),
              ],
            ),
            // Details — 4 lines: Model, Brand, Budget, Location
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    // Line 1: Model
                    Text(
                      (item['model'] as String? ?? '').isNotEmpty
                          ? item['model'] as String
                          : (item['name'] as String? ?? subtitleLine),
                      style: const TextStyle(fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Line 2: Brand (+ variant)
                    if (subtitleLine.isNotEmpty)
                      Text(
                        subtitleLine,
                        style: TextStyle(fontFamily: 'Poppins',
                          color: Colors.grey[400],
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Line 3: Price / Budget
                    () {
                      final budget = item['budget']?.toString() ?? '';
                      final zeroPrices = {'', '₹0', '₹0.0', '₹0 - ₹0', '₹0.0 - ₹0.0'};
                      String priceDisplay = '';
                      if (price.isNotEmpty && !zeroPrices.contains(price)) {
                        priceDisplay = price;
                      } else if (budget.isNotEmpty && budget != '0' && budget != '0.0' && budget != 'null') {
                        priceDisplay = budget.startsWith('₹') ? budget : '₹$budget';
                      }
                      debugPrint('CardUI price=$price, budget=$budget, display=$priceDisplay');
                      if (priceDisplay.isEmpty) return const SizedBox.shrink();
                      return Text(
                        priceDisplay,
                        style: TextStyle(fontFamily: 'Poppins',
                          color: Colors.green[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }(),
                    // Line 4: Location
                    if (location.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.near_me, color: Colors.grey[500], size: 11),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontFamily: 'Poppins',
                                color: Colors.grey[400],
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
    );
  }

}

// 3D Animated Drawer Transition
class Drawer3DTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const Drawer3DTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth = screenWidth * 0.58;

        // Calculate 3D transformation values
        final slideValue = animation.value;
        final rotationAngle =
            (1 - slideValue) * -0.5; // Rotate from -0.5 rad to 0
        final scaleValue = 0.85 + (slideValue * 0.15); // Scale from 0.85 to 1.0
        final translateX = -drawerWidth * (1 - slideValue); // Slide from left

        // Background overlay opacity
        final overlayOpacity = slideValue * 0.6;

        // Main content scale and translate (push effect)
        final mainContentScale = 1.0 - (slideValue * 0.1);
        final mainContentTranslateX = slideValue * drawerWidth * 0.3;
        final mainContentRotation = slideValue * 0.15;

        return Stack(
          children: [
            // Main content with 3D push effect (simulated) - behind everything
            if (slideValue > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..setTranslationRaw(mainContentTranslateX, 0, 0)
                      ..multiply(
                        Matrix4.diagonal3Values(
                          mainContentScale,
                          mainContentScale,
                          1.0,
                        ),
                      )
                      ..rotateY(mainContentRotation),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20 * slideValue),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.3 * slideValue,
                            ),
                            blurRadius: 30,
                            offset: const Offset(-10, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Tap area on the right side to close drawer
            Positioned(
              left: drawerWidth * slideValue,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -10) {
                    Navigator.pop(context);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: overlayOpacity),
                ),
              ),
            ),

            // 3D Drawer with rotation and scale
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // Perspective
                  ..setTranslationRaw(translateX, 0, 0)
                  ..rotateY(rotationAngle)
                  ..multiply(
                    Matrix4.diagonal3Values(scaleValue, scaleValue, 1.0),
                  ),
                child: Container(
                  width: drawerWidth,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2 * slideValue),
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: const Offset(10, 0),
                      ),
                      BoxShadow(
                        color: Colors.purple.withValues(
                          alpha: 0.1 * slideValue,
                        ),
                        blurRadius: 60,
                        spreadRadius: 10,
                        offset: const Offset(20, 0),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: slideValue.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Single Tap-style Side Drawer
class _ChatHistorySideDrawer extends StatefulWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSearchChats;
  final VoidCallback onLibrary;
  final VoidCallback onProjects;
  final VoidCallback onGroupChat;

  const _ChatHistorySideDrawer({
    required this.onNewChat,
    required this.onSearchChats,
    required this.onLibrary,
    required this.onProjects,
    required this.onGroupChat,
  });

  @override
  State<_ChatHistorySideDrawer> createState() => _ChatHistorySideDrawerState();
}

class _ChatHistorySideDrawerState extends State<_ChatHistorySideDrawer>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _shimmerController;
  late List<Animation<double>> _itemAnimations;

  final List<Map<String, dynamic>> _chatHistory = [
    {
      'title': 'Looking for iPhone 13',
      'time': 'Today',
      'icon': Icons.phone_iphone,
    },
    {
      'title': 'Best restaurants nearby',
      'time': 'Today',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Job search - Developer',
      'time': 'Yesterday',
      'icon': Icons.work_outline,
    },
    {
      'title': 'Apartment for rent',
      'time': 'Yesterday',
      'icon': Icons.home_outlined,
    },
    {
      'title': 'Grocery shopping list',
      'time': 'Last 7 days',
      'icon': Icons.shopping_cart_outlined,
    },
    {
      'title': 'Travel plans',
      'time': 'Last 7 days',
      'icon': Icons.flight_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Stagger animation controller for items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Shimmer animation controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Create staggered animations for each item (total 10 items approx)
    _itemAnimations = List.generate(10, (index) {
      final startTime = index * 0.1;
      final endTime = startTime + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            startTime.clamp(0.0, 1.0),
            endTime.clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        ),
      );
    });

    // Start animation
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.58;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            width: drawerWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              // Glassmorphism - transparent with subtle tint
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.blue.withValues(alpha: 0.05),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              // Glass border - bright edge
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              // Depth shadows
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(8, 0),
                ),
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 60,
                  spreadRadius: -5,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with New Chat button - Animated
                  _buildAnimatedItem(
                    0,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNewChat();
                        },
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.blue.withValues(
                                      alpha:
                                          0.15 +
                                          (_shimmerController.value * 0.1),
                                    ),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                  stops: [0.0, _shimmerController.value, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 600),
                                    builder: (context, value, child) {
                                      return Transform.rotate(
                                        angle: (1 - value) * 0.5,
                                        child: Transform.scale(
                                          scale: 0.5 + (value * 0.5),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'New Chat',
                                    style: TextStyle(fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Search Bar - Animated
                  _buildAnimatedItem(
                    1,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onSearchChats();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Search chats...',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Menu Items (Library, Projects, Group Chat) - Animated
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _buildAnimatedItem(
                          2,
                          _buildMenuItem(
                            Icons.folder_open_outlined,
                            'Library',
                            Colors.orange,
                            widget.onLibrary,
                          ),
                        ),
                        _buildAnimatedItem(
                          3,
                          _buildMenuItem(
                            Icons.folder_special_outlined,
                            'Projects',
                            Colors.purple,
                            widget.onProjects,
                          ),
                        ),
                        _buildAnimatedItem(
                          4,
                          _buildMenuItem(
                            Icons.group_outlined,
                            'Group Chats',
                            Colors.green,
                            widget.onGroupChat,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Chat History List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount:
                          _chatHistory.length + 3, // +3 for section headers
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSectionHeader('Today');
                        } else if (index <= 2) {
                          return _buildChatItem(_chatHistory[index - 1]);
                        } else if (index == 3) {
                          return _buildSectionHeader('Yesterday');
                        } else if (index <= 5) {
                          return _buildChatItem(_chatHistory[index - 2]);
                        } else if (index == 6) {
                          return _buildSectionHeader('Last 7 days');
                        } else {
                          return _buildChatItem(_chatHistory[index - 3]);
                        }
                      },
                    ),
                  ),

                  // Bottom section with user profile
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Account',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Settings & Preferences',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.more_horiz,
                          color: Colors.white.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    if (index >= _itemAnimations.length) {
      return child;
    }
    return AnimatedBuilder(
      animation: _itemAnimations[index],
      builder: (context, _) {
        final value = _itemAnimations[index].value;
        return Transform.translate(
          offset: Offset(-30 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 14, top: 12, bottom: 8),
        child: Text(
          title,
          style: TextStyle(fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-40 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Icon(
                  chat['icon'] as IconData,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chat['title'] as String,
                  style: TextStyle(fontFamily: 'Poppins',
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.more_horiz,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated typing dots (three bouncing dots)
class _TypingDotsWidget extends StatefulWidget {
  const _TypingDotsWidget();

  @override
  State<_TypingDotsWidget> createState() => _TypingDotsWidgetState();
}

class _TypingDotsWidgetState extends State<_TypingDotsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay) % 1.0;
            final bounce = t < 0.5 ? math.sin(t * math.pi) : 0.0;
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6 + 0.4 * bounce),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
