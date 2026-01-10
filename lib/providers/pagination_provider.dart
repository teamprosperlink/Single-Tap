import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PAGINATION STATE

/// Generic pagination state that can be used with any data type
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    String? error,
    bool clearLastDocument = false,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: clearLastDocument
          ? null
          : (lastDocument ?? this.lastDocument),
      error: error,
    );
  }

  /// Check if we can load more
  bool get canLoadMore => !isLoading && !isLoadingMore && hasMore;

  /// Check if list is empty and not loading
  bool get isEmpty => items.isEmpty && !isLoading;

  /// Check if initial load is happening
  bool get isInitialLoading => isLoading && items.isEmpty;
}

/// PAGINATION NOTIFIER

/// Generic pagination notifier for Firestore collections
class PaginationNotifier<T> extends StateNotifier<PaginationState<T>> {
  final int pageSize;
  final Query Function() queryBuilder;
  final T Function(DocumentSnapshot doc) fromDocument;

  PaginationNotifier({
    required this.queryBuilder,
    required this.fromDocument,
    this.pageSize = 20,
  }) : super(const PaginationState());

  /// Load initial data
  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      clearLastDocument: true,
    );

    try {
      final query = queryBuilder().limit(pageSize);
      final snapshot = await query.get();

      final items = snapshot.docs.map((doc) => fromDocument(doc)).toList();

      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: snapshot.docs.length >= pageSize,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more data (pagination)
  Future<void> loadMore() async {
    if (!state.canLoadMore || state.lastDocument == null) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final query = queryBuilder()
          .startAfterDocument(state.lastDocument!)
          .limit(pageSize);
      final snapshot = await query.get();

      final newItems = snapshot.docs.map((doc) => fromDocument(doc)).toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        hasMore: snapshot.docs.length >= pageSize,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refresh the list (reload from beginning)
  Future<void> refresh() async {
    state = const PaginationState();
    await loadInitial();
  }

  /// Add item to the beginning of the list
  void prependItem(T item) {
    state = state.copyWith(items: [item, ...state.items]);
  }

  /// Add item to the end of the list
  void appendItem(T item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  /// Remove item from the list
  void removeItem(bool Function(T) test) {
    state = state.copyWith(
      items: state.items.where((item) => !test(item)).toList(),
    );
  }

  /// Update item in the list
  void updateItem(bool Function(T) test, T newItem) {
    state = state.copyWith(
      items: state.items.map((item) => test(item) ? newItem : item).toList(),
    );
  }

  /// Clear all items
  void clear() {
    state = const PaginationState();
  }
}

/// STREAM PAGINATION STATE

/// Pagination state for real-time streams
class StreamPaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int currentLimit;
  final String? error;

  const StreamPaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentLimit = 20,
    this.error,
  });

  StreamPaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentLimit,
    String? error,
  }) {
    return StreamPaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentLimit: currentLimit ?? this.currentLimit,
      error: error,
    );
  }
}

/// STREAM PAGINATION NOTIFIER

/// Pagination notifier for real-time Firestore streams
/// Increases limit to load more items while maintaining stream
class StreamPaginationNotifier<T>
    extends StateNotifier<StreamPaginationState<T>> {
  final int initialLimit;
  final int loadMoreIncrement;
  final Query Function(int limit) queryBuilder;
  final T Function(DocumentSnapshot doc) fromDocument;

  StreamPaginationNotifier({
    required this.queryBuilder,
    required this.fromDocument,
    this.initialLimit = 20,
    this.loadMoreIncrement = 20,
  }) : super(StreamPaginationState(currentLimit: initialLimit));

  /// Get the stream with current limit
  Stream<List<T>> getStream() {
    return queryBuilder(state.currentLimit).snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => fromDocument(doc)).toList();

      // Update hasMore based on results
      if (mounted) {
        final hasMore = snapshot.docs.length >= state.currentLimit;
        if (state.hasMore != hasMore) {
          state = state.copyWith(hasMore: hasMore);
        }
      }

      return items;
    });
  }

  /// Load more items by increasing the limit
  void loadMore() {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(
      currentLimit: state.currentLimit + loadMoreIncrement,
      isLoading: true,
    );

    // The stream will automatically update with new limit
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    });
  }

  /// Reset to initial limit
  void reset() {
    state = StreamPaginationState(currentLimit: initialLimit);
  }
}

/// HELPER EXTENSIONS

extension PaginationQueryExtension on Query {
  /// Apply pagination to a query
  Query paginate({required int limit, DocumentSnapshot? startAfter}) {
    Query query = this.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query;
  }
}

/// FACTORY FUNCTIONS

/// Create a pagination provider for a specific query
StateNotifierProvider<PaginationNotifier<T>, PaginationState<T>>
createPaginationProvider<T>({
  required Query Function() queryBuilder,
  required T Function(DocumentSnapshot doc) fromDocument,
  int pageSize = 20,
}) {
  return StateNotifierProvider<PaginationNotifier<T>, PaginationState<T>>((
    ref,
  ) {
    return PaginationNotifier<T>(
      queryBuilder: queryBuilder,
      fromDocument: fromDocument,
      pageSize: pageSize,
    );
  });
}

/// Create a family pagination provider (with parameter)
StateNotifierProviderFamily<PaginationNotifier<T>, PaginationState<T>, String>
createPaginationProviderFamily<T>({
  required Query Function(String param) queryBuilder,
  required T Function(DocumentSnapshot doc) fromDocument,
  int pageSize = 20,
}) {
  return StateNotifierProvider.family<
    PaginationNotifier<T>,
    PaginationState<T>,
    String
  >((ref, param) {
    return PaginationNotifier<T>(
      queryBuilder: () => queryBuilder(param),
      fromDocument: fromDocument,
      pageSize: pageSize,
    );
  });
}
