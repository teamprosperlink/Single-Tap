import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../res/config/api_config.dart';

class AiChatService {
  static final AiChatService _instance = AiChatService._internal();
  factory AiChatService() => _instance;
  AiChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Track which API keys have exhausted their daily quota.
  /// Key: API key (masked), Value: expiry time
  final Map<String, DateTime> _exhaustedKeys = {};

  /// Track per-minute rate-limited keys (short cooldown, NOT quota exhaustion).
  /// Key: API key (masked), Value: cooldown expiry
  final Map<String, DateTime> _rateLimitedKeys = {};

  /// Process an @Single Tap AI mention in a chat.
  /// Works for both normal chat and group chat.
  Future<void> processAiMention({
    required String conversationId,
    required String userMessage,
    required String userName,
    required bool isGroupChat,
  }) async {
    try {
      // Set AI typing indicator
      await _setAiTyping(conversationId, true);

      // Extract the question
      final question = _extractQuestion(userMessage);
      if (question.isEmpty) {
        await _saveAiMessage(
          conversationId: conversationId,
          text:
              "Hi! I'm Single Tap AI. Ask me anything by typing @Single Tap AI followed by your question.",
          isGroupChat: isGroupChat,
        );
        return;
      }

      // Call Gemini API with key rotation
      final result = await _callGeminiWithRotation(question, userName);

      if (result['success'] == true) {
        await _saveAiMessage(
          conversationId: conversationId,
          text: result['text'] as String,
          isGroupChat: isGroupChat,
        );
      } else {
        final errorMsg = result['error'] as String? ?? 'Unknown error';
        debugPrint('Single Tap AI error: $errorMsg');
        await _saveAiMessage(
          conversationId: conversationId,
          text: _getUserFriendlyError(errorMsg),
          isGroupChat: isGroupChat,
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('AiChatService error: $e');
      try {
        await _saveAiMessage(
          conversationId: conversationId,
          text: "Sorry, something went wrong. Please try again.",
          isGroupChat: isGroupChat,
          isError: true,
        );
      } catch (_) {}
    } finally {
      await _setAiTyping(conversationId, false);
    }
  }

  /// Try all available API keys, skipping exhausted ones.
  /// Per-minute rate limits get a short cooldown (2 min), daily quota gets 15 min.
  Future<Map<String, dynamic>> _callGeminiWithRotation(
      String question, String userName) async {
    final allKeys = ApiConfig.allChatApiKeys;
    if (allKeys.isEmpty) {
      return {'success': false, 'error': 'No API keys configured.'};
    }

    final now = DateTime.now();

    // Clean up expired entries
    _exhaustedKeys.removeWhere((_, expiry) => now.isAfter(expiry));
    _rateLimitedKeys.removeWhere((_, expiry) => now.isAfter(expiry));

    // Filter: skip daily-exhausted keys, but allow rate-limited keys if cooldown passed
    final availableKeys = allKeys.where((key) {
      final masked = _maskKey(key);
      if (_exhaustedKeys.containsKey(masked)) return false;
      return true;
    }).toList();

    // If all keys exhausted, check if any rate-limited key has cooled down
    if (availableKeys.isEmpty) {
      // Try rate-limited keys whose cooldown has expired
      final cooledKeys = allKeys.where((key) {
        final masked = _maskKey(key);
        final rlExpiry = _rateLimitedKeys[masked];
        return rlExpiry != null && now.isAfter(rlExpiry);
      }).toList();

      if (cooledKeys.isNotEmpty) {
        availableKeys.addAll(cooledKeys);
        for (final key in cooledKeys) {
          _rateLimitedKeys.remove(_maskKey(key));
        }
        debugPrint('Single Tap AI: ${cooledKeys.length} rate-limited keys recovered');
      }
    }

    if (availableKeys.isEmpty) {
      debugPrint('Single Tap AI: All ${allKeys.length} API keys exhausted');
      return {
        'success': false,
        'error': 'Quota exhausted on all keys',
      };
    }

    debugPrint(
        'Single Tap AI: ${availableKeys.length}/${allKeys.length} API keys available');

    String lastError = 'Quota exhausted on all keys';

    // Models to try in order for each key
    const modelChain = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.0-flash-lite'];

    for (final apiKey in availableKeys) {
      final maskedKey = _maskKey(apiKey);
      debugPrint('Single Tap AI: trying key=$maskedKey');

      for (final model in modelChain) {
        final result = await _callModel(model, question, userName, apiKey);
        if (result['success'] == true) return result;

        final error = result['error'] as String? ?? '';
        lastError = error;

        // Content/safety errors — don't try other keys or models
        if (error.contains('blocked') || error.contains('safety')) {
          return result;
        }

        // API key completely invalid — mark dead for 15 min, skip to next key
        if (error.contains('API key invalid')) {
          _exhaustedKeys[maskedKey] = now.add(const Duration(minutes: 15));
          debugPrint('Single Tap AI: key $maskedKey invalid, blocked 15min');
          break; // next key
        }

        // Daily quota exhausted (limit: 0) — block for 15 min only (not 1 hour)
        if (error.contains('Quota exhausted')) {
          _exhaustedKeys[maskedKey] = now.add(const Duration(minutes: 15));
          debugPrint('Single Tap AI: key $maskedKey quota exhausted, blocked 15min');
          break; // next key
        }

        // Temporary per-minute rate limit — cooldown 2 min, try next model
        if (error.contains('Rate limited')) {
          _rateLimitedKeys[maskedKey] = now.add(const Duration(minutes: 2));
          debugPrint('Single Tap AI: key $maskedKey rate-limited on $model, trying next model...');
          continue; // next model
        }

        // Model not available — try next model on same key
        if (error.contains('Model not available') || error.contains('400')) {
          debugPrint('Single Tap AI: $model unavailable, trying next model...');
          continue; // next model
        }

        // Other error — try next model
        continue;
      }
    }

    return {
      'success': false,
      'error': lastError.contains('Quota') || lastError.contains('key')
          ? 'Quota exhausted on all keys'
          : lastError,
    };
  }

  /// Call a specific Gemini model — retries only on temporary rate limits, not quota exhaustion.
  /// On 400 errors, tries v1 endpoint as fallback (v1beta may not work for all keys).
  Future<Map<String, dynamic>> _callModel(
      String model, String question, String userName, String apiKey) async {
    final prompt =
        '''You are Single Tap AI, a helpful assistant embedded in the Single Tap chat app.
Keep your responses concise, friendly, and helpful. Use a conversational tone.
NEVER address the user by name. Do not say "Hi [name]" or "Hey [name]". Just start with the answer directly or a generic greeting like "Hey!" or "Here you go!".
Format your answers in clear bullet points (use • symbol) whenever the answer has multiple pieces of information. Use short paragraphs only for simple one-line answers.
Wrap important keywords, names, or key terms in double asterisks like **this**. For example: **Sheer Khurma**, **Gulab Jamun**, **Python**, **React**.
Do not use any other markdown formatting like ##, ```, or _. Keep responses under 300 words unless the question requires a longer explanation.

Question: $question''';

    // Try v1beta first, then v1 on 400
    final apiVersions = ['v1beta', 'v1'];

    for (final apiVersion in apiVersions) {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
      });

      try {
        final response = await http
            .post(url,
                headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 30));

        debugPrint(
            'Single Tap AI [$model/$apiVersion] status=${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Check for blocked content
          final promptFeedback = data['promptFeedback'];
          if (promptFeedback != null &&
              promptFeedback['blockReason'] != null) {
            return {
              'success': false,
              'error':
                  'Content was blocked: ${promptFeedback['blockReason']}'
            };
          }

          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            return {'success': false, 'error': 'No response generated.'};
          }

          final finishReason = candidates[0]['finishReason'] as String?;
          if (finishReason == 'SAFETY') {
            return {
              'success': false,
              'error': 'Response blocked by safety filters.'
            };
          }

          final text =
              candidates[0]['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return {'success': true, 'text': text};
          }

          return {'success': false, 'error': 'Empty response from AI.'};
        } else if (response.statusCode == 400) {
          // 400 = Bad Request — could be invalid model, disabled key, or bad params
          debugPrint('Single Tap AI [$model/$apiVersion] 400 body: ${response.body}');

          final bodyLower = response.body.toLowerCase();

          // API key completely disabled or invalid
          if (bodyLower.contains('api_key_invalid') ||
              bodyLower.contains('api key not valid') ||
              bodyLower.contains('api key expired')) {
            return {'success': false, 'error': 'API key invalid'};
          }

          // Model not found or not supported — don't retry with different version
          if (bodyLower.contains('model not found') ||
              bodyLower.contains('is not found') ||
              bodyLower.contains('not supported')) {
            return {'success': false, 'error': 'Model not available: $model'};
          }

          // Billing/quota related 400
          if (bodyLower.contains('billing') ||
              bodyLower.contains('quota') ||
              bodyLower.contains('exceeded') ||
              bodyLower.contains('disabled')) {
            return {'success': false, 'error': 'Quota exhausted'};
          }

          // Invalid parameter (like topK not supported) — try next API version
          if (bodyLower.contains('invalid') || bodyLower.contains('parameter')) {
            debugPrint('Single Tap AI: 400 with $apiVersion, trying next version...');
            continue;
          }

          // Unknown 400 — try next API version before giving up
          if (apiVersion == 'v1beta') {
            debugPrint('Single Tap AI: 400 on v1beta, trying v1...');
            continue;
          }

          return {'success': false, 'error': 'Bad request (400)'};
        } else if (response.statusCode == 429) {
          debugPrint('Single Tap AI [$model/$apiVersion] 429 body: ${response.body}');

          final limitType = _classifyRateLimit(response.body);
          debugPrint('Single Tap AI [$model]: 429 classified as "$limitType"');

          if (limitType == 'daily') {
            return {'success': false, 'error': 'Quota exhausted'};
          }

          // Per-minute or unknown rate limit — wait and retry (up to 2 attempts)
          for (int retry = 0; retry < 2; retry++) {
            final waitSecs = (retry + 1) * 5; // 5s, then 10s
            debugPrint('Single Tap AI [$model] rate limited, retrying in ${waitSecs}s (attempt ${retry + 1}/2)...');
            await Future.delayed(Duration(seconds: waitSecs));

            try {
              final retryResponse = await http
                  .post(url,
                      headers: {'Content-Type': 'application/json'}, body: body)
                  .timeout(const Duration(seconds: 30));

              if (retryResponse.statusCode == 200) {
                final data = jsonDecode(retryResponse.body);
                final candidates = data['candidates'] as List?;
                if (candidates != null && candidates.isNotEmpty) {
                  final text =
                      candidates[0]['content']?['parts']?[0]?['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    return {'success': true, 'text': text};
                  }
                }
              } else if (retryResponse.statusCode == 429) {
                // Still rate limited — check if it became daily quota
                if (_isQuotaExhausted(retryResponse.body)) {
                  return {'success': false, 'error': 'Quota exhausted'};
                }
                continue; // try next retry
              }
            } catch (e) {
              debugPrint('Single Tap AI [$model] retry error: $e');
            }
          }
          return {'success': false, 'error': 'Rate limited'};
        } else if (response.statusCode == 403 ||
            response.statusCode == 401) {
          return {
            'success': false,
            'error': 'API key invalid'
          };
        } else {
          debugPrint('Single Tap AI [$model/$apiVersion] error ${response.statusCode}: ${response.body}');
          return {
            'success': false,
            'error': 'API error ${response.statusCode}'
          };
        }
      } catch (e) {
        debugPrint('Single Tap AI [$model/$apiVersion] exception: $e');
        // On network error with v1beta, try v1
        if (apiVersion == 'v1beta') continue;
        return {'success': false, 'error': 'Network error: $e'};
      }
    }
    return {'success': false, 'error': 'Bad request (400)'};
  }

  /// Parse a 429 response to determine if daily quota is exhausted (limit: 0)
  /// vs a temporary per-minute rate limit (which resolves in seconds).
  /// Returns: 'daily' for daily quota, 'minute' for per-minute, 'unknown' otherwise.
  String _classifyRateLimit(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final message = data['error']?['message'] as String? ?? '';
      final messageLower = message.toLowerCase();

      // Daily quota explicitly exhausted
      if (messageLower.contains('perday') && message.contains('limit: 0')) {
        return 'daily';
      }
      // "limit: 0" without PerDay — could be daily or resource limit
      if (message.contains('limit: 0')) return 'daily';

      // "quota" or "exceeded" keywords
      if (messageLower.contains('quota') || messageLower.contains('exceeded')) {
        return 'daily';
      }

      // Check retry delay — if > 60s, likely daily quota
      final details = data['error']?['details'] as List? ?? [];
      for (final detail in details) {
        if (detail['@type']?.toString().contains('RetryInfo') == true) {
          final retryDelay = detail['retryDelay'] as String? ?? '';
          final seconds =
              int.tryParse(retryDelay.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (seconds > 60) return 'daily';
          if (seconds > 0) return 'minute';
        }
      }

      // Per-minute rate limit (short term)
      if (messageLower.contains('perminute') || messageLower.contains('per minute')) {
        return 'minute';
      }
    } catch (_) {}
    return 'unknown';
  }

  /// Legacy compatibility wrapper
  bool _isQuotaExhausted(String responseBody) {
    return _classifyRateLimit(responseBody) == 'daily';
  }

  /// Mask an API key for logging
  String _maskKey(String apiKey) {
    if (apiKey.length > 12) {
      return '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}';
    }
    return '***';
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyError(String error) {
    if (error.contains('Quota exhausted on all keys')) {
      return "I'm temporarily unavailable due to high usage. Please try again in 10-15 minutes.";
    }
    if (error.contains('Quota exhausted')) {
      return "I've reached my usage limit. Please try again in a few minutes.";
    }
    if (error.contains('API key invalid')) {
      return "I'm having a configuration issue. Please contact support.";
    }
    if (error.contains('Bad request') || error.contains('400')) {
      return "I'm temporarily unable to process your request. Please try again in a few minutes.";
    }
    if (error.contains('Model not available')) {
      return "AI service is currently updating. Please try again in a few minutes.";
    }
    if (error.contains('Rate limit') || error.contains('429')) {
      return "I'm getting a lot of questions right now! Please try again in about a minute.";
    }
    if (error.contains('authentication') || error.contains('403')) {
      return "I'm having trouble connecting. Please contact support.";
    }
    if (error.contains('blocked') || error.contains('safety')) {
      return "I can't answer that question. Please try rephrasing it.";
    }
    if (error.contains('timeout') || error.contains('Network')) {
      return "Network is slow. Please check your connection and try again.";
    }
    if (error.contains('No API keys')) {
      return "AI chat is not configured. Please contact support.";
    }
    return "Sorry, something went wrong. Please try again in a moment.";
  }

  /// Extract the question portion from a message containing @Single Tap AI
  String _extractQuestion(String message) {
    final pattern = RegExp(r'@Single\s*Tap\s*AI\s*', caseSensitive: false);
    return message.replaceAll(pattern, '').trim();
  }

  /// Save an AI message to Firestore
  Future<void> _saveAiMessage({
    required String conversationId,
    required String text,
    required bool isGroupChat,
    bool isError = false,
  }) async {
    final messageData = <String, dynamic>{
      'senderId': ApiConfig.singletapAiSenderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isAiMessage': true,
      'isSystemMessage': false,
      'isDeleted': false,
      'isEdited': false,
      'read': false,
      'isRead': false,
      'status': 2,
    };

    if (isGroupChat) {
      messageData['readBy'] = <String>[];
    }

    if (isError) {
      messageData['isAiError'] = true;
    }

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);

    // Update conversation metadata
    final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': 'Single Tap AI: $preview',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': ApiConfig.singletapAiSenderId,
    });
  }

  /// Set/clear AI typing indicator
  Future<void> _setAiTyping(String conversationId, bool isTyping) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isTyping.${ApiConfig.singletapAiSenderId}': isTyping,
      });
    } catch (e) {
      debugPrint('Error setting AI typing: $e');
    }
  }

  /// Check if a message text contains an @Single Tap AI mention
  static bool containsAiMention(String text) {
    return RegExp(r'@Single\s*Tap\s*AI', caseSensitive: false).hasMatch(text);
  }
}
