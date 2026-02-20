import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration
/// This file contains all API keys and configurations used throughout the app
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// Google Gemini API Key - loaded from environment variables
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Gemini model names
  static const String geminiFlashModel = 'gemini-2.5-flash';
  static const String geminiEmbeddingModel = 'text-embedding-004';

  /// API endpoints
  static const String geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com';

  /// Model configuration
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 1024;

  /// Embedding configuration
  static const int embeddingDimension = 768;

  /// ── Unified Matching Constants ────────────────────────────────────────
  /// Single source of truth for ALL matching in the app.
  /// Used by: UnifiedPostService, RealtimeMatchingService, VoiceAssistantService

  /// Minimum relevance before detailed scoring. Below this, skip candidate.
  static const double matchPreFilterThreshold = 0.40;

  /// Final score must be >= this to surface as a match.
  static const double matchFinalThreshold = 0.60;

  /// Realtime notification threshold (slightly higher to reduce noise).
  static const double matchRealtimeThreshold = 0.65;

  /// Intent complement bonus when offer↔seek or symmetric↔symmetric.
  static const double matchIntentBonus = 0.15;

  /// Location bonus multiplier (location score 0-1 scaled by this).
  static const double matchLocationWeight = 0.05;

  /// Lifestyle clash penalty.
  static const double matchLifestylePenalty = 0.15;

  /// Keyword-signal damping factor (kwScore * this vs semantic).
  static const double matchKeywordDamping = 0.70;

  /// Max posts to query from Firestore for matching.
  static const int matchQueryLimit = 200;

  /// Max results returned from findMatches.
  static const int matchMaxResults = 20;

  /// Legacy constants (kept for backward compat with UnifiedMatchingService)
  static const double semanticSimilarityThreshold = 0.7;
  static const double intentMatchWeight = 0.4;
  static const double semanticMatchWeight = 0.3;
  static const double locationMatchWeight = 0.15;
  static const double timeMatchWeight = 0.10;
  static const double keywordMatchWeight = 0.05;

  /// Cache configuration
  static const Duration embeddingCacheDuration = Duration(hours: 24);
  static const Duration matchCacheDuration = Duration(minutes: 30);
  static const int maxCacheSize = 1000;

  /// Network timeout configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  static const Duration apiCallTimeout = Duration(seconds: 45);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Firestore collection names
  static const String postsCollection = 'posts';
  static const String usersCollection = 'users';
  static const String matchesCollection = 'matches';
  static const String intentsCollection = 'intents';
  static const String embeddingsCollection = 'embeddings';
  static const String cacheCollection = 'cache';
}
