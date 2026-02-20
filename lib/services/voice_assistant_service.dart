import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_provider.dart';
import 'location services/gemini_service.dart';
import 'unified_post_service.dart';
import '../res/config/api_config.dart';

enum VoiceAssistantState { idle, listening, processing, speaking }

class VoiceMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? results;

  const VoiceMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.results,
  });
}

class VoiceAssistantService extends ChangeNotifier {
  VoiceAssistantState _state = VoiceAssistantState.idle;
  String _partialTranscript = '';
  final List<VoiceMessage> _messages = [];
  List<Map<String, dynamic>> _lastResults = [];
  String _processingHint = '';
  String _errorHint = '';

  final _gemini = GeminiService();
  final _stt = stt.SpeechToText();
  final _tts = FlutterTts();

  final List<Content> _history = [];
  static const _maxHistoryItems = 40;

  bool _sttInitialized = false;
  Timer? _silenceTimer;
  Timer? _speakingTimeout;
  bool _isProcessingTurn = false;

  int _sttRestartCount = 0;
  static const _maxSttRestarts = 3;
  bool _gotFinalResult = false;

  // Navigation callback — set by the screen before use
  void Function(String screen)? onNavigate;

  // Getters
  VoiceAssistantState get state => _state;
  String get partialTranscript => _partialTranscript;
  List<VoiceMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get lastResults => _lastResults;
  String get processingHint => _processingHint;
  String get errorHint => _errorHint;

  // ── Gemini function declarations ──────────────────────────────────────────

