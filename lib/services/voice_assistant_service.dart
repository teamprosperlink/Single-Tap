import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_provider.dart';
import 'location services/gemini_service.dart';

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

  final _gemini = GeminiService();
  final _stt = stt.SpeechToText();
  final _tts = FlutterTts();

  final List<Content> _history = [];
  static const _maxHistoryItems = 40;

  bool _sttInitialized = false;
  Timer? _silenceTimer;
  Timer? _speakingTimeout;

  String _errorHint = '';

  VoiceAssistantState get state => _state;
  String get partialTranscript => _partialTranscript;
  List<VoiceMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get lastResults => _lastResults;
  String get errorHint => _errorHint;

  // Gemini function declarations
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
        Schema.object(properties: {}),
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
        Schema.object(properties: {}),
      ),
      FunctionDeclaration(
        'searchByEmbedding',
        'Find posts semantically similar to a natural language query using AI embeddings.',
        Schema.object(properties: {
          'text': Schema.string(description: 'Natural language search query'),
        }),
      ),
    ]),
  ];

  bool _isProcessingTurn = false;

  Future<void> initialize() async {
    if (_sttInitialized) return;

    _sttInitialized = await _stt.initialize(
      onStatus: (status) {
        debugPrint('VoiceAssistant STT status: $status');
        if ((status == 'done' || status == 'notListening') &&
            _state == VoiceAssistantState.listening &&
            !_isProcessingTurn) {
          _silenceTimer?.cancel();
          if (_partialTranscript.isNotEmpty) {
            _processUserTurn(_partialTranscript);
          } else {
            _state = VoiceAssistantState.idle;
            notifyListeners();
          }
        }
      },
      onError: (error) {
        debugPrint('VoiceAssistant STT error: $error');
        if (_state == VoiceAssistantState.listening && !_isProcessingTurn) {
          _silenceTimer?.cancel();
          final errorMsg = error.errorMsg;
          if (errorMsg == 'error_no_match' || errorMsg == 'error_speech_timeout') {
            // No speech detected — return to idle with hint
            _state = VoiceAssistantState.idle;
            _partialTranscript = '';
            _errorHint = "Didn't catch that. Try again or type below.";
            notifyListeners();
            // Clear hint after 3 seconds
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
        }
      },
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);

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

    // Add greeting message
    _messages.add(VoiceMessage(
      text: "Hi! I'm your SingleTap assistant. Ask me anything — general knowledge, search posts, check your profile, or find matches. You can speak or type below.",
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// Send a typed text message (fallback when STT doesn't work)
  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state != VoiceAssistantState.idle) return;
    _errorHint = '';
    _processUserTurn(trimmed);
  }

  Future<void> startListening() async {
    if (_state != VoiceAssistantState.idle) return;

    _partialTranscript = '';
    _errorHint = '';
    _state = VoiceAssistantState.listening;
    notifyListeners();

    if (!_sttInitialized) {
      _state = VoiceAssistantState.idle;
      notifyListeners();
      return;
    }

    await _stt.listen(
      onResult: (result) {
        _partialTranscript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult && _partialTranscript.isNotEmpty) {
          _processUserTurn(_partialTranscript);
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

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 8), () {
      if (_state == VoiceAssistantState.listening) {
        if (_partialTranscript.isNotEmpty) {
          _processUserTurn(_partialTranscript);
        } else {
          _state = VoiceAssistantState.idle;
          notifyListeners();
        }
      }
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
    notifyListeners();

    final reply = await _gemini.sendWithFunctionCalling(
      userMessage: text,
      history: List.from(_history),
      tools: _tools,
      functionHandler: _handleFunctionCall,
    );

    final responseText = reply ?? 'Sorry, I could not process that request.';

    _appendHistory(Content.text(text));
    _appendHistory(Content.model([TextPart(responseText)]));

    _messages.add(VoiceMessage(
      text: responseText,
      isUser: false,
      timestamp: DateTime.now(),
      results: _lastResults.isEmpty ? null : List.from(_lastResults),
    ));

    _state = VoiceAssistantState.speaking;
    _isProcessingTurn = false;
    notifyListeners();

    // Safety timeout: if TTS doesn't complete/error within reasonable time, reset to idle
    _speakingTimeout?.cancel();
    final estimatedSeconds = (responseText.length / 10).clamp(3, 30).toInt();
    _speakingTimeout = Timer(Duration(seconds: estimatedSeconds), () {
      if (_state == VoiceAssistantState.speaking) {
        debugPrint('TTS safety timeout - resetting to idle');
        _state = VoiceAssistantState.idle;
        notifyListeners();
      }
    });

    try {
      await _tts.speak(responseText);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _speakingTimeout?.cancel();
      _state = VoiceAssistantState.idle;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _handleFunctionCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    final uid = FirebaseProvider.currentUserId;
    final fs = FirebaseProvider.firestore;

    switch (name) {
      case 'searchPosts':
        final query = (args['query'] as String? ?? '').toLowerCase();
        final keywords = query.split(' ').where((w) => w.length > 2).toList();
        if (keywords.isEmpty) {
          return {'posts': [], 'count': 0};
        }
        final snap = await fs
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(20)
            .get();
        final results = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((p) {
              final title = (p['title'] as String? ?? '').toLowerCase();
              final desc = (p['description'] as String? ?? '').toLowerCase();
              final kws = (p['keywords'] as List<dynamic>?)
                      ?.map((k) => k.toString().toLowerCase())
                      .toList() ??
                  [];
              return keywords.any((k) =>
                  title.contains(k) ||
                  desc.contains(k) ||
                  kws.any((kw) => kw.contains(k)));
            })
            .take(10)
            .toList();
        _lastResults = results.cast<Map<String, dynamic>>();
        notifyListeners();
        return {'posts': results, 'count': results.length};

      case 'getMyPosts':
        if (uid == null) return {'error': 'Not authenticated'};
        final snap = await fs
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .limit(20)
            .get();
        final results =
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _lastResults = results.cast<Map<String, dynamic>>();
        notifyListeners();
        return {'posts': results, 'count': results.length};

      case 'getMatches':
        final postId = args['postId'] as String? ?? '';
        if (postId.isEmpty) return {'error': 'postId required'};
        final postDoc = await fs.collection('posts').doc(postId).get();
        if (!postDoc.exists) return {'error': 'Post not found'};
        final embedding =
            List<double>.from(postDoc.data()?['embedding'] ?? []);
        if (embedding.isEmpty) return {'matches': [], 'count': 0};
        final allSnap = await fs
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(50)
            .get();
        final scored = allSnap.docs
            .where((d) => d.id != postId)
            .map((d) {
              final other = List<double>.from(d.data()['embedding'] ?? []);
              final sim = other.isEmpty
                  ? 0.0
                  : _gemini.calculateSimilarity(embedding, other);
              return {'id': d.id, 'score': sim, ...d.data()};
            })
            .where((m) => (m['score'] as double) >= 0.6)
            .toList()
          ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final top = scored.take(10).toList();
        _lastResults = top.cast<Map<String, dynamic>>();
        notifyListeners();
        return {'matches': top, 'count': top.length};

      case 'getUserProfile':
        if (uid == null) return {'error': 'Not authenticated'};
        final doc = await fs.collection('users').doc(uid).get();
        return doc.data() ?? {'error': 'Profile not found'};

      case 'searchByEmbedding':
        final text = args['text'] as String? ?? '';
        if (text.isEmpty) return {'error': 'text required'};
        final queryEmb = await _gemini.generateEmbedding(text);
        final snap = await fs
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .limit(50)
            .get();
        final scored = snap.docs
            .map((d) {
              final emb = List<double>.from(d.data()['embedding'] ?? []);
              final sim = emb.isEmpty
                  ? 0.0
                  : _gemini.calculateSimilarity(queryEmb, emb);
              return {'id': d.id, 'score': sim, ...d.data()};
            })
            .where((m) => (m['score'] as double) >= 0.6)
            .toList()
          ..sort(
              (a, b) => (b['score'] as double).compareTo(a['score'] as double));
        final top = scored.take(10).toList();
        _lastResults = top.cast<Map<String, dynamic>>();
        notifyListeners();
        return {'results': top, 'count': top.length};

      default:
        return {'error': 'Unknown function: $name'};
    }
  }

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
