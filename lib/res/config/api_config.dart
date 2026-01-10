import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration
/// This file contains all API keys and configurations used throughout the app
class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();

  /// Google Gemini API Key - loaded from environment variables
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Gemini model names
  static const String geminiFlashModel = 'gemini-1.5-flash-latest';
  static const String geminiEmbeddingModel = 'text-embedding-004';

  /// API endpoints
  static const String geminiApiBaseUrl = 'https://generativelanguage.googleapis.com';

  /// Model configuration
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 1024;

  /// Embedding configuration
  static const int embeddingDimension = 768;

  /// Matching thresholds
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
