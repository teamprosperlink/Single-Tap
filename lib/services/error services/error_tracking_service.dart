
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized error tracking service using Sentry
class ErrorTrackingService {
  static final ErrorTrackingService _instance = ErrorTrackingService._internal();
  factory ErrorTrackingService() => _instance;
  ErrorTrackingService._internal();

  bool _isInitialized = false;

  /// Get Sentry DSN from environment variables
  static String get _sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';

  /// Check if Sentry is configured
  static bool get isConfigured => _sentryDsn.isNotEmpty;

  /// Initialize Sentry error tracking
  /// Call this in main() before runApp()
  static Future<void> initialize(FutureOr<void> Function() appRunner) async {
    if (!isConfigured) {
      debugPrint('Sentry DSN not configured. Error tracking disabled.');
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        // Set environment based on debug mode
        options.environment = kDebugMode ? 'development' : 'production';
        // Set sample rate (1.0 = 100% of events)
        options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
        // Enable auto performance monitoring
        options.enableAutoPerformanceTracing = true;
        // Attach screenshots on errors (optional)
        options.attachScreenshot = true;
        // Don't send PII
        options.sendDefaultPii = false;
        // Max breadcrumbs to store
        options.maxBreadcrumbs = 50;
        // Ignore specific exceptions
        options.beforeSend = (event, hint) {
          // Don't send image decode errors
          if (event.throwable?.toString().contains('ImageDecoder') == true) {
            return null;
          }
          return event;
        };
      },
      appRunner: appRunner,
    );

    ErrorTrackingService()._isInitialized = true;
    debugPrint('Sentry error tracking initialized');
  }

  /// Set user context for better error tracking
  Future<void> setUser({
    String? id,
    String? email,
    String? username,
  }) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      if (id != null || email != null || username != null) {
        scope.setUser(SentryUser(
          id: id,
          email: email,
          username: username,
        ));
      } else {
        scope.setUser(null);
      }
    });
  }

  /// Clear user context (on logout)
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Add a breadcrumb for debugging
  Future<void> addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) async {
    if (!_isInitialized) return;

    await Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      data: data,
      level: level,
      timestamp: DateTime.now(),
    ));
  }

  /// Capture an exception
  Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? message,
    Map<String, dynamic>? extras,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isInitialized) {
      debugPrint('Error (Sentry not initialized): $exception');
      return;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (message != null) {
          scope.setTag('error_message', message);
        }
        if (extras != null) {
          extras.forEach((key, value) {
            scope.setContexts(key, value is Map ? value : {'value': value});
          });
        }
        scope.level = level;
      },
    );
  }

  /// Capture a message
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) {
      debugPrint('Message (Sentry not initialized): $message');
      return;
    }

    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extras != null) {
          extras.forEach((key, value) {
            scope.setContexts(key, value is Map ? value : {'value': value});
          });
        }
      },
    );
  }

  /// Set a tag for filtering
  Future<void> setTag(String key, String value) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Set extra context data
  Future<void> setContext(String key, dynamic value) async {
    if (!_isInitialized) return;

    await Sentry.configureScope((scope) {
      scope.setContexts(key, value is Map ? value : {'value': value});
    });
  }

  /// Start a transaction for performance monitoring
  ISentrySpan? startTransaction({
    required String name,
    required String operation,
  }) {
    if (!_isInitialized) return null;

    return Sentry.startTransaction(name, operation);
  }

  /// Wrap a function with error tracking
  Future<T?> trackOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) {
      return await operation();
    }

    final transaction = Sentry.startTransaction(name, 'operation');

    try {
      final result = await operation();
      transaction.status = const SpanStatus.ok();
      return result;
    } catch (e, stackTrace) {
      transaction.status = const SpanStatus.internalError();
      await captureException(e, stackTrace: stackTrace, extras: extras);
      rethrow;
    } finally {
      await transaction.finish();
    }
  }
}

/// Extension for easy error reporting
extension ErrorTrackingExtension on Object {
  Future<void> reportToSentry({
    dynamic stackTrace,
    String? message,
  }) async {
    await ErrorTrackingService().captureException(
      this,
      stackTrace: stackTrace,
      message: message,
    );
  }
}
