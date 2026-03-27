## 6. Services & Business Logic

All core services follow the **singleton pattern**:

```dart
class ServiceName {
  static final ServiceName _instance = ServiceName._internal();
  factory ServiceName() => _instance;
  ServiceName._internal();
}
```

### Service Inventory

#### Core Services

| Service | File | Purpose |
|---------|------|---------|
| FirebaseProvider | firebase_provider.dart | Central Firebase access (InheritedWidget) |
| AuthService | auth_service.dart | Email/Google/Phone auth + device sessions |
| ProfileService | profile_services/profile_service.dart | Profile CRUD + photo uploads |
| UserManager | user_manager.dart | Profile caching with real-time stream |
| CurrentUserCache | current_user_cache.dart | Fast access to current user data |
| AccountTypeService | account_type_service.dart | Account type upgrade/management |

#### AI & Matching Services

| Service | File | Purpose |
|---------|------|---------|
| GeminiService | ai_services/gemini_service.dart | Gemini AI (generation + embeddings) |
| UnifiedPostService | unified_post_service.dart | Post CRUD + match finding (primary) |
| UnifiedMatchingService | unified_matching_service.dart | Advanced multi-factor matching |
| UniversalIntentService | universal_intent_service.dart | High-level intent wrapper |
| RealtimeMatchingService | realtime_matching_service.dart | Real-time match notifications |
| VoiceAssistantService | voice_assistant_service.dart | Voice AI with function calling |

#### Chat & Communication

| Service | File | Purpose |
|---------|------|---------|
| ConversationService | chat_services/conversation_service.dart | 1-on-1 conversation management |
| ChatService | chat_services/chat_service.dart | Low-level chat operations |
| GroupChatService | group_chat_service.dart | Multi-user group chats |
| HybridChatService | hybrid_chat_service.dart | SQLite + Firebase message sync |
| ActiveChatService | active_chat_service.dart | Track active conversation (suppress notifications) |

#### Call Services

| Service | File | Purpose |
|---------|------|---------|
| VoiceCallService | other_services/voice_call_service.dart | 1-on-1 WebRTC voice calls |
| VideoCallService | other_services/video_call_service.dart | 1-on-1 WebRTC video calls |
| GroupVoiceCallService | other_services/group_voice_call_service.dart | Group audio conferences |
| GroupVideoCallService | other_services/group_video_call_service.dart | Group video conferences |
| FloatingCallService | floating_call_service.dart | PiP call overlay |

#### Business Services

| Service | File | Purpose |
|---------|------|---------|
| CatalogService | catalog_service.dart | Business catalog management (100 items max) |
| BookingService | booking_service.dart | Appointment/booking management |
| ReviewService | review_service.dart | Reviews and ratings |

#### Infrastructure Services

| Service | File | Purpose |
|---------|------|---------|
| LocationService | location_services/location_service.dart | GPS + periodic location updates |
| GeocodingService | location_services/geocoding_service.dart | Reverse geocoding (3 API fallbacks) |
| ConnectivityService | connectivity_service.dart | Network status monitoring |
| ConnectionService | connection_service.dart | User connection requests |
| NotificationService | notification_service.dart | FCM + local notifications |
| CacheService | cache_services/cache_service.dart | LRU caching (embeddings, matches) |
| PhotoCacheService | profile_services/photo_cache_service.dart | Photo URL caching |
| AnalyticsService | analytics_service.dart | Firebase Analytics events |
| ErrorTrackingService | error_services/error_tracking_service.dart | Firebase Crashlytics |

---

