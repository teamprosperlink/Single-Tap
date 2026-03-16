import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../res/utils/api_error_handler.dart';
import '../../res/config/api_config.dart';

/// Direct Gemini REST API service — no SDK dependency.
/// Works like WhatsApp Meta AI: direct HTTP calls to generativelanguage.googleapis.com
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  // Public static getter for API key (backward compatibility)
  static String get apiKey => ApiConfig.geminiApiKey;

  // Embedding cache
  final Map<String, _CachedEmbedding> _embeddingCache = {};
  static const _embeddingCacheDuration = Duration(hours: 24);
  static const _maxCacheEntries = 200;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  GeminiService._internal();

  /// Build API URL for a model and action
  Uri _apiUrl(String model, String action) {
    return Uri.parse('$_baseUrl/models/$model:$action?key=${ApiConfig.geminiApiKey}');
  }

  // ─── TEXT GENERATION ───

  Future<String?> generateContent(String prompt) async {
    debugPrint('Gemini: Direct REST API, model=${ApiConfig.geminiFlashModel}, key=${_maskedKey()}');
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final url = _apiUrl(ApiConfig.geminiFlashModel, 'generateContent');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': ApiConfig.temperature,
              'topK': ApiConfig.topK,
              'topP': ApiConfig.topP,
              'maxOutputTokens': ApiConfig.maxOutputTokens,
            },
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return text;
          }
        } else {
          final errorBody = response.body;
          debugPrint('Error generating content (attempt ${attempt + 1}/3): ${response.statusCode} $errorBody');

          // Check for quota/rate/auth errors — don't retry
          if (response.statusCode == 429 || errorBody.contains('RESOURCE_EXHAUSTED')) {
            debugPrint('API quota exceeded — skipping retries.');
            return null;
          }
          if (response.statusCode == 403 || response.statusCode == 401) {
            debugPrint('API auth error — skipping retries.');
            return null;
          }
        }
      } catch (e) {
        debugPrint('Error generating content (attempt ${attempt + 1}/3): $e');
      }

      if (attempt < 2) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    return null;
  }

  // ─── IMAGE ANALYSIS ───

  Future<String> analyzeImage({
    required String base64Image,
    required String mimeType,
    required String prompt,
  }) async {
    try {
      debugPrint('GeminiService.analyzeImage: Starting...');

      final url = _apiUrl(ApiConfig.geminiFlashModel, 'generateContent');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        return text ?? 'Could not analyze image';
      } else {
        debugPrint('GeminiService.analyzeImage: Error ${response.statusCode}');
        return 'Error analyzing image: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      debugPrint('GeminiService.analyzeImage: Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'Error analyzing image: $e';
    }
  }

  // ─── EMBEDDINGS ───

  Future<List<double>> generateEmbedding(String text) async {
    final cacheKey = text.trim().toLowerCase();

    // Check cache first
    final cached = _embeddingCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _embeddingCacheDuration) {
      return cached.embedding;
    }

    final result = await ApiErrorHandler.handleApiCall(
          () async {
            return await _callEmbeddingApi(text);
          },
          fallback: () => _generateFallbackEmbedding(text),
          onError: (errorType) {
            if (errorType == ApiErrorType.quotaExceeded) {
              debugPrint('Gemini API quota exceeded. Using fallback embedding.');
            }
          },
        ) ??
        _generateFallbackEmbedding(text);

    // Cache the result
    if (_embeddingCache.length >= _maxCacheEntries) {
      final oldestKey = _embeddingCache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _embeddingCache.remove(oldestKey);
    }
    _embeddingCache[cacheKey] = _CachedEmbedding(result, DateTime.now());

    return result;
  }

  Future<List<double>> _callEmbeddingApi(String text) async {
    final url = _apiUrl(ApiConfig.geminiEmbeddingModel, 'embedContent');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'models/${ApiConfig.geminiEmbeddingModel}',
        'content': {
          'parts': [
            {'text': text}
          ]
        },
        'outputDimensionality': ApiConfig.embeddingDimension,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final values = data['embedding']['values'] as List;
      return values.map<double>((v) => (v as num).toDouble()).toList();
    } else {
      debugPrint('Embedding API error: ${response.statusCode} ${response.body}');
      throw Exception('Embedding API failed: ${response.statusCode}');
    }
  }

  /// Returns zero vector so cosine similarity correctly reports 0.0
  /// instead of random false-positive scores when API is unavailable.
  List<double> _generateFallbackEmbedding(String text) {
    return List.filled(768, 0.0);
  }

  // ─── SIMILARITY ───

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  // ─── KEYWORDS ───

  Future<List<String>> extractKeywords(String text) async {
    return await ApiErrorHandler.handleApiCall(() async {
          final prompt = '''
Extract the most important keywords from this text for matching purposes.
Return only a comma-separated list of keywords, nothing else.
Text: "$text"
''';
          final result = await generateContent(prompt);
          if (result != null) {
            return result
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

          final prompt = '''
Enhance this search query for better semantic matching $domainContext.
Original query: "$query"
Return only the enhanced query text, nothing else.
''';
          final result = await generateContent(prompt);
          if (result != null && result.isNotEmpty) return result;
          return query;
        }, fallback: () => query) ??
        query;
  }

  // ─── HELPERS ───

  String _maskedKey() {
    final key = ApiConfig.geminiApiKey;
    if (key.length > 8) {
      return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
    }
    return key.isEmpty ? 'EMPTY' : 'SHORT';
  }
}

class _CachedEmbedding {
  final List<double> embedding;
  final DateTime cachedAt;
  _CachedEmbedding(this.embedding, this.cachedAt);
}
