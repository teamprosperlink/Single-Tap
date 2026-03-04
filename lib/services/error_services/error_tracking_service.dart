import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized error tracking service using Firebase Crashlytics
class ErrorTrackingService {
  static final ErrorTrackingService _instance =
      ErrorTrackingService._internal();
  factory ErrorTrackingService() => _instance;
  ErrorTrackingService._internal();

  bool _isInitialized = false;

  /// Initialize Crashlytics error tracking
  /// Call this in main() after Firebase.initializeApp()
  static Future<void> initialize(FutureOr<void> Function() appRunner) async {
    final crashlytics = FirebaseCrashlytics.instance;

    // Disable in debug mode to avoid noise
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Pass all uncaught Flutter errors to Crashlytics
    FlutterError.onError = crashlytics.recordFlutterFatalError;

    // Pass all uncaught async errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    ErrorTrackingService()._isInitialized = true;
    debugPrint('Firebase Crashlytics error tracking initialized');

    await appRunner();
  }

  /// Set user context for better error tracking
  Future<void> setUser({
    String? id,
    String? email,
    String? username,
  }) async {
    if (!_isInitialized) return;

    final crashlytics = FirebaseCrashlytics.instance;
    if (id != null) {
      await crashlytics.setUserIdentifier(id);
    }
    if (email != null) {
      await crashlytics.setCustomKey('email', email);
    }
    if (username != null) {
      await crashlytics.setCustomKey('username', username);
    }
  }

  /// Clear user context (on logout)
  Future<void> clearUser() async {
    if (!_isInitialized) return;
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }

  /// Add a log message for debugging
  Future<void> addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;
    FirebaseCrashlytics.instance.log(
      '${category != null ? '[$category] ' : ''}$message',
    );
  }

  /// Capture an exception
  Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? message,
    Map<String, dynamic>? extras,
    bool fatal = false,
  }) async {
    if (!_isInitialized) {
      debugPrint('Error (Crashlytics not initialized): $exception');
      return;
    }

    if (message != null) {
      FirebaseCrashlytics.instance.log(message);
    }

    if (extras != null) {
      for (final entry in extras.entries) {
        await FirebaseCrashlytics.instance
            .setCustomKey(entry.key, entry.value.toString());
      }
    }

    await FirebaseCrashlytics.instance.recordError(
      exception,
      stackTrace is StackTrace ? stackTrace : StackTrace.current,
      fatal: fatal,
    );
  }

  /// Capture a message
  Future<void> captureMessage(
    String message, {
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) {
      debugPrint('Message (Crashlytics not initialized): $message');
      return;
    }

    FirebaseCrashlytics.instance.log(message);
  }

  /// Set a custom key for filtering
  Future<void> setTag(String key, String value) async {
    if (!_isInitialized) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  /// Set extra context data
  Future<void> setContext(String key, dynamic value) async {
    if (!_isInitialized) return;
    await FirebaseCrashlytics.instance
        .setCustomKey(key, value.toString());
  }

  /// Wrap a function with error tracking
  Future<T?> trackOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, dynamic>? extras,
  }) async {
    try {
      final result = await operation();
      return result;
    } catch (e, stackTrace) {
      await captureException(e, stackTrace: stackTrace, extras: extras);
      rethrow;
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
