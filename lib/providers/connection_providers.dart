import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'other providers/app_providers.dart';

/// PENDING REQUESTS PROVIDER

/// Stream provider for pending connection requests (received)
final pendingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('connection_requests')
      .where('receiverId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

/// Stream provider for pending requests count
final pendingRequestsCountProvider = Provider<int>((ref) {
  final requestsAsync = ref.watch(pendingRequestsProvider);
  return requestsAsync.when(
    data: (requests) => requests.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// SENT REQUESTS PROVIDER

/// Stream provider for sent connection requests
final sentRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('connection_requests')
      .where('senderId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

/// MY CONNECTIONS PROVIDER

/// State class for connections
class MyConnectionsState {
  final List<String> connectionIds;
  final List<Map<String, dynamic>> connections;
  final bool isLoading;
  final String? error;

  const MyConnectionsState({
    this.connectionIds = const [],
    this.connections = const [],
    this.isLoading = false,
    this.error,
  });

  MyConnectionsState copyWith({
    List<String>? connectionIds,
    List<Map<String, dynamic>>? connections,
    bool? isLoading,
    String? error,
  }) {
    return MyConnectionsState(
      connectionIds: connectionIds ?? this.connectionIds,
      connections: connections ?? this.connections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MyConnectionsNotifier extends StateNotifier<MyConnectionsState> {
  final String? userId;

  MyConnectionsNotifier(this.userId) : super(const MyConnectionsState());

  /// Load connections from user document
  Future<void> loadConnections() async {
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get user's connection IDs
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final connectionIds = List<String>.from(
        userDoc.data()?['connections'] ?? [],
      );

      if (connectionIds.isEmpty) {
        state = state.copyWith(
          connectionIds: [],
          connections: [],
          isLoading: false,
        );
        return;
      }

      // Fetch connection profiles in batches of 10
      final connections = <Map<String, dynamic>>[];
      for (var i = 0; i < connectionIds.length; i += 10) {
        final batch = connectionIds.skip(i).take(10).toList();
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['uid'] = doc.id;
          connections.add(data);
        }
      }

      state = state.copyWith(
        connectionIds: connectionIds,
        connections: connections,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add a connection
  void addConnection(String connectionId, Map<String, dynamic> profile) {
    if (!state.connectionIds.contains(connectionId)) {
      state = state.copyWith(
        connectionIds: [...state.connectionIds, connectionId],
        connections: [...state.connections, profile],
      );
    }
  }

  /// Remove a connection
  void removeConnection(String connectionId) {
    state = state.copyWith(
      connectionIds: state.connectionIds
          .where((id) => id != connectionId)
          .toList(),
      connections: state.connections
          .where((c) => c['uid'] != connectionId)
          .toList(),
    );
  }

  /// Refresh connections
  Future<void> refresh() async {
    state = const MyConnectionsState();
    await loadConnections();
  }

  /// Clear state
  void clear() {
    state = const MyConnectionsState();
  }
}

/// Provider for my connections
final myConnectionsProvider =
    StateNotifierProvider<MyConnectionsNotifier, MyConnectionsState>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      return MyConnectionsNotifier(userId);
    });

/// Provider for connections count
final connectionsCountProvider = Provider<int>((ref) {
  return ref.watch(myConnectionsProvider).connectionIds.length;
});

/// CONNECTION REQUEST ACTIONS

/// State for request processing
class RequestActionState {
  final Set<String> processingIds;
  final String? error;

  const RequestActionState({this.processingIds = const {}, this.error});

  RequestActionState copyWith({Set<String>? processingIds, String? error}) {
    return RequestActionState(
      processingIds: processingIds ?? this.processingIds,
      error: error,
    );
  }

  bool isProcessing(String requestId) => processingIds.contains(requestId);
}

class RequestActionNotifier extends StateNotifier<RequestActionState> {
  RequestActionNotifier() : super(const RequestActionState());

  void startProcessing(String requestId) {
    state = state.copyWith(processingIds: {...state.processingIds, requestId});
  }

  void stopProcessing(String requestId) {
    state = state.copyWith(
      processingIds: state.processingIds.where((id) => id != requestId).toSet(),
    );
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for request action state
final requestActionProvider =
    StateNotifierProvider<RequestActionNotifier, RequestActionState>((ref) {
      return RequestActionNotifier();
    });
