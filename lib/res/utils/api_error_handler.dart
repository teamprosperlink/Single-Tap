import 'package:flutter/foundation.dart';

enum ApiErrorType {
  quotaExceeded,
  networkError,
  invalidApiKey,
  modelNotFound,
  unknown,
}

class ApiErrorHandler {
  static ApiErrorType getErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('quota') || errorString.contains('billing')) {
      return ApiErrorType.quotaExceeded;
    } else if (errorString.contains('network') ||
        errorString.contains('no address associated') ||
        errorString.contains('unable to resolve host')) {
      return ApiErrorType.networkError;
    } else if (errorString.contains('api key') ||
        errorString.contains('unauthorized')) {
      return ApiErrorType.invalidApiKey;
    } else if (errorString.contains('model not found') ||
        errorString.contains('404')) {
      return ApiErrorType.modelNotFound;
    }

    return ApiErrorType.unknown;
  }

  static String getErrorMessage(ApiErrorType errorType) {
    switch (errorType) {
      case ApiErrorType.quotaExceeded:
        return 'API quota exceeded. Please check your billing and usage limits.';
      case ApiErrorType.networkError:
        return 'Network connection error. Please check your internet connection.';
      case ApiErrorType.invalidApiKey:
        return 'Invalid API key. Please verify your configuration.';
      case ApiErrorType.modelNotFound:
        return 'The requested model was not found. Please check model availability.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred. Please try again later.';
    }
  }

  static Future<T?> handleApiCall<T>(
    Future<T> Function() apiCall, {
    T? Function()? fallback,
    void Function(ApiErrorType)? onError,
  }) async {
    try {
      return await apiCall();
    } catch (error) {
      final errorType = getErrorType(error);

      debugPrint('API Error: ${getErrorMessage(errorType)}');
      debugPrint('Original error: $error');

      onError?.call(errorType);

      if (fallback != null) {
        return fallback();
      }

      return null;
    }
  }
}
