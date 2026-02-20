import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import '../../res/utils/api_error_handler.dart';
import '../../res/config/api_config.dart';

class GeminiService {
  late final GenerativeModel _model;
  late final GenerativeModel _embeddingModel;

  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  // Public static getter for API key (backward compatibility)
  static String get apiKey => ApiConfig.geminiApiKey;

  GeminiService._internal() {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
    );

    _embeddingModel = GenerativeModel(
      model: ApiConfig.geminiEmbeddingModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  Future<List<double>> generateEmbedding(String text) async {
    return await ApiErrorHandler.handleApiCall(
          () async {
            final content = Content.text(text);
            final response = await _embeddingModel.embedContent(content);
            return response.embedding.values;
          },
          fallback: () => _generateFallbackEmbedding(text),
          onError: (errorType) {
            if (errorType == ApiErrorType.quotaExceeded) {
              debugPrint(
                ' Gemini API quota exceeded. Using fallback embedding.',
              );
            }
          },
        ) ??
        _generateFallbackEmbedding(text);
  }

  List<double> _generateFallbackEmbedding(String text) {
    final random = Random(text.hashCode);
    return List.generate(768, (_) => random.nextDouble() * 2 - 1);
  }

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  Future<String?> generateContent(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text;
    } catch (e) {
      debugPrint('Error generating content: $e');
      return null;
    }
  }

