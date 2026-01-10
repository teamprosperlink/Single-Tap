import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized analytics service for tracking user events and app usage
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Initialize analytics
  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      // Analytics initialization error
    }
  }

  /// Set user ID for tracking
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      // Error setting user ID
    }
  }

  /// Set user properties
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      // Error setting user property
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      // Error logging screen view
    }
  }

  /// Log login event
  Future<void> logLogin({String? method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      // Error logging login
    }
  }

  /// Log sign up event
  Future<void> logSignUp({String? method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method ?? 'email');
    } catch (e) {
      // Error logging sign up
    }
  }

  /// Log post creation
  Future<void> logPostCreated({
    required String postId,
    String? category,
    String? actionType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'post_created',
        parameters: {
          'post_id': postId,
          if (category != null) 'category': category,
          if (actionType != null) 'action_type': actionType,
        },
      );
    } catch (e) {
      // Error logging post created
    }
  }

  /// Log match found
  Future<void> logMatchFound({
    required String postId,
    required String matchedPostId,
    required double score,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'match_found',
        parameters: {
          'post_id': postId,
          'matched_post_id': matchedPostId,
          'score': score,
        },
      );
    } catch (e) {
      // Error logging match found
    }
  }

  /// Log message sent
  Future<void> logMessageSent({
    required String conversationId,
    bool isFirstMessage = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'message_sent',
        parameters: {
          'conversation_id': conversationId,
          'is_first_message': isFirstMessage,
        },
      );
    } catch (e) {
      // Error logging message sent
    }
  }

  /// Log connection request
  Future<void> logConnectionRequest({
    required String targetUserId,
    required String action, // 'sent', 'accepted', 'rejected'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'connection_request',
        parameters: {
          'target_user_id': targetUserId,
          'action': action,
        },
      );
    } catch (e) {
      // Error logging connection request
    }
  }

  /// Log search performed
  Future<void> logSearch({
    required String query,
    int? resultsCount,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: query,
      );
      // Log results count separately if needed
      if (resultsCount != null) {
        await _analytics.logEvent(
          name: 'search_results',
          parameters: {
            'query': query,
            'results_count': resultsCount,
          },
        );
      }
    } catch (e) {
      // Error logging search
    }
  }

  /// Log filter applied
  Future<void> logFilterApplied({
    required String filterType,
    required String filterValue,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'filter_applied',
        parameters: {
          'filter_type': filterType,
          'filter_value': filterValue,
        },
      );
    } catch (e) {
      // Error logging filter applied
    }
  }

  /// Log feature used
  Future<void> logFeatureUsed({required String featureName}) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {'feature_name': featureName},
      );
    } catch (e) {
      // Error logging feature used
    }
  }

  /// Log error occurred
  Future<void> logError({
    required String errorType,
    String? errorMessage,
    String? screenName,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          if (errorMessage != null) 'error_message': errorMessage.substring(
            0,
            errorMessage.length > 100 ? 100 : errorMessage.length,
          ),
          if (screenName != null) 'screen_name': screenName,
        },
      );
    } catch (e) {
      // Error logging error event
    }
  }

  /// Log app open
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      // Error logging app open
    }
  }

  /// Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Error logging event
    }
  }
}
