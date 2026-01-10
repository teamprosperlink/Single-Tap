import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';

/// Post Validator
///
/// Validates and auto-fixes posts before storage
/// Ensures all required fields are present and valid
class PostValidator {

  /// Validate a post model
  static ValidationResult validate(PostModel post) {
    List<String> errors = [];
    List<String> warnings = [];

    // Check required fields
    if (post.userId.isEmpty) {
      errors.add('Post must have a userId');
    }

    if (post.originalPrompt.isEmpty) {
      errors.add('Post must have an originalPrompt');
    }

    if (post.title.isEmpty) {
      warnings.add('Post has no title');
    }

    if (post.description.isEmpty) {
      warnings.add('Post has no description');
    }

    // Check embedding
    if (post.embedding == null || post.embedding!.isEmpty) {
      errors.add('Post must have an embedding for matching');
    } else if (post.embedding!.length != 768) {
      warnings.add(
        'Embedding dimension is ${post.embedding!.length}, expected 768',
      );
    }

    // Check keywords
    if (post.keywords == null || post.keywords!.isEmpty) {
      warnings.add('Post has no keywords');
    }

    // Check intentAnalysis
    if (post.intentAnalysis.isEmpty) {
      warnings.add('Post has no intentAnalysis');
    }

    // Check timestamps
    if (post.createdAt.isAfter(DateTime.now())) {
      warnings.add('Post createdAt is in the future');
    }

    if (post.expiresAt != null && post.expiresAt!.isBefore(DateTime.now())) {
      warnings.add('Post has already expired');
    }

    // Check price logic
    if (post.priceMin != null && post.priceMax != null) {
      if (post.priceMin! > post.priceMax!) {
        errors.add('priceMin cannot be greater than priceMax');
      }
    }

    if (post.price != null && post.price! < 0) {
      errors.add('Price cannot be negative');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Ensure a post is valid, auto-fixing where possible
  static Future<PostModel> ensureValid(PostModel post) async {
    try {
      debugPrint(' Validating post...');

      // Auto-fix missing title
      String title = post.title;
      if (title.isEmpty && post.originalPrompt.isNotEmpty) {
        title = post.originalPrompt.length > 50
            ? '${post.originalPrompt.substring(0, 47)}...'
            : post.originalPrompt;
        debugPrint('Auto-generated title');
      }

      // Auto-fix missing description
      String description = post.description;
      if (description.isEmpty && post.originalPrompt.isNotEmpty) {
        description = post.originalPrompt;
        debugPrint('Auto-generated description');
      }

      // Auto-fix missing embedding
      List<double>? embedding = post.embedding;
      if (embedding == null || embedding.isEmpty) {
        debugPrint(' Warning: Post has no embedding - matching may not work');
      }

      // Auto-fix missing keywords
      List<String>? keywords = post.keywords;
      if (keywords == null || keywords.isEmpty) {
        // Extract simple keywords from title and description
        keywords = '$title $description'
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 3)
            .take(10)
            .toList();
        debugPrint(' Keywords extracted: ${keywords.join(', ')}');
      }

      // Auto-fix missing intentAnalysis
      Map<String, dynamic> intentAnalysis = post.intentAnalysis;
      if (intentAnalysis.isEmpty) {
        intentAnalysis = {
          'primary_intent': post.originalPrompt,
          'action_type': 'neutral',
          'domain': 'general',
          'confidence': 0.5,
        };
        debugPrint(' Default intentAnalysis added');
      }

      // Auto-fix expiration date
      DateTime? expiresAt = post.expiresAt;
      if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
        expiresAt = DateTime.now().add(const Duration(days: 30));
        debugPrint(' Expiration date set to 30 days from now');
      }

      // Create fixed post
      final fixedPost = PostModel(
        id: post.id,
        userId: post.userId,
        originalPrompt: post.originalPrompt,
        title: title,
        description: description,
        intentAnalysis: intentAnalysis,
        images: post.images,
        metadata: post.metadata,
        createdAt: post.createdAt,
        expiresAt: expiresAt,
        isActive: post.isActive,
        embedding: embedding,
        keywords: keywords,
        similarityScore: post.similarityScore,
        location: post.location,
        latitude: post.latitude,
        longitude: post.longitude,
        price: post.price,
        priceMin: post.priceMin,
        priceMax: post.priceMax,
        currency: post.currency,
        viewCount: post.viewCount,
        matchedUserIds: post.matchedUserIds,
        clarificationAnswers: post.clarificationAnswers,
        gender: post.gender,
        ageRange: post.ageRange,
        condition: post.condition,
        brand: post.brand,
      );

      // Validate the fixed post
      final validation = validate(fixedPost);

      if (!validation.isValid) {
        debugPrint(' Post validation failed: ${validation.errors.join(', ')}');
        throw ValidationException(validation.errors.join('; '));
      }

      if (validation.warnings.isNotEmpty) {
        debugPrint(' Post warnings: ${validation.warnings.join(', ')}');
      }

      debugPrint(' Post validation successful');
      return fixedPost;
    } catch (e) {
      debugPrint(' Error ensuring post validity: $e');
      rethrow;
    }
  }

  /// Validate post data from Map (before creating PostModel)
  static ValidationResult validateMap(Map<String, dynamic> data) {
    List<String> errors = [];
    List<String> warnings = [];

    // Check required fields in map
    if (data['userId'] == null || data['userId'].toString().isEmpty) {
      errors.add('userId is required');
    }

    if (data['originalPrompt'] == null ||
        data['originalPrompt'].toString().isEmpty) {
      errors.add('originalPrompt is required');
    }

    if (data['embedding'] == null || (data['embedding'] as List).isEmpty) {
      errors.add('embedding is required');
    }

    if (data['title'] == null || data['title'].toString().isEmpty) {
      warnings.add('title is missing');
    }

    if (data['intentAnalysis'] == null ||
        (data['intentAnalysis'] as Map).isEmpty) {
      warnings.add('intentAnalysis is missing');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Quick validation check (synchronous)
  static bool isValidQuick(PostModel post) {
    return post.userId.isNotEmpty &&
        post.originalPrompt.isNotEmpty &&
        post.embedding != null &&
        post.embedding!.isNotEmpty &&
        post.title.isNotEmpty;
  }

  /// Sanitize user input
  static String sanitizeInput(String input) {
    // Remove excessive whitespace
    String sanitized = input.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Remove potential injection characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>]'), '');

    // Limit length
    if (sanitized.length > 500) {
      sanitized = sanitized.substring(0, 500);
    }

    return sanitized;
  }

  /// Check if post is expired
  static bool isExpired(PostModel post) {
    if (post.expiresAt == null) return false;
    return post.expiresAt!.isBefore(DateTime.now());
  }

  /// Check if post is valid for matching
  static bool isMatchable(PostModel post) {
    return post.isActive &&
        !isExpired(post) &&
        post.embedding != null &&
        post.embedding!.isNotEmpty &&
        post.userId.isNotEmpty;
  }
}

/// Validation result class
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('ValidationResult(isValid: $isValid)');

    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (var error in errors) {
        buffer.writeln('  - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (var warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }

    return buffer.toString();
  }
}

/// Validation exception
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