  /// Analyze an image using Gemini Vision
  Future<String> analyzeImage({
    required String base64Image,
    required String mimeType,
    required String prompt,
  }) async {
    try {
      debugPrint('🖼️ GeminiService.analyzeImage: Starting...');
      debugPrint('🖼️ GeminiService.analyzeImage: MIME type: $mimeType');
      debugPrint(
        '🖼️ GeminiService.analyzeImage: Base64 length: ${base64Image.length}',
      );

      // Create vision model for image analysis
      final visionModel = GenerativeModel(
        model: ApiConfig.geminiFlashModel,
        apiKey: ApiConfig.geminiApiKey,
      );

      // Decode base64 to bytes
      final imageBytes = base64Decode(base64Image);
      debugPrint(
        '🖼️ GeminiService.analyzeImage: Image bytes: ${imageBytes.length}',
      );

      // Create content with image
      final content = [
        Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
      ];

      debugPrint('🖼️ GeminiService.analyzeImage: Sending to Gemini...');
      final response = await visionModel.generateContent(content);
      debugPrint('🖼️ GeminiService.analyzeImage: Got response');

      final resultText = response.text ?? 'Could not analyze image';
      debugPrint(
        '🖼️ GeminiService.analyzeImage: Response length: ${resultText.length}',
      );

      return resultText;
    } catch (e, stackTrace) {
      debugPrint('🖼️ GeminiService.analyzeImage: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'Error analyzing image: $e';
    }
  }

  Future<List<String>> extractKeywords(String text) async {
    return await ApiErrorHandler.handleApiCall(() async {
          final prompt =
              '''
        Extract the most important keywords from this text for matching purposes.
        Return only a comma-separated list of keywords, nothing else.
        Text: "$text"
        ''';

          final content = [Content.text(prompt)];
          final response = await _model.generateContent(content);

          if (response.text != null) {
            return response.text!
                .split(',')
                .map((keyword) => keyword.trim().toLowerCase())
                .where((keyword) => keyword.isNotEmpty)
                .toList();
          }
          return _getFallbackKeywords(text);
        }, fallback: () => _getFallbackKeywords(text)) ??
        _getFallbackKeywords(text);
  }

  List<String> _getFallbackKeywords(String text) {
    return text
        .toLowerCase()
        .split(' ')
        .where((word) => word.length > 3)
        .take(5)
        .toList();
  }

  // Enhanced search query (no hardcoded categories!)
  Future<String> enhanceSearchQuery(String query, {String? domain}) async {
    return await ApiErrorHandler.handleApiCall(() async {
          final domainContext = domain != null && domain.isNotEmpty
              ? 'in the $domain context'
              : '';

          final prompt =
              '''
        Enhance this search query for better semantic matching $domainContext.
        Original query: "$query"
        Return only the enhanced query text, nothing else.
        ''';

          final content = [Content.text(prompt)];
          final response = await _model.generateContent(content);

          if (response.text != null && response.text!.isNotEmpty) {
            return response.text!;
          }
          return query;
        }, fallback: () => query) ??
        query;
  }
  // ── Voice assistant cached model ──────────────────────────────────────────

  GenerativeModel? _voiceModel;

  /// Call once during VoiceAssistantService.initialize() with the user-context
  /// system prompt and the full tool set. Subsequent calls to [sendVoiceMessage]
  /// reuse the same model instance — no allocation overhead per turn.
  void initVoiceAssistant({
    required List<Tool> tools,
    required String systemPrompt,
  }) {
    _voiceModel = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
      tools: tools,
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig(
          mode: FunctionCallingMode.auto,
        ),
      ),
      systemInstruction: Content.system(systemPrompt),
    );
  }

  /// Send one voice-assistant turn. Handles the function-call loop up to
  /// [maxRounds] times. Retries once on transient errors, then falls back
  /// to plain generation.
  Future<String?> sendVoiceMessage({
    required String userMessage,
    required List<Content> history,
    required Future<Map<String, dynamic>> Function(
            String functionName, Map<String, dynamic> args)
        functionHandler,
    void Function(String hint)? onHint,
    int maxRounds = 3,
  }) async {
    final model = _voiceModel;
    if (model == null) {
      debugPrint('sendVoiceMessage: voice model not initialized');
      return _plainFallback(userMessage);
    }

    // Retry once on transient API errors (rate limit, network blip)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final chat = model.startChat(history: history);
        var response = await chat.sendMessage(Content.text(userMessage));

        for (int round = 0; round < maxRounds; round++) {
          final calls = response.functionCalls.toList();
          if (calls.isEmpty) break;

          debugPrint('Voice function call(s): ${calls.map((c) => c.name).join(', ')}');

          final responses = <FunctionResponse>[];
          for (final call in calls) {
            onHint?.call(_hintForFunction(call.name));
            final result = await functionHandler(call.name, call.args);
            responses.add(FunctionResponse(call.name, result));
          }

          response =
              await chat.sendMessage(Content.functionResponses(responses));
        }

        final text = response.text;
        if (text != null && text.isNotEmpty) return text;
      } catch (e, st) {
        debugPrint('sendVoiceMessage attempt ${attempt + 1} error: $e\n$st');
        if (attempt == 0) {
          onHint?.call('Retrying...');
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    return _plainFallback(userMessage);
  }

  Future<String> _plainFallback(String userMessage) async {
    try {
      debugPrint('Voice: falling back to plain generation');
      final prompt =
          'You are Supra, a friendly voice assistant inside the SingleTap app. '
          'Answer this concisely in 1-3 plain sentences with no markdown: "$userMessage"';
      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }
    } catch (e) {
      debugPrint('Plain fallback also failed: $e');
    }
    // Last resort: always return a helpful response, never null
    return 'I heard you say "$userMessage". '
        'My AI connection is slow right now, but you can try again in a moment '
        'or use the home screen to search and find matches.';
  }

  /// Human-readable hint shown in the UI while a function is executing.
  static String _hintForFunction(String name) {
    switch (name) {
      case 'searchPosts':
        return 'Searching posts...';
      case 'searchByEmbedding':
        return 'Finding semantic matches...';
      case 'searchNearby':
        return 'Searching nearby posts...';
      case 'getMyPosts':
        return 'Loading your posts...';
      case 'getMatches':
        return 'Finding post matches...';
      case 'getUserProfile':
        return 'Fetching your profile...';
      case 'findMatchesForMe':
        return 'Running your match algorithm...';
      case 'createPost':
        return 'Creating your post...';
      case 'navigateTo':
        return 'Navigating...';
      case 'getRecentConversations':
        return 'Loading conversations...';
      default:
        return 'Processing...';
    }
  }

  // ── Legacy method kept for any callers outside voice assistant ─────────────

  /// Sends a message to Gemini with function calling support.
  /// Handles the call/respond loop up to [maxRounds] times.
  /// Falls back to plain text generation if function calling fails.
  Future<String?> sendWithFunctionCalling({
    required String userMessage,
    required List<Content> history,
    required List<Tool> tools,
    required Future<Map<String, dynamic>> Function(
            String functionName, Map<String, dynamic> args)
        functionHandler,
    int maxRounds = 3,
  }) async {
    try {
      final model = GenerativeModel(
        model: ApiConfig.geminiFlashModel,
        apiKey: ApiConfig.geminiApiKey,
        tools: tools,
        toolConfig: ToolConfig(
          functionCallingConfig: FunctionCallingConfig(
            mode: FunctionCallingMode.auto,
          ),
        ),
        systemInstruction: Content.system(
          'You are a smart, friendly voice assistant inside the SingleTap app. '
          'You can answer ANY question — general knowledge, current affairs, science, math, history, tech, coding, weather, sports, entertainment, or anything else. '
          'IMPORTANT RULES:\n'
          '1. For general questions, answer DIRECTLY from your knowledge. DO NOT call any function.\n'
          '2. ONLY call functions for SingleTap app data: posts, matches, profile.\n'
          '3. Keep responses concise (2-3 sentences) since they will be spoken aloud.\n'
          '4. Be helpful, accurate, and natural. No markdown.',
        ),
      );
      final chat = model.startChat(history: history);
      var response = await chat.sendMessage(Content.text(userMessage));

      for (int round = 0; round < maxRounds; round++) {
        final calls = response.functionCalls.toList();
        if (calls.isEmpty) break;
        final responses = <FunctionResponse>[];
        for (final call in calls) {
          final result = await functionHandler(call.name, call.args);
          responses.add(FunctionResponse(call.name, result));
        }
        response = await chat.sendMessage(Content.functionResponses(responses));
      }

      final text = response.text;
      if (text != null && text.isNotEmpty) return text;
    } catch (e, stackTrace) {
      debugPrint('sendWithFunctionCalling error: $e\n$stackTrace');
    }

    try {
      final prompt =
          'You are a smart, friendly voice assistant inside the SingleTap app. '
          'Answer concisely (2-3 sentences, no markdown). '
          'The user said: "$userMessage"';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.isNotEmpty == true ? response.text : null;
    } catch (e) {
      debugPrint('Fallback generateContent also failed: $e');
      return null;
    }
  }

  // ── Markdown stripper for TTS ──────────────────────────────────────────────

  /// Strips markdown so the text sounds natural when spoken aloud.
  static String stripMarkdownForSpeech(String text) {
    var result = text;

    // Remove code blocks
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    result = result.replaceAll(RegExp(r'`[^`]+`'), '');

    // Remove headings (#, ##, ###)
    result = result.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Bold / italic: **text**, *text*, __text__, _text_
    result = result.replaceAll(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), r'$1');
    result = result.replaceAll(RegExp(r'_{1,2}([^_]+)_{1,2}'), r'$1');

    // Remove bullet list markers (-, *, +) and numbered list markers
    result = result.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // Remove markdown links [text](url) → text
    result = result.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');

    // Remove inline images
    result = result.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');

    // Remove horizontal rules
    result = result.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');

    // Remove blockquote markers
    result = result.replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '');

    // Collapse multiple blank lines to a single space / period pause
    result = result.replaceAll(RegExp(r'\n{2,}'), '. ');
    result = result.replaceAll('\n', ' ');

    // Collapse multiple spaces
    result = result.replaceAll(RegExp(r' {2,}'), ' ');

    return result.trim();
  }
}