  static final _tools = [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'searchPosts',
        'Search active posts by keyword query. Use when user wants to find posts, services, or listings.',
        Schema.object(properties: {
          'query': Schema.string(description: 'Search keywords'),
        }),
      ),
      FunctionDeclaration(
        'getMyPosts',
        'Get the current user\'s own posts/listings. Use when user asks about their posts.',
        null,
      ),
      FunctionDeclaration(
        'getMatches',
        'Find posts that match a given post by semantic similarity.',
        Schema.object(properties: {
          'postId': Schema.string(description: 'The post ID to find matches for'),
        }),
      ),
      FunctionDeclaration(
        'getUserProfile',
        'Get the current user\'s profile information.',
        null,
      ),
      FunctionDeclaration(
        'searchByEmbedding',
        'Find posts semantically similar to a natural language query using AI embeddings.',
        Schema.object(properties: {
          'text': Schema.string(description: 'Natural language search query'),
        }),
      ),
      FunctionDeclaration(
        'searchNearby',
        'Search for posts near the user\'s location using semantic similarity and proximity.',
        Schema.object(properties: {
          'text': Schema.string(description: 'What the user is looking for'),
          'radiusKm': Schema.number(description: 'Search radius in kilometers, default 25'),
        }),
      ),
      FunctionDeclaration(
        'findMatchesForMe',
        'Find the best matching posts for the current user based on their own active posts. Use when user says "find matches for me", "who matches my needs", "show my best matches".',
        null,
      ),
      FunctionDeclaration(
        'createPost',
        'Create a new post/listing for the user using their natural language description. Call this when the user says "post that I need...", "create a listing for...", "I want to post that I\'m looking for...", "add a post saying...".',
        Schema.object(properties: {
          'prompt': Schema.string(
              description: 'The full natural language description of what the user wants to post'),
        }),
      ),
      FunctionDeclaration(
        'navigateTo',
        'Navigate the user to a different screen in the app. Call when user says "go to messages", "open discover", "take me to my profile", "show nearby", "open conversations".',
        Schema.object(properties: {
          'screen': Schema.string(
              description: 'Target screen name: "messages", "discover", "nearby", "profile", "live"'),
        }),
      ),
      FunctionDeclaration(
        'getRecentConversations',
        'Get the user\'s recent conversations/chats. Use when user asks "who am I talking to", "show my chats", "any new messages".',
        null,
      ),
    ]),
  ];

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_sttInitialized) return;

    _sttInitialized = await _stt.initialize(
      onStatus: (status) {
        debugPrint('VoiceAssistant STT status: $status');
        if (status == 'done' &&
            _state == VoiceAssistantState.listening &&
            !_isProcessingTurn &&
            !_gotFinalResult) {
          _attemptSttRestart();
        }
      },
      onError: (error) {
        debugPrint('VoiceAssistant STT error: $error');
        if (_state != VoiceAssistantState.listening || _isProcessingTurn) return;
        final errorMsg = error.errorMsg;
        if (errorMsg == 'error_network' || errorMsg == 'error_client') return;
        _silenceTimer?.cancel();
        if (errorMsg == 'error_no_match' || errorMsg == 'error_speech_timeout') {
          _state = VoiceAssistantState.idle;
          _partialTranscript = '';
          _errorHint = "Didn't catch that. Try again or type below.";
          notifyListeners();
          Future.delayed(const Duration(seconds: 3), () {
            if (_errorHint.isNotEmpty) {
              _errorHint = '';
              notifyListeners();
            }
          });
        } else if (_partialTranscript.isNotEmpty) {
          _processUserTurn(_partialTranscript);
        } else {
          _state = VoiceAssistantState.idle;
          _partialTranscript = '';
          notifyListeners();
        }
      },
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.52);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _speakingTimeout?.cancel();
      _state = VoiceAssistantState.idle;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _speakingTimeout?.cancel();
      _state = VoiceAssistantState.idle;
      notifyListeners();
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      _speakingTimeout?.cancel();
      _state = VoiceAssistantState.idle;
      notifyListeners();
    });

    // Fetch user context and initialize the voice model
    await _initVoiceModel();

    _messages.add(VoiceMessage(
      text: "Hi! I'm Supra, your SingleTap assistant. Ask me anything — general knowledge, search posts, find matches, or create a new listing. Speak or type below.",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// Fetch user profile and build the context-aware system prompt,
  /// then hand everything to GeminiService so the model is cached.
  Future<void> _initVoiceModel() async {
    final uid = FirebaseProvider.currentUserId;
    String userName = 'there';
    int activePostCount = 0;

    if (uid != null) {
      try {
        final userDoc =
            await FirebaseProvider.firestore.collection('users').doc(uid).get();
        final data = userDoc.data();
        if (data != null) {
          userName = (data['displayName'] as String?)?.split(' ').first ??
              (data['name'] as String?)?.split(' ').first ??
              userName;
        }

        final postsSnap = await FirebaseProvider.firestore
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .limit(20)
            .get();
        activePostCount = postsSnap.size;
      } catch (e) {
        debugPrint('VoiceAssistant: error fetching user context: $e');
      }
    }

    final systemPrompt = _buildSystemPrompt(userName, activePostCount);
    _gemini.initVoiceAssistant(tools: _tools, systemPrompt: systemPrompt);

    // Quick health check — test the API key with a trivial call
    try {
      final test = await _gemini.generateContent('Reply with OK');
      debugPrint('VoiceAssistant: API health check ${test != null ? "PASSED" : "FAILED (null)"}');
    } catch (e) {
      debugPrint('VoiceAssistant: API health check FAILED: $e');
    }
  }

  static String _buildSystemPrompt(String userName, int activePostCount) {
    return '''You are Supra, a smart and friendly AI voice assistant inside the SingleTap app.
You are speaking with $userName, who currently has $activePostCount active post${activePostCount == 1 ? '' : 's'}.

ABOUT SINGLETAP:
SingleTap is an AI-powered matching app where users post what they need or offer, and the app semantically matches them with other users who have complementary intentions.

VOICE OUTPUT RULES — CRITICAL:
- Respond in plain natural speech only. NO markdown, NO bullet points, NO asterisks, NO hashtags, NO bold/italic formatting.
- Keep answers to 1-3 sentences for simple questions; max 5 sentences for complex ones.
- Never start with "Sure!", "Certainly!", or "Of course!" — be direct and natural.
- After a findMatchesForMe result, describe the top 1-2 matches by name and their intent in plain speech.
- Numbers and percentages: say them naturally ("eighty-three percent", "about 2 kilometers away").

FUNCTION CALLING RULES:
- Answer general questions (science, history, math, jokes, weather, facts, coding) DIRECTLY from your knowledge. Do NOT call any function.
- IMPORTANT: When the user mentions wanting, needing, looking for, offering, selling, or searching for ANY product, service, skill, or person — ALWAYS call searchByEmbedding. This is the core purpose of SingleTap.
- Examples that MUST trigger searchByEmbedding: "I want water bottle", "I need a plumber", "looking for teacher", "find me a chef", "I am looking for someone who can fix my phone", "water bottle", "plumber nearby".
- "find matches for me" / "who matches me" / "show my matches" → call findMatchesForMe.
- "create a post" / "post that I need..." / "add a listing" → call createPost.
- "go to messages" / "open my profile" / "take me to discover" → call navigateTo.
- "who am I chatting with" / "show my chats" → call getRecentConversations.
- After any function result, always respond in plain natural speech describing what was found.
- If a search returns no results, say so clearly and suggest the user create a post to attract matches.

MATCHING EXPLANATION:
When explaining match results, always mention: the person's name, what they're seeking or offering, and the match percentage. Example: "Your top match is Alex, who is offering piano lessons, with an 87 percent match score."

INTENT RULES:
- seeking + offering = complementary and high-value match.
- Same intent type (seeking + seeking) = low match for direct interaction.
- Always consider what the user is looking for and what the other post provides.''';
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (_state != VoiceAssistantState.idle) return;

    _partialTranscript = '';
    _errorHint = '';
    _processingHint = '';
    _sttRestartCount = 0;
    _gotFinalResult = false;
    _state = VoiceAssistantState.listening;
    notifyListeners();

    if (!_sttInitialized) {
      _state = VoiceAssistantState.idle;
      notifyListeners();
      return;
    }

    _startSttSession();
  }

  Future<void> _startSttSession() async {
    await _stt.listen(
      onResult: (result) {
        _partialTranscript = result.recognizedWords;
        notifyListeners();
        _resetSilenceTimer();
        if (result.finalResult && _partialTranscript.isNotEmpty) {
          _gotFinalResult = true;
          _silenceTimer?.cancel();
          _processUserTurn(_partialTranscript);
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 15), () {
      if (_state == VoiceAssistantState.listening && !_isProcessingTurn) {
        if (_partialTranscript.isNotEmpty) {
          _processUserTurn(_partialTranscript);
        } else {
          _state = VoiceAssistantState.idle;
          notifyListeners();
        }
      }
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (_state == VoiceAssistantState.listening && !_isProcessingTurn) {
        if (_partialTranscript.isNotEmpty) {
          _processUserTurn(_partialTranscript);
        } else {
          _state = VoiceAssistantState.idle;
          notifyListeners();
        }
      }
    });
  }

  void _attemptSttRestart() {
    if (_sttRestartCount >= _maxSttRestarts || _isProcessingTurn) {
      _silenceTimer?.cancel();
      if (_partialTranscript.isNotEmpty) {
        _processUserTurn(_partialTranscript);
      } else {
        _state = VoiceAssistantState.idle;
        _errorHint = 'Connection issue. Try again or type below.';
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () {
          if (_errorHint.isNotEmpty) {
            _errorHint = '';
            notifyListeners();
          }
        });
      }
      return;
    }
    _sttRestartCount++;
    debugPrint('VoiceAssistant: STT restart $_sttRestartCount/$_maxSttRestarts');
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_state != VoiceAssistantState.listening || _isProcessingTurn) return;
      _startSttSession();
    });
  }

  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    await _stt.stop();
    if (_state == VoiceAssistantState.listening) {
      if (_partialTranscript.isNotEmpty) {
        _processUserTurn(_partialTranscript);
      } else {
        _state = VoiceAssistantState.idle;
        notifyListeners();
      }
    }
  }

  /// Called when user taps the orb while speaking — stops TTS immediately.
  Future<void> interruptSpeaking() async {
    if (_state != VoiceAssistantState.speaking) return;
    _speakingTimeout?.cancel();
    await _tts.stop();
    _state = VoiceAssistantState.idle;
    notifyListeners();
  }

  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state != VoiceAssistantState.idle) return;
    _errorHint = '';
    _processUserTurn(trimmed);
  }

  // ── Core turn processing ───────────────────────────────────────────────────

  Future<void> _processUserTurn(String text) async {
    if (_isProcessingTurn) return;
    _isProcessingTurn = true;
    _silenceTimer?.cancel();
    await _stt.stop();

    _messages.add(VoiceMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _state = VoiceAssistantState.processing;
    _partialTranscript = '';
    _lastResults = [];
    _processingHint = 'Thinking...';
    notifyListeners();

    String rawResponse;
    try {
      var reply = await _gemini.sendVoiceMessage(
        userMessage: text,
        history: List.from(_history),
        functionHandler: _handleFunctionCall,
        onHint: (hint) {
          _processingHint = hint;
          notifyListeners();
        },
      );

      // If Gemini chat returned nothing, run a direct semantic search fallback
      if (reply == null && _lastResults.isEmpty) {
        _processingHint = 'Searching directly...';
        notifyListeners();
        try {
          final directResults = await _handleFunctionCall(
            'searchByEmbedding',
            {'text': text},
          );
          final count = directResults['count'] as int? ?? 0;
          if (count > 0) {
            reply = 'I found $count result${count == 1 ? '' : 's'} '
                'for "$text". Take a look at the cards below.';
          } else {
            reply =
                'I searched for "$text" but no matching posts were found yet. '
                'Try creating a post on the home screen to attract matches.';
          }
        } catch (e) {
          debugPrint('Direct search fallback failed: $e');
        }
      }

      rawResponse = reply ??
          'I heard you say "$text". '
              'Let me search for that — try again in a moment or use the home screen.';
    } catch (e) {
      debugPrint('_processUserTurn error: $e');
      rawResponse =
          'Something went wrong while processing your request. Please try again.';
    }

    // Strip markdown so TTS sounds natural
    final spokenText = GeminiService.stripMarkdownForSpeech(rawResponse);

    _appendHistory(Content.text(text));
    _appendHistory(Content.model([TextPart(rawResponse)]));

    _messages.add(VoiceMessage(
      text: rawResponse,
      isUser: false,
      timestamp: DateTime.now(),
      results: _lastResults.isEmpty ? null : List.from(_lastResults),
    ));

    _processingHint = '';
    _state = VoiceAssistantState.speaking;
    _isProcessingTurn = false;
    notifyListeners();

    // Safety timeout — if TTS hangs, reset to idle
    _speakingTimeout?.cancel();
    final estimatedSeconds = (spokenText.length / 5).clamp(5, 60).toInt();
    _speakingTimeout = Timer(Duration(seconds: estimatedSeconds), () {
      if (_state == VoiceAssistantState.speaking) {
        debugPrint('TTS safety timeout — resetting to idle');
        _state = VoiceAssistantState.idle;
        notifyListeners();
      }
    });

    try {
      await _tts.speak(spokenText);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _speakingTimeout?.cancel();
      _state = VoiceAssistantState.idle;
      notifyListeners();
    }
  }

  // ── Function handlers ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleFunctionCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    final uid = FirebaseProvider.currentUserId;
    final fs = FirebaseProvider.firestore;

    switch (name) {
      // ── searchPosts ────────────────────────────────────────────────────────
      case 'searchPosts':
        final query = (args['query'] as String? ?? '').trim();
        if (query.isEmpty) return {'results': [], 'count': 0};
        // Delegate to searchByEmbedding for consistent smart matching
        return _handleFunctionCall('searchByEmbedding', {'text': query});

      // ── getMyPosts ─────────────────────────────────────────────────────────
      case 'getMyPosts':
        if (uid == null) return {'error': 'Not authenticated'};
        final snap = await fs
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .limit(20)
            .get();
        final results = snap.docs
            .map((d) => _cleanPostData(d.data(), id: d.id))
            .toList();
        _lastResults = results;
        notifyListeners();
        return {'posts': results, 'count': results.length};

      // ── getMatches ────────────────────────────────────────────────────────
      case 'getMatches':
        final postId = args['postId'] as String? ?? '';
        if (postId.isEmpty) return {'error': 'postId required'};
        try {
          final matches = await UnifiedPostService().findMatches(postId);
          final results = matches.map((m) => <String, dynamic>{
            'id': m.id,
            'score': m.similarityScore ?? 0.0,
            'title': m.title,
            'description': m.description,
            'userId': m.userId,
            'userName': m.userName,
            'location': m.location,
          }).toList();
          _lastResults = results;
          notifyListeners();
          return {'matches': results, 'count': results.length};
        } catch (e) {
          return {'error': 'Failed to find matches: $e'};
        }

      // ── getUserProfile ────────────────────────────────────────────────────
      case 'getUserProfile':
        if (uid == null) return {'error': 'Not authenticated'};
        final doc = await fs.collection('users').doc(uid).get();
        return doc.data() ?? {'error': 'Profile not found'};

      // ── searchByEmbedding ─────────────────────────────────────────────────
      case 'searchByEmbedding':
        final text = args['text'] as String? ?? '';
        if (text.isEmpty) return {'error': 'text required'};

        // Generate complementary search terms (mirrors UnifiedPostService)
        // so "looking for plumber" → "plumber available, plumbing services..."
        final searchText = await _buildSmartSearchText(text);
        debugPrint('Voice searchByEmbedding: "$text" → search="$searchText"');

        final queryEmb = await _gemini.generateEmbedding(searchText);
        final snap = await fs
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(ApiConfig.matchQueryLimit)
            .get();

        debugPrint('Voice search: ${snap.docs.length} active posts to scan');
        final embScored = <Map<String, dynamic>>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (data['userId'] == uid) continue; // skip own posts
          final emb = List<double>.from(data['embedding'] ?? []);
          if (emb.isEmpty) continue;
          final sim = _gemini.calculateSimilarity(queryEmb, emb);
          if (sim >= ApiConfig.matchPreFilterThreshold) {
            debugPrint('  "${data['title']}" sim=${sim.toStringAsFixed(3)}');
          }
          if (sim >= ApiConfig.matchFinalThreshold) {
            embScored.add(_cleanPostData(data, id: d.id, score: sim));
          }
        }
        embScored.sort((a, b) =>
            (b['score'] as double).compareTo(a['score'] as double));
        final top = embScored.take(ApiConfig.matchMaxResults).toList();
        debugPrint('Voice search: ${top.length} results above threshold');
        _lastResults = top;
        notifyListeners();
        return {'results': top, 'count': top.length};

      // ── searchNearby ──────────────────────────────────────────────────────
      case 'searchNearby':
        if (uid == null) return {'error': 'Not authenticated'};
        final text = args['text'] as String? ?? '';
        if (text.isEmpty) return {'error': 'text required'};
        final radiusKm = (args['radiusKm'] as num?)?.toDouble() ?? 25.0;

        final userDoc = await fs.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final userLat = userData?['latitude'] as double?;
        final userLng = userData?['longitude'] as double?;
        if (userLat == null || userLng == null) {
          return {'error': 'Your location is not available. Please enable location services.'};
        }

        final queryEmb = await _gemini.generateEmbedding(text);
        final snap = await fs
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(ApiConfig.matchQueryLimit)
            .get();

        final nearbyScored = <Map<String, dynamic>>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (data['userId'] == uid) continue;
          final postLat = (data['latitude'] as num?)?.toDouble();
          final postLng = (data['longitude'] as num?)?.toDouble();
          if (postLat == null || postLng == null) continue;

          final distKm = _haversineKm(userLat, userLng, postLat, postLng);
          if (distKm > radiusKm) continue;

          final emb = List<double>.from(data['embedding'] ?? []);
          final cosineSim = emb.isEmpty
              ? 0.0
              : _gemini.calculateSimilarity(queryEmb, emb);
          final proxScore = 1.0 - (distKm / radiusKm).clamp(0.0, 1.0);
          final combined = 0.7 * cosineSim + 0.3 * proxScore;

          nearbyScored.add(_cleanPostData(
            data,
            id: d.id,
            score: combined,
            distanceKm: double.parse(distKm.toStringAsFixed(1)),
          ));
        }
        nearbyScored.sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final nearbyTop = nearbyScored.take(10).toList();
        _lastResults = nearbyTop;
        notifyListeners();
        return {'results': nearbyTop, 'count': nearbyTop.length};

      // ── findMatchesForMe ──────────────────────────────────────────────────
      case 'findMatchesForMe':
        if (uid == null) return {'error': 'Not authenticated'};

        final myPostsSnap = await fs
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .limit(10)
            .get();
        if (myPostsSnap.docs.isEmpty) {
          return {'error': 'You have no active posts. Create a post first to find matches.'};
        }

        // Delegate to UnifiedPostService for each post, then merge & dedup
        final bestByUser = <String, Map<String, dynamic>>{};
        final postService = UnifiedPostService();

        for (final myPostDoc in myPostsSnap.docs) {
          try {
            final matches = await postService.findMatches(myPostDoc.id);
            for (final match in matches) {
              final otherUserId = match.userId;
              final score = match.similarityScore ?? 0.0;
              final existing = bestByUser[otherUserId];
              if (existing == null ||
                  (existing['score'] as double) < score) {
                bestByUser[otherUserId] = {
                  'id': match.id,
                  'score': score,
                  'title': match.title,
                  'description': match.description,
                  'userId': match.userId,
                  'userName': match.userName,
                  'userPhoto': match.userPhoto,
                  'location': match.location,
                  'latitude': match.latitude,
                  'longitude': match.longitude,
                };
              }
            }
          } catch (e) {
            debugPrint('findMatchesForMe: error for post ${myPostDoc.id}: $e');
          }
        }

        final matchList = bestByUser.values.toList()
          ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final matchTop = matchList.take(10).toList();
        _lastResults = matchTop.cast<Map<String, dynamic>>();
        notifyListeners();
        return {'matches': matchTop, 'count': matchTop.length};

      // ── createPost ────────────────────────────────────────────────────────
      case 'createPost':
        if (uid == null) return {'error': 'Not authenticated'};
        final prompt = (args['prompt'] as String? ?? '').trim();
        if (prompt.isEmpty) return {'error': 'prompt is required'};

        try {
          final userDoc = await fs.collection('users').doc(uid).get();
          final userData = userDoc.data();
          final result = await UnifiedPostService().createPost(
            originalPrompt: prompt,
            latitude: (userData?['latitude'] as num?)?.toDouble(),
            longitude: (userData?['longitude'] as num?)?.toDouble(),
            location: userData?['location'] as String?,
          );
          if (result['success'] == true) {
            return {
              'success': true,
              'message': 'Post created successfully',
              'postId': result['postId'] ?? '',
            };
          }
          return {
            'error': result['message'] ?? 'Failed to create post',
          };
        } catch (e) {
          debugPrint('createPost error: $e');
          return {'error': 'Could not create post: $e'};
        }

      // ── navigateTo ────────────────────────────────────────────────────────
      case 'navigateTo':
        final screen = (args['screen'] as String? ?? '').toLowerCase().trim();
        if (screen.isEmpty) return {'error': 'screen name required'};
        // Delay slightly so the spoken response plays first
        Future.delayed(const Duration(milliseconds: 800), () {
          onNavigate?.call(screen);
        });
        return {'navigating': true, 'screen': screen};

      // ── getRecentConversations ─────────────────────────────────────────────
      case 'getRecentConversations':
        if (uid == null) return {'error': 'Not authenticated'};
        final snap = await fs
            .collection('conversations')
            .where('participants', arrayContains: uid)
            .orderBy('lastMessageTime', descending: true)
            .limit(10)
            .get();
        final convos = snap.docs.map((d) {
          final data = d.data();
          final participants = List<String>.from(data['participants'] ?? []);
          final otherId = participants.firstWhere(
            (p) => p != uid,
            orElse: () => '',
          );
          return {
            'conversationId': d.id,
            'otherUserId': otherId,
            'lastMessage': data['lastMessage'] ?? '',
            'lastMessageTime': data['lastMessageTime']?.toString() ?? '',
          };
        }).toList();
        return {'conversations': convos, 'count': convos.length};

      default:
        return {'error': 'Unknown function: $name'};
    }
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  /// Generate complementary search text for a voice query.
  /// Mirrors what UnifiedPostService does with complementary_intents:
  /// "looking for plumber" → "plumber available, plumbing services, pipe repair"
  /// This dramatically improves match quality vs raw query embedding.
  Future<String> _buildSmartSearchText(String query) async {
    try {
      final result = await _gemini.generateContent(
        'User is searching for: "$query"\n'
        'Generate a short complementary search phrase (max 20 words) that describes '
        'posts matching this search. If seeking, describe who offers it. '
        'If offering, describe who needs it.\n'
        'Return ONLY the phrase, no explanation.\n'
        'Examples:\n'
        '"looking for plumber" → "plumber available plumbing services pipe repair"\n'
        '"I am chef" → "need chef looking for cook hiring cooking services"\n'
        '"water bottle" → "selling water bottle bottle for sale hydration"',
      );
      if (result != null && result.trim().isNotEmpty) {
        // Combine complementary terms with original query for best embedding
        return '${result.trim()} $query';
      }
    } catch (e) {
      debugPrint('Smart search text generation failed: $e');
    }
    return query;
  }

  /// Strip heavy fields (embedding, intentAnalysis, metadata) so Gemini
  /// gets a small, clean payload and UI result cards have all needed fields.
  static Map<String, dynamic> _cleanPostData(
    Map<String, dynamic> raw, {
    String? id,
    double? score,
    double? distanceKm,
  }) {
    return {
      if (id != null) 'id': id,
      'title': raw['title'] ?? '',
      'description': raw['description'] ?? '',
      'userId': raw['userId'] ?? '',
      'userName': raw['userName'] ?? '',
      'userPhoto': raw['userPhoto'] ?? '',
      'location': raw['location'] ?? '',
      if (raw['price'] != null) 'price': raw['price'],
      if (raw['currency'] != null) 'currency': raw['currency'],
      if (raw['latitude'] != null) 'latitude': raw['latitude'],
      if (raw['longitude'] != null) 'longitude': raw['longitude'],
      if (score != null) 'score': score,
      if (distanceKm != null) 'distanceKm': distanceKm,
    };
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);

  void _appendHistory(Content content) {
    _history.add(content);
    while (_history.length > _maxHistoryItems) {
      _history.removeAt(0);
    }
  }

  void clearConversation() {
    _messages.clear();
    _history.clear();
    _lastResults = [];
    _partialTranscript = '';
    _processingHint = '';
    _errorHint = '';
    _state = VoiceAssistantState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speakingTimeout?.cancel();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}
