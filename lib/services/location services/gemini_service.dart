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
        model: 'gemini-1.5-flash',
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
}

// No more hardcoded categories in Gemini service!
