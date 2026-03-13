## 1. Executive Summary

**Supper** is an AI-powered semantic matching application built with Flutter. Users express intent in natural language (e.g., "I want to sell my iPhone" or "Looking for a gym partner"), and the Gemini AI engine dynamically understands intent, generates 768-dimensional embeddings, and matches people semantically - without any hardcoded categories.

### Core Differentiators

| Feature | Description |
|---------|-------------|
| **No Hardcoded Categories** | AI determines intent dynamically from natural language |
| **Semantic Matching** | 768-dim embeddings + cosine similarity for intelligent matching |
| **Complementary Intent** | Sellers are matched with buyers, seekers with offerers |
| **Real-Time Matching** | Live notifications when new posts match existing user intents |
| **Voice AI Assistant** | Full voice-driven interface with Gemini function calling |
| **Business Accounts** | Catalog, bookings, reviews, analytics for businesses |
| **WebRTC Calling** | Voice/video calls with P2P WebRTC + Firebase signaling |
| **Single-Device Auth** | WhatsApp-style single active device enforcement |

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           SUPPER APPLICATION                             │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                        PRESENTATION LAYER                        │    │
│  │                                                                  │    │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │    │
│  │   │  Auth     │  │  Home    │  │  Chat    │  │  Business    │   │    │
│  │   │  Screens  │  │  Screens │  │  Screens │  │  Screens     │   │    │
│  │   │  (6)      │  │  (10)    │  │  (10)    │  │  (14)        │   │    │
│  │   └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │    │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │    │
│  │   │  Profile  │  │  Call    │  │  E-Comm  │  │  Utility     │   │    │
│  │   │  Screens  │  │  Screens │  │  Screens │  │  Screens     │   │    │
│  │   │  (11)     │  │  (8)     │  │  (7)     │  │  (2)         │   │    │
│  │   └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │    │
│  │                                                                  │    │
│  │   ┌──────────────────────────────────────────────────────────┐   │    │
│  │   │              REUSABLE WIDGETS (18 files)                 │   │    │
│  │   │  Badges · Backgrounds · Chat · Input · Cards · Avatars  │   │    │
│  │   └──────────────────────────────────────────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                      STATE MANAGEMENT LAYER                      │    │
│  │                                                                  │    │
│  │   ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐    │    │
│  │   │ Riverpod    │  │ ChangeNotifier│  │ Direct Singleton   │    │    │
│  │   │ Providers   │  │ (VoiceAssist) │  │ Access             │    │    │
│  │   │ (12)        │  │              │  │ ServiceName()      │    │    │
│  │   └─────────────┘  └──────────────┘  └────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                       SERVICE LAYER (34+)                        │    │
│  │                                                                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │    │
│  │  │ AI       │ │ Auth     │ │ Chat     │ │ Business         │   │    │
│  │  │ Services │ │ Services │ │ Services │ │ Services         │   │    │
│  │  ├──────────┤ ├──────────┤ ├──────────┤ ├──────────────────┤   │    │
│  │  │ Gemini   │ │ Auth     │ │ Convers. │ │ Catalog          │   │    │
│  │  │ Intent   │ │ Profile  │ │ Hybrid   │ │ Booking          │   │    │
│  │  │ Matching │ │ UserMgr  │ │ Group    │ │ Review           │   │    │
│  │  │ Realtime │ │ Cache    │ │ Active   │ │ Connection       │   │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘   │    │
│  │                                                                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │    │
│  │  │ Call     │ │ Location │ │ Cache    │ │ Platform         │   │    │
│  │  │ Services │ │ Services │ │ Services │ │ Services         │   │    │
│  │  ├──────────┤ ├──────────┤ ├──────────┤ ├──────────────────┤   │    │
│  │  │ Voice    │ │ GPS      │ │ LRU     │ │ Notification     │   │    │
│  │  │ Video    │ │ Geocode  │ │ Photo   │ │ Analytics        │   │    │
│  │  │ Group    │ │ Periodic │ │ Embed   │ │ Connectivity     │   │    │
│  │  │ Floating │ │          │ │ Message │ │ Error Tracking   │   │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                         DATA LAYER                               │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────────┐  │    │
│  │  │                  FIREBASE PLATFORM                         │  │    │
│  │  │  Auth · Firestore · Storage · FCM · Crashlytics · Funcs  │  │    │
│  │  └────────────────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐  │    │
│  │  │ SQLite       │  │ SharedPreferences │  │ In-Memory Cache  │  │    │
│  │  │ (Offline     │  │ (Settings,        │  │ (LRU: Embed,     │  │    │
│  │  │  Messages)   │  │  DeviceToken)     │  │  Match, Photo)   │  │    │
│  │  └──────────────┘  └──────────────────┘  └──────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                      EXTERNAL SERVICES                           │    │
│  │  Google Gemini API · Geocoding APIs · WebRTC STUN/TURN          │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Firebase Integration Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    FIREBASE SERVICES MAP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FIREBASE AUTH ─────────────────────────────────────────────    │
│  │  Email/Password login                                        │
│  │  Google Sign-In (OAuth)                                      │
│  │  Phone OTP (SMS verification)                                │
│  │  Single-device session enforcement                           │
│  └─→ AuthService → ProfileService → UserManager                │
│                                                                 │
│  CLOUD FIRESTORE ───────────────────────────────────────────    │
│  │                                                              │
│  │  posts/                                                      │
│  │  ├── {postId}          ← AI intent, 768-dim embedding       │
│  │  │   └── matches/      ← match results with scores          │
│  │  │                                                           │
│  │  users/                                                      │
│  │  ├── {userId}          ← profile, location, account type    │
│  │  │   ├── catalog/      ← business items (products/services) │
│  │  │   └── notifications/← per-user notifications             │
│  │  │                                                           │
│  │  conversations/                                              │
│  │  ├── {convId}          ← participant IDs, last message      │
│  │  │   └── messages/     ← text, media, audio messages        │
│  │  │                                                           │
│  │  group_conversations/                                        │
│  │  ├── {groupId}         ← members, admins, group settings    │
│  │  │   └── messages/     ← group messages                     │
│  │  │                                                           │
│  │  connection_requests/  ← friend/network connection requests │
│  │  calls/                ← 1-on-1 call records                │
│  │  group_calls/          ← group call records                 │
│  │  reviews/              ← business review records            │
│  │  bookings/             ← service booking records            │
│  │  └── Real-time via StreamBuilder + StreamSubscription       │
│  │                                                              │
│  FIREBASE STORAGE ──────────────────────────────────────────    │
│  │  profile_images/       ← user profile photos                │
│  │  chat_images/          ← chat media (images, videos)        │
│  │  chat_audio/           ← voice messages                     │
│  │  catalog_images/       ← business catalog item photos       │
│  │  group_photos/         ← group chat photos                  │
│  │  └── Compressed before upload (image_compress, video_comp)  │
│  │                                                              │
│  FIREBASE MESSAGING (FCM) ──────────────────────────────────    │
│  │  Push notifications for: new matches, messages, bookings    │
│  │  Background message handler registered in main()            │
│  │  Token stored in users/{userId}/fcmToken                    │
│  │                                                              │
│  FIREBASE CRASHLYTICS ──────────────────────────────────────    │
│  │  Automatic crash reporting + custom error tracking           │
│  │                                                              │
│  FIREBASE ANALYTICS ────────────────────────────────────────    │
│  │  Screen views, user actions, business events                 │
│  │                                                              │
│  CLOUD FUNCTIONS ───────────────────────────────────────────    │
│     Force logout (single-device enforcement)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Gemini AI Integration Map

