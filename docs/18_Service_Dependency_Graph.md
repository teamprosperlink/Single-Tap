## 18. Service Dependency Graph

```
FirebaseProvider (InheritedWidget - Central Access)
│
├─→ GeminiService (AI Engine)
│   ├─→ UnifiedPostService (Post CRUD + Matching)
│   │   ├─→ UnifiedMatchingService (Advanced Matching)
│   │   ├─→ RealtimeMatchingService (Live Match Notifications)
│   │   ├─→ AccountTypeService (Post Limits)
│   │   └─→ CatalogService (Business Post Sync)
│   └─→ VoiceAssistantService (Voice AI)
│
├─→ AuthService (Authentication)
│   ├─→ ProfileService (Profile CRUD)
│   ├─→ UserManager (Profile Caching)
│   └─→ CurrentUserCache (Fast Profile Access)
│
├─→ LocationService (GPS + Periodic Updates)
│   └─→ GeocodingService (3-API Fallback)
│
├─→ ConversationService (1-on-1 Chat)
│   ├─→ ChatService (Low-Level Chat Ops)
│   ├─→ GroupChatService (Group Chats)
│   ├─→ HybridChatService (SQLite + Firebase Sync)
│   └─→ ActiveChatService (Active Chat Tracking)
│
├─→ NotificationService (FCM + Local)
│   ├─→ ConnectionService (User Connections)
│   ├─→ BookingService (Bookings)
│   └─→ ReviewService (Reviews/Ratings)
│
├─→ CacheService (LRU Caching)
│   └─→ PhotoCacheService (Photo URL Cache)
│
├─→ ConnectivityService (Network Monitoring)
│
├─→ VoiceCallService ──→ WebRTC (P2P Audio)
├─→ VideoCallService ──→ WebRTC (P2P Video)
├─→ GroupVoiceCallService ──→ WebRTC (Multi-Party Audio)
├─→ GroupVideoCallService ──→ WebRTC (Multi-Party Video)
├─→ FloatingCallService (PiP Overlay)
│
├─→ ErrorTrackingService (Firebase Crashlytics)
├─→ AnalyticsService (Firebase Analytics)
│
└─→ Riverpod Providers (Reactive State)
    ├─→ authStateProvider (Auth Stream)
    ├─→ currentUserIdProvider (Derived)
    ├─→ currentUserProfileStreamProvider (Firestore Stream)
    ├─→ connectivityProvider (Network Stream)
    └─→ themeProvider (StateNotifier)
```

---

