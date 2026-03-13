## 4. Frontend Architecture

### Architecture Pattern

The app follows a **Service-Oriented Architecture** with:
- **Singleton Services** for business logic (factory constructor pattern)
- **Riverpod Providers** for reactive state management
- **Firebase Streams** for real-time data
- **SQLite** for offline message caching

```
┌─────────────────────────────────────────────┐
│                  UI Layer                    │
│   Screens (62) + Widgets (18)               │
│   ConsumerStatefulWidget / StatefulWidget    │
├─────────────────────────────────────────────┤
│              State Layer                     │
│   Riverpod Providers (12)                   │
│   StreamProvider / FutureProvider / Provider │
├─────────────────────────────────────────────┤
│            Service Layer                     │
│   Singleton Services (34+)                  │
│   Business logic, API calls, AI processing  │
├─────────────────────────────────────────────┤
│             Data Layer                       │
│   Firebase (Firestore, Auth, Storage, FCM)  │
│   SQLite (offline message cache)            │
│   SharedPreferences (settings, device token)│
│   In-Memory Cache (LRU, embeddings)         │
├─────────────────────────────────────────────┤
│           External APIs                      │
│   Google Gemini AI (text + embeddings)      │
│   Geocoding APIs (OSM, BigDataCloud, etc.)  │
│   WebRTC STUN/TURN servers                  │
└─────────────────────────────────────────────┘
```

### Data Flow

```
User Input (text/voice)
    ↓
UnifiedPostService.createPost()
    ↓
GeminiService.analyzeIntent() → IntentAnalysis JSON
    ↓
GeminiService.generateEmbedding() → 768-dim vector
    ↓
Firestore: posts/{postId} (stored with embedding + keywords)
    ↓
UnifiedPostService.findMatches() → Cosine similarity + scoring
    ↓
Matched posts ranked and returned to UI
    ↓
RealtimeMatchingService → Push notification to matched users
```

### Navigation Architecture

**5-Tab Bottom Navigation** (`MainNavigationScreen`):

| Tab | Index | Screen | Purpose |
|-----|-------|--------|---------|
| Home | 0 | `HomeScreen` | AI-powered post feed + discovery |
| Messages | 1 | `ConversationsScreen` | Chats, Groups, Calls |
| Nearby | 4 | `NearByScreen` | Location-based post feed |
| Networking | 2 | `LiveConnectTabScreen` | People discovery + connections |
| Business | 3 | `BusinessHubScreen` | Business dashboard |

### App Initialization Flow

```
main()
  ├─ Load .env variables (flutter_dotenv)
  ├─ Firebase.initializeApp()
  ├─ FirebaseCrashlytics setup
  ├─ FCM background handler registration
  ├─ Firestore settings (50MB cache, persistence)
  └─ runApp(ProviderScope(child: MyApp()))
       ├─ MyApp: MaterialApp with theme from ThemeProvider
       ├─ SplashScreen (3-second animated logo)
       └─ AuthWrapper
            ├─ [Not authenticated] → OnboardingScreen → LoginScreen
            └─ [Authenticated] → MainNavigationScreen
                 ├─ _initializeUserServices()
                 │   ├─ ProfileService.ensureProfileExists()
                 │   ├─ AuthService.saveCurrentDeviceSession()
                 │   ├─ LocationService.initializeLocation()
                 │   ├─ Start periodic location updates
                 │   ├─ ConversationService.cleanupDuplicates()
                 │   └─ NotificationService.startListener()
                 └─ _startDeviceSessionMonitoring()
                      └─ Listen for force-logout signals
```

### Deferred Service Initialization

Heavy services are initialized after first frame render:
1. `AnalyticsService.initialize()`
2. `AppOptimizer.initialize()`
3. `MemoryManager.initialize()`
4. `UserManager.initialize()`
5. `NotificationService.initialize()`
6. `ConnectivityService.initialize()`

---

