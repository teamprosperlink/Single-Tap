import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'other providers/app_providers.dart';

/// USER PROFILE STATE

/// State class for user profile
class UserProfileState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final bool isEditMode;
  final String? error;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.isEditMode = false,
    this.error,
  });

  UserProfileState copyWith({
    Map<String, dynamic>? profile,
    bool? isLoading,
    bool? isEditMode,
    String? error,
    bool clearProfile = false,
  }) {
    return UserProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isEditMode: isEditMode ?? this.isEditMode,
      error: error,
    );
  }

  String get name => profile?['name'] ?? 'User';
  String? get photoUrl => profile?['photoUrl'];
  String? get bio => profile?['bio'];
  String? get city => profile?['city'];
  String? get aboutMe => profile?['aboutMe'];
  List<String> get interests => List<String>.from(profile?['interests'] ?? []);
  List<String> get activities =>
      List<String>.from(profile?['activities'] ?? []);
  List<String> get connectionTypes =>
      List<String>.from(profile?['connectionTypes'] ?? []);
}

/// USER PROFILE NOTIFIER

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final String? userId;

  UserProfileNotifier(this.userId)
    : super(const UserProfileState(isLoading: true)) {
    // Auto-load profile when notifier is created
    if (userId != null) {
      loadProfile();
    }
  }

  /// Load user profile from Firestore
  Future<void> loadProfile() async {
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    // First, set basic info from Firebase Auth for immediate display
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && state.profile == null) {
      state = state.copyWith(
        profile: {
          'name': authUser.displayName ?? 'User',
          'email': authUser.email,
          'photoUrl': authUser.photoURL,
        },
        isLoading: true, // Still loading full profile
      );
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        state = state.copyWith(profile: doc.data(), isLoading: false);
      } else {
        // If no Firestore doc, keep Auth data but mark as not loading
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update profile data
  void updateProfile(Map<String, dynamic> data) {
    if (state.profile != null) {
      state = state.copyWith(profile: {...state.profile!, ...data});
    }
  }

  /// Set edit mode
  void setEditMode(bool value) {
    state = state.copyWith(isEditMode: value);
  }

  /// Save profile to Firestore
  Future<bool> saveProfile(Map<String, dynamic> updates) async {
    if (userId == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updates);

      updateProfile(updates);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear profile (on logout)
  void clearProfile() {
    state = const UserProfileState();
  }
}

/// Provider for user profile
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      return UserProfileNotifier(userId);
    });

/// SEARCH HISTORY STATE

/// State for user's search/intent history
class SearchHistoryState {
  final List<Map<String, dynamic>> history;
  final bool isLoading;
  final String? error;

  const SearchHistoryState({
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  SearchHistoryState copyWith({
    List<Map<String, dynamic>>? history,
    bool? isLoading,
    String? error,
  }) {
    return SearchHistoryState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SearchHistoryNotifier extends StateNotifier<SearchHistoryState> {
  final String? userId;

  SearchHistoryNotifier(this.userId)
    : super(const SearchHistoryState(isLoading: true)) {
    // Auto-load history when notifier is created
    if (userId != null) {
      loadHistory();
    } else {
      // No user, set loading to false
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load search history from Firestore
  Future<void> loadHistory() async {
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final history = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add new item to history
  void addHistoryItem(Map<String, dynamic> item) {
    state = state.copyWith(history: [item, ...state.history]);
  }

  /// Remove item from history
  void removeHistoryItem(String postId) {
    state = state.copyWith(
      history: state.history.where((h) => h['id'] != postId).toList(),
    );
  }

  /// Clear history
  void clearHistory() {
    state = const SearchHistoryState();
  }
}

/// Provider for search history
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, SearchHistoryState>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      return SearchHistoryNotifier(userId);
    });

/// USER POSTS PROVIDER

/// Stream provider for user's active posts
final userPostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

/// PROFILE EDIT STATE

/// State for profile editing form
class ProfileEditState {
  final List<String> selectedConnectionTypes;
  final List<String> selectedActivities;
  final String aboutMe;
  final bool isSaving;

  const ProfileEditState({
    this.selectedConnectionTypes = const [],
    this.selectedActivities = const [],
    this.aboutMe = '',
    this.isSaving = false,
  });

  ProfileEditState copyWith({
    List<String>? selectedConnectionTypes,
    List<String>? selectedActivities,
    String? aboutMe,
    bool? isSaving,
  }) {
    return ProfileEditState(
      selectedConnectionTypes:
          selectedConnectionTypes ?? this.selectedConnectionTypes,
      selectedActivities: selectedActivities ?? this.selectedActivities,
      aboutMe: aboutMe ?? this.aboutMe,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  ProfileEditNotifier() : super(const ProfileEditState());

  void setConnectionTypes(List<String> types) {
    state = state.copyWith(selectedConnectionTypes: types);
  }

  void toggleConnectionType(String type) {
    final current = List<String>.from(state.selectedConnectionTypes);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(selectedConnectionTypes: current);
  }

  void setActivities(List<String> activities) {
    state = state.copyWith(selectedActivities: activities);
  }

  void toggleActivity(String activity) {
    final current = List<String>.from(state.selectedActivities);
    if (current.contains(activity)) {
      current.remove(activity);
    } else {
      current.add(activity);
    }
    state = state.copyWith(selectedActivities: current);
  }

  void setAboutMe(String text) {
    state = state.copyWith(aboutMe: text);
  }

  void setSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }

  void loadFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return;

    state = ProfileEditState(
      selectedConnectionTypes: List<String>.from(
        profile['connectionTypes'] ?? [],
      ),
      selectedActivities: List<String>.from(profile['activities'] ?? []),
      aboutMe: profile['aboutMe'] ?? '',
    );
  }

  void reset() {
    state = const ProfileEditState();
  }
}

/// Provider for profile edit form state
final profileEditProvider =
    StateNotifierProvider<ProfileEditNotifier, ProfileEditState>((ref) {
      return ProfileEditNotifier();
    });
