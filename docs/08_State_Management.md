## 8. State Management (Riverpod)

### Provider Inventory

#### App Providers (`lib/providers/other providers/app_providers.dart`)

| Provider | Type | Data | Dependencies |
|----------|------|------|-------------|
| authStateProvider | StreamProvider\<User?\> | Firebase auth state | None |
| currentUserIdProvider | Provider\<String?\> | Current user UID | authStateProvider |
| currentUserProfileProvider | FutureProvider\<UserProfile?\> | One-time profile fetch | currentUserIdProvider |
| currentUserProfileStreamProvider | StreamProvider\<UserProfile?\> | Real-time profile | currentUserIdProvider |
| connectivityProvider | StreamProvider\<bool\> | Network status | ConnectivityService |
| isOnlineProvider | Provider\<bool\> | Sync online status | connectivityProvider |
| userOnlineStatusProvider | StreamProvider.family\<bool, String\> | Any user's online status | userId param |
| userProfileByIdProvider | FutureProvider.family\<UserProfile?, String\> | Any user's profile | userId param |
| userProfileStreamByIdProvider | StreamProvider.family\<UserProfile?, String\> | Any user's profile (stream) | userId param |
| firebaseAuthProvider | Provider\<FirebaseAuth\> | FirebaseAuth instance | None |
| firestoreProvider | Provider\<FirebaseFirestore\> | Firestore instance | None |

#### Theme Provider (`lib/providers/other providers/theme_provider.dart`)

| Provider | Type | Data |
|----------|------|------|
| themeProvider | StateNotifierProvider\<ThemeNotifier, ThemeState\> | Dark/glassmorphism theme |

### State Management Patterns

**Pattern 1: Layered Providers**
```
Base:     authStateProvider (Firebase stream)
Derived:  currentUserIdProvider (extracts UID)
Derived:  currentUserProfileStreamProvider (Firestore document stream)
Consumer: UI widgets watch for reactive updates
```

**Pattern 2: Family Providers for Parameterization**
```dart
// View any user's online status
ref.watch(userOnlineStatusProvider('otherUserId'))

// View any user's profile
ref.watch(userProfileByIdProvider('otherUserId'))
```

**Pattern 3: ConsumerStatefulWidget**
```dart
class ScreenName extends ConsumerStatefulWidget {
  ConsumerState<ScreenName> createState() => _ScreenNameState();
}

class _ScreenNameState extends ConsumerState<ScreenName> {
  String? get _userId => ref.read(currentUserIdProvider);  // One-time read

  Widget build(BuildContext context) {
    ref.watch(themeProvider);  // Reactive rebuild on theme change
  }
}
```

### Screens Using Riverpod

| Screen | Providers Consumed |
|--------|-------------------|
| SettingsScreen | themeProvider, currentUserIdProvider |
| GroupChatScreen | currentUserIdProvider |
| ProfileWithHistoryScreen | themeProvider |
| LiveConnectTabScreen | themeProvider |
| EnhancedChatScreen | currentUserIdProvider |
| LocationSettingsScreen | (imports providers) |
| GroupInfoScreen | (imports providers) |
| CreateGroupScreen | (imports providers) |

### Additional State Patterns

- **ChangeNotifier**: `VoiceAssistantService` extends ChangeNotifier for observable voice state (listening, processing, speaking)
- **Direct Singleton Access**: Most screens access services directly via `ServiceName()` factory constructors
- **SharedPreferences**: Theme persistence, device tokens, location preferences

---

