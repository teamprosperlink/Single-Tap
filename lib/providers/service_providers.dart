import 'package:flutter_riverpod/flutter_riverpod.dart';

// Services
import '../services/location services/gemini_service.dart';
import '../services/location services/location_service.dart';
import '../services/connection_service.dart';
import '../services/chat services/conversation_service.dart';
import '../services/unified_post_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/connectivity_service.dart';
import '../services/universal_intent_service.dart';
import '../services/unified_matching_service.dart';
import '../services/profile services/photo_cache_service.dart';
import '../services/hybrid_chat_service.dart';
import '../services/group_chat_service.dart';
import '../services/error services/error_tracking_service.dart';

/// AI & MATCHING SERVICES

/// Gemini AI service for embeddings and intent analysis
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Universal intent service for processing user intents
final universalIntentServiceProvider = Provider<UniversalIntentService>((ref) {
  return UniversalIntentService();
});

/// Unified matching service for semantic matching
final unifiedMatchingServiceProvider = Provider<UnifiedMatchingService>((ref) {
  return UnifiedMatchingService();
});

/// Unified post service for post operations
final unifiedPostServiceProvider = Provider<UnifiedPostService>((ref) {
  return UnifiedPostService();
});

/// LOCATION SERVICES

/// Location service for GPS and location updates
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// CONNECTION & SOCIAL SERVICES

/// Connection service for managing user connections
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService();
});

/// MESSAGING SERVICES

/// Conversation service for chat conversations
final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService();
});

/// Hybrid chat service for message operations
final hybridChatServiceProvider = Provider<HybridChatService>((ref) {
  return HybridChatService();
});

/// Group chat service for group messaging
final groupChatServiceProvider = Provider<GroupChatService>((ref) {
  return GroupChatService();
});

/// NOTIFICATION & ANALYTICS SERVICES

/// Notification service for push notifications
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Analytics service for event tracking
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Error tracking service for Sentry
final errorTrackingServiceProvider = Provider<ErrorTrackingService>((ref) {
  return ErrorTrackingService();
});

/// UTILITY SERVICES

/// Connectivity service for network status
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Photo cache service for image caching
final photoCacheServiceProvider = Provider<PhotoCacheService>((ref) {
  return PhotoCacheService();
});

/// SERVICE INITIALIZATION

/// Initialize all services that need startup initialization
Future<void> initializeServices(ProviderContainer container) async {
  // Initialize notification service
  await container.read(notificationServiceProvider).initialize();

  // Initialize connectivity service
  await container.read(connectivityServiceProvider).initialize();

  // Initialize analytics
  await container.read(analyticsServiceProvider).initialize();
}
