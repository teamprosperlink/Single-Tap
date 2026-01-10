import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/universal_intent_service.dart';
import '../services/profile services/photo_cache_service.dart';
import 'other providers/app_providers.dart';

/// HOME SCREEN STATE

/// State class for home screen processing
class HomeProcessingState {
  final bool isProcessing;
  final bool isRecording;
  final bool isVoiceProcessing;
  final String voiceText;
  final String? error;

  const HomeProcessingState({
    this.isProcessing = false,
    this.isRecording = false,
    this.isVoiceProcessing = false,
    this.voiceText = '',
    this.error,
  });

  HomeProcessingState copyWith({
    bool? isProcessing,
    bool? isRecording,
    bool? isVoiceProcessing,
    String? voiceText,
    String? error,
  }) {
    return HomeProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      isRecording: isRecording ?? this.isRecording,
      isVoiceProcessing: isVoiceProcessing ?? this.isVoiceProcessing,
      voiceText: voiceText ?? this.voiceText,
      error: error,
    );
  }
}

/// HOME PROCESSING NOTIFIER

class HomeProcessingNotifier extends StateNotifier<HomeProcessingState> {
  HomeProcessingNotifier() : super(const HomeProcessingState());

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void setRecording(bool value) {
    state = state.copyWith(isRecording: value);
  }

  void setVoiceProcessing(bool value) {
    state = state.copyWith(isVoiceProcessing: value);
  }

  void setVoiceText(String text) {
    state = state.copyWith(voiceText: text);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void reset() {
    state = const HomeProcessingState();
  }
}

/// Provider for home processing state
final homeProcessingProvider =
    StateNotifierProvider<HomeProcessingNotifier, HomeProcessingState>((ref) {
      return HomeProcessingNotifier();
    });

/// MATCHES STATE

/// State class for matches
class MatchesState {
  final List<Map<String, dynamic>> matches;
  final bool isLoading;
  final String? error;

  const MatchesState({
    this.matches = const [],
    this.isLoading = false,
    this.error,
  });

  MatchesState copyWith({
    List<Map<String, dynamic>>? matches,
    bool? isLoading,
    String? error,
  }) {
    return MatchesState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasMatches => matches.isNotEmpty;
  int get matchCount => matches.length;
}

/// MATCHES NOTIFIER

class MatchesNotifier extends StateNotifier<MatchesState> {
  final UniversalIntentService _intentService;
  final PhotoCacheService _photoCache;

  MatchesNotifier(this._intentService, this._photoCache)
    : super(const MatchesState());

