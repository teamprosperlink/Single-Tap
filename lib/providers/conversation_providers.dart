import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import 'other providers/app_providers.dart';

/// CONVERSATIONS SCREEN STATE

/// State class for conversations screen UI
class ConversationsScreenState {
  final bool isSearching;
  final String searchQuery;
  final String? error;

  const ConversationsScreenState({
    this.isSearching = false,
    this.searchQuery = '',
    this.error,
  });

  ConversationsScreenState copyWith({
    bool? isSearching,
    String? searchQuery,
    String? error,
  }) {
    return ConversationsScreenState(
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
    );
  }
}

/// CONVERSATIONS SCREEN NOTIFIER

class ConversationsScreenNotifier
    extends StateNotifier<ConversationsScreenState> {
  ConversationsScreenNotifier() : super(const ConversationsScreenState());

  void setSearching(bool value) {
    state = state.copyWith(isSearching: value);
    if (!value) {
      state = state.copyWith(searchQuery: '');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.toLowerCase());
  }

  void toggleSearch() {
    final newIsSearching = !state.isSearching;
    state = state.copyWith(
      isSearching: newIsSearching,
      searchQuery: newIsSearching ? state.searchQuery : '',
    );
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void reset() {
    state = const ConversationsScreenState();
  }
}

/// Provider for conversations screen UI state
final conversationsScreenProvider =
    StateNotifierProvider<
      ConversationsScreenNotifier,
      ConversationsScreenState
    >((ref) {
      return ConversationsScreenNotifier();
    });

/// CONVERSATIONS STREAM PROVIDER

/// Stream provider for user's conversations
final conversationsStreamProvider = StreamProvider<List<ConversationModel>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participants', arrayContains: userId)
      .snapshots()
      .map((snapshot) {
        final conversations = <ConversationModel>[];

        for (var doc in snapshot.docs) {
          try {
            final conv = ConversationModel.fromFirestore(doc);
            conversations.add(conv);
          } catch (e) {
            // Skip invalid conversations
          }
        }

        // Sort by lastMessageTime (most recent first)
        conversations.sort((a, b) {
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });

        return conversations;
      });
});

/// FILTERED CONVERSATIONS PROVIDER

/// Provider that filters conversations based on search query
final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationModel>>>((ref) {
      final conversationsAsync = ref.watch(conversationsStreamProvider);
      final screenState = ref.watch(conversationsScreenProvider);
      final userId = ref.watch(currentUserIdProvider);

      return conversationsAsync.whenData((conversations) {
        if (screenState.searchQuery.isEmpty) {
          return conversations;
        }

        return conversations.where((conv) {
          final displayName = conv.getDisplayName(userId ?? '');
          return displayName.toLowerCase().contains(screenState.searchQuery);
        }).toList();
      });
    });

/// USER ONLINE STATUS PROVIDER

/// Stream provider for a user's online status
final userOnlineStatusStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, userId) {
      if (userId.isEmpty) {
        return Stream.value({'isOnline': false, 'lastSeen': null});
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              return {'isOnline': false, 'lastSeen': null};
            }

            final data = snapshot.data()!;
            return {
              'isOnline': data['isOnline'] ?? false,
              'showOnlineStatus': data['showOnlineStatus'] ?? true,
              'lastSeen': data['lastSeen'],
              'name': data['name'],
              'photoUrl': data['photoUrl'],
            };
          });
    });

/// CONVERSATION PARTICIPANT CACHE

/// Cache for participant data to avoid repeated Firestore queries
class ParticipantCacheState {
  final Map<String, Map<String, dynamic>> cache;
  final bool isLoading;

  const ParticipantCacheState({this.cache = const {}, this.isLoading = false});

  ParticipantCacheState copyWith({
    Map<String, Map<String, dynamic>>? cache,
    bool? isLoading,
  }) {
    return ParticipantCacheState(
      cache: cache ?? this.cache,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ParticipantCacheNotifier extends StateNotifier<ParticipantCacheState> {
  ParticipantCacheNotifier() : super(const ParticipantCacheState());

  void cacheParticipant(String odlalud, Map<String, dynamic> data) {
    state = state.copyWith(cache: {...state.cache, odlalud: data});
  }

  Map<String, dynamic>? getParticipant(String userId) {
    return state.cache[userId];
  }

  Future<Map<String, dynamic>?> fetchAndCacheParticipant(String userId) async {
    // Check cache first
    if (state.cache.containsKey(userId)) {
      return state.cache[userId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        cacheParticipant(userId, data);
        return data;
      }
    } catch (e) {
      // Ignore errors
    }

    return null;
  }

  void clearCache() {
    state = const ParticipantCacheState();
  }
}

/// Provider for participant data cache
final participantCacheProvider =
    StateNotifierProvider<ParticipantCacheNotifier, ParticipantCacheState>((
      ref,
    ) {
      return ParticipantCacheNotifier();
    });

/// UNREAD COUNT PROVIDER

/// Provider for total unread message count
final totalUnreadCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(conversationsStreamProvider);
  final userId = ref.watch(currentUserIdProvider);

  return conversationsAsync.maybeWhen(
    data: (conversations) {
      if (userId == null) return 0;

      int total = 0;
      for (final conv in conversations) {
        total += conv.getUnreadCount(userId);
      }
      return total;
    },
    orElse: () => 0,
  );
});

/// HELPER FUNCTIONS

/// Format last seen timestamp to human-readable string
String formatLastSeen(dynamic lastSeen) {
  if (lastSeen == null) return 'Offline';

  if (lastSeen is Timestamp) {
    final lastSeenTime = lastSeen.toDate();
    final difference = DateTime.now().difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'Offline';
    }
  }

  return 'Offline';
}
