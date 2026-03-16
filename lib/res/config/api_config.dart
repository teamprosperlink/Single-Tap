import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration
/// This file contains all API keys and configurations used throughout the app
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// API key for AI Chat (@Single Tap AI feature)
  static String get geminiChatApiKey =>
      dotenv.env['GEMINI_CHAT_API_KEY'] ?? '';

  /// All available chat API keys for rotation when quota is exhausted.
  /// Add GEMINI_CHAT_API_KEY_2, _3, etc. in .env for backup keys.
  static List<String> get allChatApiKeys {
    final keys = <String>[];
    // Primary chat key
    final primary = dotenv.env['GEMINI_CHAT_API_KEY'] ?? '';
    if (primary.isNotEmpty) keys.add(primary);
    // Numbered backup keys
    for (int i = 2; i <= 5; i++) {
      final key = dotenv.env['GEMINI_CHAT_API_KEY_$i'] ?? '';
      if (key.isNotEmpty) keys.add(key);
    }
    return keys;
  }

  /// Gemini model for AI Chat
  static const String geminiChatModel = 'gemini-2.5-flash';

  /// Gemini API key for intent analysis & embeddings
  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GEMINI_CHAT_API_KEY'] ?? '';

  /// Gemini Flash model for intent analysis
  static const String geminiFlashModel = 'gemini-2.0-flash';

  /// Gemini embedding model
  static const String geminiEmbeddingModel = 'text-embedding-004';

  /// Embedding dimension (768 for text-embedding-004)
  static const int embeddingDimension = 768;

  /// Generation config
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 1024;

  /// Cache durations
  static const Duration embeddingCacheDuration = Duration(hours: 24);
  static const Duration matchCacheDuration = Duration(minutes: 30);

  /// Matching thresholds
  static const double intentMatchWeight = 0.4;
  static const double semanticMatchWeight = 0.3;
  static const double locationMatchWeight = 0.15;
  static const double timeMatchWeight = 0.10;
  static const double keywordMatchWeight = 0.05;

  /// Timeout configuration
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration apiCallTimeout = Duration(seconds: 20);

  /// Cache configuration
  static const int maxCacheSize = 1000;

  /// Firestore collection names
  static const String postsCollection = 'posts';
  static const String matchesCollection = 'matches';

  /// Single Tap AI chat assistant constants
  static const String singletapAiSenderId = 'singletap_ai';
  static const String singletapAiDisplayName = 'Single Tap AI';
}