  /// Process intent and find matches
  Future<void> processIntent(String intent) async {
    if (intent.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _intentService.processIntentAndMatch(intent);

      if (result['success'] == true) {
        final matches = List<Map<String, dynamic>>.from(
          result['matches'] ?? [],
        );

        // Cache photo URLs
        for (final match in matches) {
          final userProfile = match['userProfile'] ?? {};
          final userId = match['userId'];
          final photoUrl = userProfile['photoUrl'];

          if (userId != null && photoUrl != null) {
            _photoCache.cachePhotoUrl(userId, photoUrl);
          }
        }

        state = state.copyWith(matches: matches, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['error']?.toString(),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear all matches
  void clearMatches() {
    state = const MatchesState();
  }

  /// Add a match
  void addMatch(Map<String, dynamic> match) {
    state = state.copyWith(matches: [...state.matches, match]);
  }

  /// Remove a match by user ID
  void removeMatch(String userId) {
    state = state.copyWith(
      matches: state.matches.where((m) => m['userId'] != userId).toList(),
    );
  }
}

/// Provider for matches
final matchesProvider = StateNotifierProvider<MatchesNotifier, MatchesState>((
  ref,
) {
  return MatchesNotifier(UniversalIntentService(), PhotoCacheService());
});

/// CONVERSATION STATE

/// Message model for conversation
class ConversationMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ConversationMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp,
  };
}

/// State class for conversation
class ConversationState {
  final List<ConversationMessage> messages;

  const ConversationState({this.messages = const []});

  ConversationState copyWith({List<ConversationMessage>? messages}) {
    return ConversationState(messages: messages ?? this.messages);
  }
}

/// CONVERSATION NOTIFIER

class ConversationNotifier extends StateNotifier<ConversationState> {
  ConversationNotifier()
    : super(
        ConversationState(
          messages: [
            ConversationMessage(
              text:
                  'Hi! I\'m your Supper assistant. What would you like to find today?',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

  /// Add a user message
  void addUserMessage(String text) {
    final message = ConversationMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Add an AI message
  void addAIMessage(String text) {
    final message = ConversationMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Clear conversation
  void clear() {
    state = ConversationState(
      messages: [
        ConversationMessage(
          text:
              'Hi! I\'m your Supper assistant. What would you like to find today?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }
}

/// Provider for conversation
final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
      return ConversationNotifier();
    });

/// SUGGESTIONS PROVIDER

/// Default suggestions list
const List<String> _defaultSuggestions = [
  "Looking for a bike under \$200",
  "Need study books for engineering",
  "Room for rent near campus",
  "Part-time job opportunities",
  "Selling my old laptop",
];

/// Provider for search suggestions
final suggestionsProvider = StateProvider<List<String>>(
  (ref) => _defaultSuggestions.take(3).toList(),
);

/// Provider to filter suggestions based on query
final filteredSuggestionsProvider = Provider.family<List<String>, String>((
  ref,
  query,
) {
  if (query.isEmpty) return _defaultSuggestions.take(3).toList();

  final filtered = _defaultSuggestions
      .where((s) => s.toLowerCase().contains(query.toLowerCase()))
      .toList();

  if (filtered.length < 3) {
    filtered.addAll(["Find roommates", "Buy/Sell items", "Study materials"]);
  }

  return filtered.take(3).toList();
});

/// USER INTENTS PROVIDER

/// Provider for user's intent history
final userIntentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final intents = await UniversalIntentService().getUserIntents(userId);
    return intents;
  } catch (e) {
    return [];
  }
});

/// CURRENT USER NAME PROVIDER

/// Provider for current user's display name
final currentUserNameProvider = FutureProvider<String>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 'User';

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      return doc.data()?['name'] ?? 'User';
    }
    return 'User';
  } catch (e) {
    return 'User';
  }
});

/// AI RESPONSE GENERATOR

/// Generate AI response based on user message
String generateAIResponse(String userMessage, String userName) {
  final message = userMessage.toLowerCase();
  final firstName = userName.split(' ')[0];

  if (message.contains('hello') ||
      message.contains('hi') ||
      message.contains('hey')) {
    return 'Hello $firstName! How can I help you find what you need today?';
  } else if (message.contains('bike') || message.contains('cycle')) {
    return 'Looking for a bike? I can help you find people selling or renting bicycles in your area. What\'s your budget?';
  } else if (message.contains('book') || message.contains('study')) {
    return 'Need books? Tell me which subject or specific books you\'re looking for, and I\'ll find students who have them.';
  } else if (message.contains('room') ||
      message.contains('hostel') ||
      message.contains('rent')) {
    return 'Looking for accommodation? I can connect you with people offering rooms or looking for roommates nearby.';
  } else if (message.contains('job') ||
      message.contains('work') ||
      message.contains('hire')) {
    return 'Job hunting? Let me know what kind of work you\'re looking for or if you\'re hiring, and I\'ll find relevant matches.';
  } else if (message.contains('sell') || message.contains('buy')) {
    return 'Looking to buy or sell something? Describe what you need, and I\'ll find the perfect match for you!';
  } else if (message.contains('thank') || message.contains('thanks')) {
    return 'You\'re welcome! Let me know if you need help with anything else.';
  } else if (message.contains('help')) {
    return 'I can help you find:\n• Items to buy/sell\n• Roommates\n• Study materials\n• Part-time jobs\n• Services\nJust tell me what you need!';
  } else {
    return 'I understand you\'re looking for: "$userMessage". Let me find the best matches for you in our community!';
  }
}

/// Check if message should trigger match processing
bool shouldProcessForMatches(String message) {
  final lowerMessage = message.toLowerCase();
  return lowerMessage.contains('bike') ||
      lowerMessage.contains('book') ||
      lowerMessage.contains('room') ||
      lowerMessage.contains('job') ||
      lowerMessage.contains('sell') ||
      lowerMessage.contains('buy') ||
      lowerMessage.contains('rent') ||
      lowerMessage.contains('hire') ||
      lowerMessage.contains('find') ||
      lowerMessage.contains('look');
}
