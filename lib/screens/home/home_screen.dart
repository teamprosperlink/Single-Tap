import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/universal_intent_service.dart';
import '../../services/location services/gemini_service.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../services/realtime_matching_service.dart';
import '../../services/profile services/photo_cache_service.dart';
import 'product/product_detail_screen.dart';
import 'product/see_all_products_screen.dart';
import 'voice_assistant_screen.dart';
import '../../widgets/voice_orb.dart';
import '../profile/profile_view_screen.dart';

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
  final UniversalIntentService _intentService = UniversalIntentService();
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();
  final GeminiService _geminiService = GeminiService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();

  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();

  bool _isSearchFocused = false;
  bool _isProcessing = false;

  final List<String> _suggestions = [];
  final List<Map<String, dynamic>> _matches = [];

  late AnimationController _controller;
  Timer? _timer;

  final List<Map<String, dynamic>> _conversation = [];

  // Current chat ID for auto-save (ChatGPT style)
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

  // ChatGPT-style action states
  final Set<String> _likedMessages = {};
  final Set<String> _dislikedMessages = {};
  String _currentSpeechText = '';

  @override
  void initState() {
    super.initState();
    _loadUserIntents();
    _loadUserProfile();
    _realtimeService.initialize();
    _initTts();

    _controller = AnimationController(vsync: this);

    _searchFocusNode.addListener(_onFocusChange);

    _conversation.add({
      'text':
          'Hi! I\'m your Supper assistant. What would you like to find today?',
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
    _realtimeService.dispose();
    _controller.dispose();
    _timer?.cancel();
    _recordingTimer?.cancel();
    _chatScrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  /// Reset for new chat (ChatGPT style - conversation is auto-saved)
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
        _matches.clear();
        _intentController.clear();
        _currentChatId = chatId;
        _currentProjectId = null; // Clear project context when loading a chat

        // Restore messages
        for (var msg in messages) {
          _conversation.add({
            'text': msg['text'],
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
      _matches.clear();
      _intentController.clear();
      _currentChatId = null; // Reset chat ID for new conversation
      _currentProjectId = null; // Reset project context

      // Add welcome message
      _conversation.add({
        'text':
            'Hi! I\'m your Supper assistant. What would you like to find today?',
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadUserIntents() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _intentService.getUserIntents(userId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _processIntent() async {
    if (_intentController.text.isEmpty) return;

    final userMessage = _intentController.text.trim();
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

    // Get real Gemini AI response
    final aiResponse = await _getGeminiResponse(userMessage);

    if (!mounted) return;

    setState(() {
      _conversation.add({
        'text': aiResponse,
        'isUser': false,
        'timestamp': DateTime.now(),
      });
      _isProcessing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Always create post + find matches for every user message
    await _processWithIntent(userMessage);

    // Auto-save conversation to chat history (ChatGPT style)
    await _autoSaveConversation(userMessage);
  }

  /// Auto-save conversation after each message (ChatGPT style)
  Future<void> _autoSaveConversation(String userMessage) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final messagesToSave = _conversation.map((msg) {
        // Convert DateTime to Timestamp for Firestore
        final timestamp = msg['timestamp'];
        final firestoreTimestamp = timestamp is DateTime
            ? Timestamp.fromDate(timestamp)
            : timestamp;

        return <String, dynamic>{
          'text': msg['text'],
          'isUser': msg['isUser'],
          'timestamp': firestoreTimestamp,
          'type': msg['type'],
          'data': msg['data'],
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
        final chatData = <String, dynamic>{
          'userId': userId,
          'title': title,
          'messages': messagesToSave,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (_currentProjectId != null) {
          chatData['projectId'] = _currentProjectId;
        }
        final docRef = await FirebaseFirestore.instance
            .collection('chat_history')
            .add(chatData);
        _currentChatId = docRef.id;
        debugPrint('New chat created: $_currentChatId');

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
              'messages': messagesToSave,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        debugPrint('Chat updated: $_currentChatId');
      }
    } catch (e) {
      debugPrint('Error auto-saving conversation: $e');
    }
  }


  // Initialize speech recognition
  bool _isFinishingRecording = false;

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording && !_isFinishingRecording) {
              _finishRecording();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted && _isRecording && !_isFinishingRecording) {
            final errorMsg = error.errorMsg;
            if (errorMsg == 'error_no_match' || errorMsg == 'error_speech_timeout') {
              // No speech detected — return to idle, don't use mock
              _isFinishingRecording = true;
              _recordingTimer?.cancel();
              setState(() {
                _isRecording = false;
                _isVoiceProcessing = false;
                _currentSpeechText = '';
              });
              _isFinishingRecording = false;
            } else {
              _finishRecording();
            }
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _currentSpeechText = '';
    });

    if (!_speechEnabled) {
      await _initSpeech();
    }

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
        // Return to idle — don't inject a fake query
        setState(() {
          _isRecording = false;
          _isVoiceProcessing = false;
        });
      }
    } else {
      // Speech not available — return to idle
      setState(() {
        _isRecording = false;
        _isVoiceProcessing = false;
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

  void _finishRecording() {
    if (!_isRecording || _isFinishingRecording) return;
    _isFinishingRecording = true;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final spokenText = _currentSpeechText.trim();

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = spokenText.isNotEmpty;
    });

    _isFinishingRecording = false;

    // If no speech detected, just return to idle
    if (spokenText.isEmpty) {
      setState(() {
        _isVoiceProcessing = false;
      });
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
    setState(() {
      _isProcessing = true;
    });

    // Get real Gemini AI response
    final aiResponse = await _getGeminiResponse(message);

    if (!mounted) return;

    setState(() {
      _conversation.add({
        'text': aiResponse,
        'isUser': false,
        'timestamp': DateTime.now(),
      });
      _isProcessing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Always create post + find matches for every voice message
    await _processWithIntent(message);
  }

  Future<void> _processWithIntent(String intent) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _intentService.processIntentAndMatch(intent);

      if (!mounted) return;

      if (result['success'] == true) {
        final matches = List<Map<String, dynamic>>.from(
          result['matches'] ?? [],
        );

        for (final match in matches) {
          final userProfile = match['userProfile'] as Map<String, dynamic>? ?? {};
          final userId = match['userId'];
          // Check all common photo URL key variants
          final photoUrl =
              userProfile['photoUrl'] ??
              userProfile['photoURL'] ??
              userProfile['profileImageUrl'];
          if (userId != null && photoUrl != null) {
            _photoCache.cachePhotoUrl(userId, photoUrl.toString());
          }
        }

        setState(() {
          _isProcessing = false;
          if (matches.isNotEmpty) {
            _conversation.add({
              'text':
                  'Found ${matches.length} potential match${matches.length == 1 ? '' : 'es'} for you!',
              'isUser': false,
              'timestamp': DateTime.now(),
              'type': 'match_results',
              'data': matches,
            });
          } else {
            _conversation.add({
              'text':
                  'No matches found yet. Try a more specific description or check back later!',
              'isUser': false,
              'timestamp': DateTime.now(),
            });
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        _loadUserIntents();
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<String> _getGeminiResponse(String userMessage) async {
    try {
      final prompt =
          'You are an AI assistant for Supper, an intent-matching app where users post what they need or offer and get matched with others. '
          'User says: "$userMessage". '
          'Respond in 1-2 friendly sentences. Confirm you understood their intent and that you are searching for matches.';
      return await _geminiService.generateContent(prompt) ??
          'I understand: "$userMessage". Searching for matches now!';
    } catch (_) {
      return 'I understand you\'re looking for: "$userMessage". Let me find the best matches for you!';
    }
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)}m away';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceInKm.toStringAsFixed(0)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        centerTitle: false,
        leadingWidth: 56,
        title: const SizedBox.shrink(),
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
          // AI Voice Assistant banner
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VoiceAssistantScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const VoiceOrb(state: VoiceOrbState.idle, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('AI Voice Assistant',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('Tap to search with your voice',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.7), size: 18),
                ],
              ),
            ),
          ),

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
                          style: TextStyle(
                            fontSize: 13,
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
                child: Row(
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
                                      style: TextStyle(
                                        color: _currentSpeechText.isNotEmpty
                                            ? Colors.white
                                            : Colors.grey[400],
                                        fontSize: 12,
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
                              style: TextStyle(
                                color: _isSearchFocused
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontSize: _isSearchFocused ? 16 : 15,
                                fontWeight: _isSearchFocused
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                height: 1.4,
                              ),
                              child: TextField(
                                cursorHeight: 17,
                                controller: _intentController,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.text,
                                maxLines: 1,
                                cursorWidth: 2,
                                cursorColor: Colors.white,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ask me anything...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                // Don't call setState on every keystroke - causes focus loss
                                onSubmitted: (_) => _processIntent(),
                              ),
                            ),
                    ),

                    const SizedBox(width: 8),

                    // Stop button when recording, Mic button otherwise
                    if (_isRecording || _isVoiceProcessing) ...[
                      // Stop button
                      GestureDetector(
                        onTap: _stopVoiceRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(bottom: 7.5),
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
                          margin: const EdgeInsets.only(left: 6, bottom: 7.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),

                    // Send button
                    GestureDetector(
                      onTap: _isProcessing ? null : _processIntent,
                      child: Container(
                        width: 50,
                        height: 40,
                        margin: const EdgeInsets.only(right: 6, bottom: 7.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
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
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight - 32;
    return Column(
      children: [
        SizedBox(height: topPadding),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    final isUser = message['isUser'] as bool;
    final text = message['text'] as String;
    final type = message['type'] as String?;

    // Match results — render as vertical list of match cards inside the chat
    if (type == 'match_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildMatchesInChat(data, isDarkMode);
    }

    // Result card types - wrap with action row below
    if (type != null && type.endsWith('_results')) {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();

      // Skip news and reels results
      if (type == 'news_results' || type == 'reels_results') {
        return const SizedBox.shrink();
      }

      final category = type.replaceAll('_results', '');
      return _buildResultsWidget(data, isDarkMode, category, index);
    }

    return Container(
      margin: EdgeInsets.only(
        top: isUser ? 12 : 1,
        bottom: isUser ? 8 : 1,
      ),
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
                      image: AssetImage('assets/logo/Clogo.jpeg'),
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

                    final textStyle = TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
                      double longestLineWidth = textPainter.width;
                      for (final line in lineMetrics) {
                        if (line.width > longestLineWidth) {
                          longestLineWidth = line.width;
                        }
                      }
                      if (lineMetrics.isNotEmpty) {
                        longestLineWidth = 0;
                        for (final line in lineMetrics) {
                          if (line.width > longestLineWidth) {
                            longestLineWidth = line.width;
                          }
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
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
                                        onTap: () => _toggleTts(
                                          'user_$index',
                                          text,
                                        ),
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
                    image: _auth.currentUser?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(_auth.currentUser!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: _auth.currentUser?.photoURL == null
                        ? Colors.grey
                        : null,
                  ),
                  child: _auth.currentUser?.photoURL == null
                      ? const Icon(Icons.person, color: Colors.white, size: 16)
                      : null,
                ),
            ],
          ),

          // ChatGPT-style action icons row (assistant messages only, skip welcome)
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
    // News and reels results are skipped (SizedBox.shrink), so don't hide action row
    if (nextType == 'news_results' || nextType == 'reels_results') return false;
    return nextType.endsWith('_results');
  }

  /// Regenerate the assistant response at the given index
  void _regenerateResponse(int index) {
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

    _getGeminiResponse(userMessage).then((newResponse) {
      if (!mounted) return;
      setState(() {
        _conversation.add({
          'text': newResponse,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
        _isProcessing = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
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
                ScaffoldMessenger.of(context).showSnackBar(
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

  Widget _buildResultsWidget(
    List<Map<String, dynamic>> data,
    bool isDarkMode,
    String category,
    int msgIndex,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "See All",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (data.length > 2) const SizedBox(height: 4),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final productName = item['name'] as String? ?? '';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildItemCard(item, isDarkMode, category),
                    _buildActionRow(
                      'product_${msgIndex}_$index',
                      productName,
                      leftPadding: 0,
                      showCopy: false,
                      showRegenerate: false,
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

  void _showSeeAllProducts(List<Map<String, dynamic>> data, String category) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SeeAllProductsScreen(
          products: data,
          category: category,
        ),
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    String category,
  ) {
    // Get icon based on category
    IconData getIcon() {
      switch (category) {
        case 'food':
          return Icons.restaurant;
        case 'electric':
          return Icons.devices;
        case 'house':
          return Icons.home;
        case 'place':
          return Icons.place;
        default:
          return Icons.category;
      }
    }

    // Get subtitle based on category
    String getSubtitle() {
      switch (category) {
        case 'food':
          return item['restaurant'] as String? ?? '';
        case 'electric':
          return item['brand'] as String? ?? '';
        case 'house':
          return item['location'] as String? ?? '';
        case 'place':
          return item['location'] as String? ?? '';
        default:
          return '';
      }
    }

    // Get bottom info based on category
    String getBottomInfo() {
      return item['distance'] as String? ?? item['location'] as String? ?? '';
    }

    // Get bottom icon based on category
    IconData getBottomIcon() {
      return Icons.location_on;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to unified detail screen
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with download button
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    item['image'] as String? ?? '',
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[700],
                        child: Icon(getIcon(), color: Colors.white54, size: 40),
                      );
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
                  ),
                ),
              ],
            ),
            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item['name'] as String? ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Subtitle (restaurant/brand/location)
                  Text(
                    getSubtitle(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Price & Rating Row
                  Row(
                    children: [
                      // Price
                      Expanded(
                        child: Text(
                          item['price'] as String? ?? '',
                          style: TextStyle(
                            color: Colors.green[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rating
                      Icon(Icons.star, color: Colors.amber[400], size: 14),
                      const SizedBox(width: 2),
                      Text(
                        '${item['rating']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Bottom info (distance/condition/area)
                  Row(
                    children: [
                      Icon(getBottomIcon(), color: Colors.grey[500], size: 12),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          getBottomInfo(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
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

  Widget _buildMatchesInChat(
    List<Map<String, dynamic>> matches,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: matches
            .map((match) => _buildMatchCard(match, isDarkMode))
            .toList(),
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, bool isDarkMode) {
    final userProfile = match['userProfile'] as Map<String, dynamic>? ?? {};
    final matchScore = (match['matchScore'] ?? 0.0) * 100;
    // Resolve name: top-level key first (set by _enrichMatchesWithProfiles),
    // then fall back to profile fields.
    final userName =
        (match['userName'] as String?)?.isNotEmpty == true
            ? match['userName'] as String
            : (userProfile['name'] as String?)?.isNotEmpty == true
            ? userProfile['name'] as String
            : userProfile['displayName'] as String? ??
                userProfile['phone'] as String? ??
                'Unknown User';
    final userId = match['userId'];

    final cachedPhoto = userId != null
        ? _photoCache.getCachedPhotoUrl(userId)
        : null;
    final photoUrl =
        cachedPhoto ??
        userProfile['photoUrl'] ??
        userProfile['photoURL'] ??
        userProfile['profileImageUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          final otherUser = UserProfile.fromMap(userProfile, match['userId']);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl: photoUrl,
                    radius: 24,
                    fallbackText: userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${matchScore.toStringAsFixed(0)}% match',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile['city'].toString(),
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (match['distance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(match['distance'] as double),
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['title'] ??
                          match['description'] ??
                          'Looking for match',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null &&
                        match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Action buttons: Chat + View Profile
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final otherUser = UserProfile.fromMap(
                          userProfile,
                          match['userId'],
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EnhancedChatScreen(otherUser: otherUser),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Chat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final nav = Navigator.of(context);
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(match['userId'])
                            .get();
                        if (!userDoc.exists) return;
                        final profile = UserProfile.fromFirestore(userDoc);
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileViewScreen(userProfile: profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

// SingleTap-style Side Drawer
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

  List<Map<String, dynamic>> _realChatHistory = [];
  bool _isLoadingHistory = false;

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

    // Start animation and load real chat history
    _staggerController.forward();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (mounted) setState(() => _isLoadingHistory = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_history')
          .where('userId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
      if (mounted) {
        setState(() {
          _realChatHistory = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _chatLabel(Map<String, dynamic> chat) {
    return chat['title'] as String? ??
        chat['firstMessage'] as String? ??
        'Chat';
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
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
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
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
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
                    child: _isLoadingHistory
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          )
                        : _realChatHistory.isEmpty
                            ? Center(
                                child: Text(
                                  'No chat history yet',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                itemCount: _realChatHistory.length,
                                itemBuilder: (context, index) {
                                  return _buildChatItem(
                                    _realChatHistory[index],
                                  );
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Settings & Preferences',
                                style: TextStyle(
                                  color: Colors.white54,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
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
                  Icons.chat_bubble_outline,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _chatLabel(chat),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
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