```
┌──────────────────────────────────────────────────────────────────┐
│                      GEMINI AI INTEGRATION                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐     ┌──────────────────────────────────────┐    │
│  │  User Input  │────→│         GeminiService                │    │
│  │  "I need a   │     │                                      │    │
│  │   plumber"   │     │  Model: gemini-2.5-flash             │    │
│  └─────────────┘     │  Embedding: gemini-embedding-001     │    │
│                       │                                      │    │
│                       │  ┌──────────────────────────────┐    │    │
│                       │  │  analyzeIntent(text)         │    │    │
│                       │  │  → Structured JSON response  │    │    │
│                       │  │    action_type: "seeking"    │    │    │
│                       │  │    domain: "home_services"   │    │    │
│                       │  │    keywords: ["plumber",     │    │    │
│                       │  │      "repair", "pipe"]       │    │    │
│                       │  └──────────┬───────────────────┘    │    │
│                       │             │                        │    │
│                       │  ┌──────────▼───────────────────┐    │    │
│                       │  │  generateEmbedding(text)     │    │    │
│                       │  │  → 768-dimensional vector    │    │    │
│                       │  │  → Cached for 24 hours       │    │    │
│                       │  └──────────┬───────────────────┘    │    │
│                       │             │                        │    │
│                       │  ┌──────────▼───────────────────┐    │    │
│                       │  │  chatWithGemini(context)     │    │    │
│                       │  │  → Conversational AI chat    │    │    │
│                       │  │  → Function calling support  │    │    │
│                       │  └──────────────────────────────┘    │    │
│                       └──────────────────────────────────────┘    │
│                                      │                            │
│          ┌───────────────────────────┼───────────────────┐        │
│          │                           │                   │        │
│          ▼                           ▼                   ▼        │
│  ┌───────────────┐  ┌────────────────────┐  ┌───────────────┐    │
│  │ UnifiedPost   │  │ UnifiedMatching    │  │ VoiceAssistant│    │
│  │ Service       │  │ Service            │  │ Service       │    │
│  │               │  │                    │  │               │    │
│  │ Create post   │  │ Cosine similarity  │  │ Voice chat    │    │
│  │ with AI       │  │ Keyword overlap    │  │ with Gemini   │    │
│  │ analysis      │  │ Intent bonus       │  │ function      │    │
│  │               │  │ Location bonus     │  │ calling       │    │
│  └───────────────┘  └────────────────────┘  └───────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    SCORING PIPELINE                       │    │
│  │                                                          │    │
│  │  Step 1: cosine_similarity(search_embedding, post_emb)  │    │
│  │          ↓                                               │    │
│  │  Step 2: keyword_score = shared_keywords / total × 0.70  │    │
│  │          ↓                                               │    │
│  │  Step 3: relevance = max(semantic, keyword_score)        │    │
│  │          ↓                                               │    │
│  │  Step 4: + intent_bonus (0.15) if offer ↔ seek          │    │
│  │          + location_bonus (score × 0.05)                 │    │
│  │          - lifestyle_penalty (0.15) if clash             │    │
│  │          - domain_penalty (0.10) if mismatch             │    │
│  │          ↓                                               │    │
│  │  Step 5: Surface if final_score ≥ 0.60                  │    │
│  │          Push notification if ≥ 0.65                     │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### User Journey Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER JOURNEY MAP                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ONBOARDING ────────────────────────────────────────────────────     │
│  │                                                                   │
│  │  Splash (3s) → Onboarding (4 pages) → Choose Account Type        │
│  │  → Login (email/phone/Google) → OTP Verify → Device Check        │
│  │  → [If conflict] Device Login Dialog → Force Logout Other         │
│  │  → Main Navigation (5 tabs)                                       │
│  │                                                                   │
│  POST & MATCH ──────────────────────────────────────────────────     │
│  │                                                                   │
│  │  Type/Speak intent → AI analyzes → Post created with embedding    │
│  │  → Matches found → Results displayed as cards                     │
│  │  → Tap match → View profile OR Start chat                         │
│  │  → [Background] RealtimeMatching pushes notifications             │
│  │                                                                   │
│  MESSAGING ─────────────────────────────────────────────────────     │
│  │                                                                   │
│  │  Conversations tab → Tap chat → EnhancedChatScreen                │
│  │  → Send text/image/video/audio → Real-time delivery               │
│  │  → [Offline] SQLite cache → Sync when online                      │
│  │  → Voice/Video call → WebRTC P2P connection                       │
│  │  → [Group] Create group → Group chat + group calls                │
│  │                                                                   │
│  NETWORKING ────────────────────────────────────────────────────     │
│  │                                                                   │
│  │  LiveConnect tab → Browse nearby users → Filter by interests      │
│  │  → Send connection request → Accept/Reject                        │
│  │  → Connected → Can chat directly                                  │
│  │                                                                   │
│  BUSINESS ──────────────────────────────────────────────────────     │
│  │                                                                   │
│  │  Enable business → Set info & hours → Add catalog items           │
│  │  → Items auto-synced to matchable posts                           │
│  │  → Receive bookings → Confirm/Complete/Cancel                     │
│  │  → View reviews & profile analytics                               │
│  │  → Public profile visible to all users                            │
│  │                                                                   │
│  E-COMMERCE ────────────────────────────────────────────────────     │
│  │                                                                   │
│  │  Browse products → Product detail → Add to cart                   │
│  │  → Checkout → Order confirmation → Track order                    │
│  │                                                                   │
│  PROFILE ───────────────────────────────────────────────────────     │
│     Edit profile → Upload photo → Set location → Update bio          │
│     → Settings → Theme, Notifications, Privacy, Terms                │
│     → Upgrade plan → Business features                               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### State Management Flow Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT ARCHITECTURE                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  RIVERPOD PROVIDERS                                                │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │                                                          │     │
│  │  StreamProviders (Real-time Firestore)                   │     │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │     │
│  │  │ authStateProvider │→│ Firebase Auth state stream    │ │     │
│  │  └──────────────────┘  └──────────────────────────────┘ │     │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │     │
│  │  │ currentUserProfile│→│ users/{uid} Firestore stream │ │     │
│  │  │ StreamProvider    │  └──────────────────────────────┘ │     │
│  │  └──────────────────┘                                    │     │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │     │
│  │  │ connectivityProv.│→│ Connectivity plugin stream    │ │     │
│  │  └──────────────────┘  └──────────────────────────────┘ │     │
│  │                                                          │     │
│  │  FutureProviders (One-time fetches)                      │     │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │     │
│  │  │ currentUserId    │→│ Derived from authState        │ │     │
│  │  │ Provider         │  └──────────────────────────────┘ │     │
│  │  └──────────────────┘                                    │     │
│  │                                                          │     │
│  │  StateNotifierProviders (Mutable state)                  │     │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐ │     │
│  │  │ themeProvider    │→│ ThemeNotifier (light/dark)    │ │     │
│  │  └──────────────────┘  └──────────────────────────────┘ │     │
│  │                                                          │     │
│  └──────────────────────────────────────────────────────────┘     │
│                              │                                     │
│                              ▼                                     │
│  SCREEN CONSUMPTION                                                │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │  ConsumerStatefulWidget                                  │     │
│  │  ┌──────────────────────────────────────────────────┐   │     │
│  │  │  ref.watch(authStateProvider)  → rebuild on auth  │   │     │
│  │  │  ref.watch(themeProvider)      → rebuild on theme │   │     │
│  │  │  ref.read(currentUserIdProv.)  → one-time read    │   │     │
│  │  └──────────────────────────────────────────────────┘   │     │
│  │                                                          │     │
│  │  StatefulWidget + Direct Service Access                  │     │
│  │  ┌──────────────────────────────────────────────────┐   │     │
│  │  │  CatalogService()     → singleton factory         │   │     │
│  │  │  ConversationService() → singleton factory         │   │     │
│  │  │  LocationService()     → singleton factory         │   │     │
│  │  │  setState() for local UI state                     │   │     │
│  │  └──────────────────────────────────────────────────┘   │     │
│  └──────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────┘
```

### Account Types

| Type | Features | Post Limit |
|------|----------|------------|
| `personal` | Basic matching, messaging, voice search | 5/day |
| `business` | Catalog, bookings, reviews, analytics, business hours | Unlimited |

---

