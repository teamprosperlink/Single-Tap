# Supper App - Complete Technical Documentation

> **Version:** 1.0.0+1 | **Last Updated:** March 10, 2026
> **Platform:** Flutter 3.35.7 / Dart 3.9.2 | **Backend:** Firebase | **AI Engine:** Google Gemini

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Tech Stack & Libraries](#2-tech-stack--libraries)
3. [Project Structure](#3-project-structure)
4. [Frontend Architecture](#4-frontend-architecture)
5. [Data Models & Database Schema](#5-data-models--database-schema)
6. [Services & Business Logic](#6-services--business-logic)
7. [AI / Matching Pipeline](#7-ai--matching-pipeline)
8. [State Management (Riverpod)](#8-state-management-riverpod)
9. [Screens & User Flows](#9-screens--user-flows)
10. [Reusable Widgets & Components](#10-reusable-widgets--components)
11. [Authentication & Security](#11-authentication--security)
12. [Theming & Design System](#12-theming--design-system)
13. [Platform Configuration & Device Compatibility](#13-platform-configuration--device-compatibility)
14. [CI/CD Pipeline](#14-cicd-pipeline)
15. [Testing Strategy](#15-testing-strategy)
16. [Performance & Optimization](#16-performance--optimization)
17. [API Configuration & Environment](#17-api-configuration--environment)
18. [Service Dependency Graph](#18-service-dependency-graph)

---

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

## 2. Tech Stack & Libraries

### Core Framework

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter | 3.35.7 |
| Language | Dart | 3.9.2 |
| State Management | Riverpod | 2.6.1 |
| Backend | Firebase | Multi-service |
| AI Engine | Google Gemini | gemini-2.5-flash |
| Embeddings | Gemini Embedding | gemini-embedding-001 |

### Firebase Services (8 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| firebase_core | ^3.8.0 | Core initialization |
| firebase_auth | ^5.3.3 | Authentication (email, Google, phone) |
| cloud_firestore | ^5.4.4 | NoSQL database |
| cloud_functions | ^5.6.2 | Cloud Functions (force logout) |
| firebase_storage | ^12.3.4 | File/media storage |
| firebase_messaging | ^15.1.4 | Push notifications (FCM) |
| firebase_crashlytics | ^4.2.1 | Crash reporting |
| firebase_analytics | ^11.3.3 | Usage analytics |

### AI & Machine Learning

| Package | Version | Purpose |
|---------|---------|---------|
| google_generative_ai | ^0.4.7 | Gemini AI (generation + embeddings) |
| speech_to_text | ^7.3.0 | Voice input transcription |
| flutter_tts | ^4.2.5 | Text-to-speech output |

### Real-Time Communication

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_webrtc | ^0.12.5 | P2P voice/video calls |
| flutter_callkit_incoming | ^3.0.0 | Native call UI (iOS CallKit, Android) |
| flutter_ringtone_player | ^4.0.0+4 | Ringtone for incoming calls |

### Networking & HTTP

| Package | Version | Purpose |
|---------|---------|---------|
| http | ^1.2.2 | HTTP client (geocoding APIs) |
| dio | ^5.7.0 | Advanced HTTP (media upload/download) |

### Location & Geolocation

| Package | Version | Purpose |
|---------|---------|---------|
| geolocator | ^13.0.2 | GPS positioning |
| geocoding | ^3.0.0 | Reverse geocoding (coordinates → address) |

### Media Handling (7 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| cached_network_image | ^3.4.1 | Image caching with placeholders |
| image_picker | ^1.1.2 | Camera/gallery image selection |
| video_player | ^2.9.2 | Video playback |
| chewie | ^1.8.5 | Video player controls |
| flutter_image_compress | ^2.3.0 | Image compression before upload |
| video_compress | ^3.1.2 | Video compression before upload |
| file_picker | ^8.1.4 | File selection (documents, etc.) |

### Audio

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_sound | ^9.16.3 | Voice message recording |
| audioplayers | ^6.1.0 | Audio playback |

### Notifications

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_local_notifications | ^18.0.1 | Local notification display |

### UI/UX Components (8 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| cupertino_icons | ^1.0.8 | iOS-style icons |
| badges | ^3.1.2 | Badge indicators |
| shimmer | ^3.0.0 | Loading shimmer effects |
| flutter_chat_bubble | ^2.0.2 | Chat bubble styling |
| lottie | ^3.3.2 | Lottie animations |
| google_fonts | ^8.0.1 | Google Fonts (Poppins) |
| font_awesome_flutter | ^10.12.0 | FontAwesome icons |
| fl_chart | ^0.69.0 | Charts/data visualization |

### Device & Platform

| Package | Version | Purpose |
|---------|---------|---------|
| permission_handler | ^11.3.1 | Runtime permissions |
| device_info_plus | ^11.3.3 | Device identification |
| package_info_plus | ^8.0.3 | App version info |
| connectivity_plus | ^6.0.5 | Network monitoring |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| uuid | ^4.5.2 | Unique ID generation |
| url_launcher | ^6.3.1 | Open URLs/apps |
| shared_preferences | ^2.3.2 | Key-value local storage |
| path_provider | ^2.1.4 | File system paths |
| timeago | 3.7.0 | Relative timestamps |
| share_plus | ^10.1.4 | Native share sheet |
| open_filex | ^4.5.0 | Open files with native apps |
| mime | ^2.0.0 | MIME type detection |
| intl | ^0.19.0 | Internationalization |
| emoji_picker_flutter | ^4.3.0 | Emoji selection UI |
| flutter_dotenv | ^5.1.0 | Environment variables |

### Local Storage

| Package | Version | Purpose |
|---------|---------|---------|
| sqflite | ^2.3.0 | SQLite (offline message cache) |
| path | ^1.9.0 | Path manipulation |

### PDF

| Package | Version | Purpose |
|---------|---------|---------|
| syncfusion_flutter_pdf | ^28.1.33 | PDF generation/viewing |

### Development Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_test | SDK | Widget/unit testing |
| integration_test | SDK | Integration testing |
| flutter_launcher_icons | ^0.13.1 | App icon generation |
| flutter_lints | ^3.0.2 | Code linting rules |
| mockito | ^5.4.4 | Mock objects for testing |
| fake_cloud_firestore | ^3.1.0 | Firestore mocks |

**Total: 55+ dependencies**

---

## 3. Project Structure

```
lib/
├── main.dart                              # App entry + AuthWrapper + SplashScreen
├── main_web.dart                          # Web-specific entry point
├── firebase_options.dart                  # Firebase config (from .env)
│
├── config/
│   └── app_theme.dart                     # Theme constants, spacing, colors
│
├── database/
│   └── message_database.dart              # SQLite message cache (offline)
│
├── mixins/
│   └── voice_search_mixin.dart            # Voice search for any screen
│
├── models/                                # Data models (15 files)
│   ├── base/
│   │   ├── base_category_model.dart       # Abstract category base
│   │   ├── base_order_item.dart           # Abstract order item base
│   │   └── priceable_mixin.dart           # Price formatting mixin
│   ├── booking_model.dart                 # Bookings
│   ├── catalog_item.dart                  # Products/services
│   ├── conversation_model.dart            # Chat conversations
│   ├── extended_user_profile.dart         # Discovery profile
│   ├── inquiry_model.dart                 # Business inquiries
│   ├── live_connect_filter.dart           # Networking filters
│   ├── menu_model.dart                    # Restaurant menu system
│   ├── message_model.dart                 # Chat messages
│   ├── post_model.dart                    # AI-matchable posts
│   ├── review_model.dart                  # Reviews/ratings
│   └── user_profile.dart                  # User + BusinessProfile
│
├── providers/                             # Riverpod state management
│   └── other providers/
│       ├── app_providers.dart             # 11 providers (auth, user, connectivity)
│       └── theme_provider.dart            # Dark/glassmorphism theme
│
├── res/                                   # Resources & configuration
│   ├── config/
│   │   ├── api_assets.dart                # Asset paths + API endpoints
│   │   ├── api_config.dart                # AI config + matching thresholds
│   │   ├── app_colors.dart                # 471-line color system
│   │   └── app_text_styles.dart           # 682-line typography system
│   └── utils/
│       ├── api_error_handler.dart          # Error classification
│       ├── app_optimizer.dart              # Performance optimization
│       ├── memory_manager.dart             # Buffer management
│       ├── performance_monitor.dart        # Performance tracking
│       ├── photo_url_helper.dart           # Google photo URL fixing
│       └── snackbar_helper.dart            # Glassmorphic snackbars
│
├── screens/                               # UI screens (62 files)
│   ├── login/                             # Auth flow (6 screens)
│   ├── home/                              # Main tabs + features (10 screens)
│   │   └── product/                       # E-commerce (7 screens)
│   ├── chat/                              # Messaging (10 screens)
│   ├── call/                              # Voice/video calls (8 screens)
│   ├── business/simple/                   # Business management (14 screens)
│   ├── profile/                           # User profile (11 screens)
│   ├── location/                          # Location settings (1 screen)
│   └── performance_debug_screen.dart      # Dev debugging
│
├── services/                              # Business logic (34+ files)
│   ├── ai_services/
│   │   └── gemini_service.dart            # Gemini AI integration
│   ├── cache_services/
│   │   └── cache_service.dart             # LRU caching layer
│   ├── chat_services/
│   │   ├── chat_service.dart              # Low-level chat ops
│   │   └── conversation_service.dart      # Conversation management
│   ├── error_services/
│   │   └── error_tracking_service.dart    # Crashlytics integration
│   ├── location_services/
│   │   ├── geocoding_service.dart         # Reverse geocoding
│   │   └── location_service.dart          # GPS + location updates
│   ├── other_services/
│   │   ├── group_video_call_service.dart  # Group video calls
│   │   ├── group_voice_call_service.dart  # Group voice calls
│   │   ├── video_call_service.dart        # 1-on-1 video calls
│   │   └── voice_call_service.dart        # 1-on-1 voice calls
│   ├── profile_services/
│   │   ├── photo_cache_service.dart       # Photo URL caching
│   │   └── profile_service.dart           # Profile CRUD
│   ├── account_type_service.dart          # Account upgrade/management
│   ├── active_chat_service.dart           # Active chat tracking
│   ├── analytics_service.dart             # Firebase Analytics
│   ├── auth_service.dart                  # Authentication
│   ├── booking_service.dart               # Booking management
│   ├── catalog_service.dart               # Business catalog
│   ├── connection_service.dart            # User connections
│   ├── connectivity_service.dart          # Network monitoring
│   ├── current_user_cache.dart            # Current user caching
│   ├── firebase_provider.dart             # Firebase access point
│   ├── floating_call_service.dart         # Floating call overlay
│   ├── group_chat_service.dart            # Group chat management
│   ├── hybrid_chat_service.dart           # SQLite + Firebase sync
│   ├── notification_service.dart          # FCM + local notifications
│   ├── realtime_matching_service.dart     # Real-time match detection
│   ├── review_service.dart                # Reviews/ratings
│   ├── unified_matching_service.dart      # Advanced matching
│   ├── unified_post_service.dart          # Post CRUD + matching
│   ├── universal_intent_service.dart      # Intent processing wrapper
│   ├── user_manager.dart                  # User profile streaming
│   └── voice_assistant_service.dart       # Voice AI assistant
│
├── utils/
│   └── currency_utils.dart                # Currency formatting
│
└── widgets/                               # Reusable components (18 files)
    ├── account_badges.dart                # 6 badge widgets
    ├── app_background.dart                # Background with particles
    ├── app_drawer.dart                    # ChatGPT-style drawer
    ├── audio_visualizer.dart              # Audio wave visualization
    ├── catalog_card_widget.dart           # Product/service card
    ├── catalog_chat_bubble.dart           # Catalog item in chat
    ├── chat_common.dart                   # Shared chat components
    ├── coming_soon_widget.dart            # Feature placeholder
    ├── country_code_picker_sheet.dart     # Country code selector
    ├── device_login_dialog.dart           # Multi-device dialog
    ├── floating_particles.dart            # Particle animation
    ├── safe_circle_avatar.dart            # Rate-limit-safe avatar
    ├── select_participants_dialog.dart    # Group call participant picker
    ├── voice_orb.dart                     # Voice assistant orb
    ├── chat widgets/
    │   └── match_card_with_actions.dart   # Match result card
    ├── other widgets/
    │   ├── glass_text_field.dart          # Glassmorphic inputs
    │   └── user_avatar.dart              # Cached user avatar
    └── profile widgets/
        └── profile_detail_bottom_sheet.dart # Premium profile sheet
```

### File Statistics

| Category | Count |
|----------|-------|
| Screen files | 62 |
| Service files | 34+ |
| Model files | 15 |
| Widget files | 18 |
| Provider files | 2 |
| Config files | 4 |
| Utility files | 7 |
| **Total Dart files** | **140+** |

---

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

## 5. Data Models & Database Schema

### Firestore Collection Structure

```
users/
├── {uid}/                          → UserProfile document
│   ├── (profile fields)
│   ├── businessProfile (nested)    → BusinessProfile
│   ├── verification (nested)       → VerificationData
│   ├── catalog/
│   │   └── {catalogId}             → CatalogItem
│   ├── bookings/
│   │   └── {bookingId}             → BookingModel
│   ├── reviews/
│   │   └── {reviewId}              → ReviewModel
│   ├── inquiries/
│   │   └── {inquiryId}             → InquiryModel
│   ├── menu_categories/
│   │   └── {categoryId}            → MenuCategoryModel
│   ├── menu_items/
│   │   └── {itemId}                → MenuItemModel
│   └── food_orders/
│       └── {orderId}               → FoodOrderModel

posts/
└── {postId}                        → PostModel (with 768-dim embedding)

conversations/
├── {conversationId}                → ConversationModel
│   └── messages/
│       └── {messageId}             → MessageModel

connection_requests/
└── {requestId}                     → Connection request data

voice_calls/
└── {callId}                        → WebRTC signaling data

video_calls/
└── {callId}                        → WebRTC signaling data

group_calls/
└── {callId}/
    └── participants/               → Group call participant data

notifications/
└── {notificationId}                → Notification records

bookings/
└── {bookingId}                     → BookingModel (top-level)

business_reviews/
└── {reviewId}                      → ReviewModel (top-level)
```

### Core Models

#### UserProfile (`users/{uid}`)

| Field | Type | Description |
|-------|------|-------------|
| uid | String | Firebase Auth UID |
| name | String | Display name |
| email | String | Email address |
| profileImageUrl | String? | Profile photo URL |
| phone | String? | Phone number |
| location | String? | Location name |
| latitude | double? | GPS latitude |
| longitude | double? | GPS longitude |
| bio | String | User bio |
| interests | List |<String> | User interests |
| isOnline | bool | Current online status |
| isVerified | bool | Verification status |
| showOnlineStatus | bool | Privacy toggle |
| accountType | AccountType | personal \| business |
| accountStatus | AccountStatus | active \| pendingVerification \| suspended |
| businessProfile | BusinessProfile? | Business data (if business account) |
| verification | VerificationData | Verification details |
| fcmToken | String? | FCM push token |
| activeDeviceToken | String? | Current device token |
| forceLogout | bool | Remote logout signal |
| createdAt | DateTime | Account creation |
| lastSeen | DateTime | Last activity |

#### BusinessProfile (nested in UserProfile)

| Field | Type | Description |
|-------|------|-------------|
| businessName | String? | Legal business name |
| description | String? | Business description |
| softLabel | String? | Industry label |
| contactPhone | String? | Business phone |
| contactEmail | String? | Business email |
| website | String? | Website URL |
| address | String? | Physical address |
| hours | BusinessHours? | Operating schedule |
| profileViews | int | View counter |
| catalogViews | int | Catalog view counter |
| averageRating | double | Review rating (0-5) |
| totalReviews | int | Number of reviews |
| coverImageUrl | String? | Cover photo |
| isLive | bool | Live status |
| socialLinks | Map\<String, String\>? | Social media |
| businessTypes | List\<String\> | products, services, bookings, events |

#### PostModel (`posts/{postId}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Post ID |
| userId | String | Creator's UID |
| originalPrompt | String | Raw user input |
| title | String | AI-generated title |
| description | String | AI-generated description |
| intentAnalysis | Map | Full AI analysis (see section 7) |
| embedding | List\<double\>? | 768-dim semantic vector |
| keywords | List\<String\>? | Extracted keywords |
| location | String? | Location name |
| latitude / longitude | double? | GPS coordinates |
| price / priceMin / priceMax | double? | Pricing |
| currency | String? | Currency code |
| images | List\<String\>? | Attached images |
| isActive | bool | Active status |
| expiresAt | DateTime? | Expiration (30 days) |
| similarityScore | double? | Match score (populated during matching) |
| matchedUserIds | List\<String\> | Matched user IDs |
| createdAt | DateTime | Creation time |

**Key Computed Properties:**
- `primaryIntent` → from `intentAnalysis['primary_intent']`
- `actionType` → from `intentAnalysis['action_type']` (offering/seeking/neutral)
- `searchKeywords` → from `intentAnalysis['search_keywords']`
- `needsClarification` → if `clarifications_needed` is not empty

#### MessageModel (`conversations/{id}/messages/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Message ID |
| senderId | String | Sender UID |
| receiverId | String | Recipient UID |
| chatId | String | Conversation ID |
| text | String? | Message text |
| type | MessageType | text, image, video, audio, file, location, voiceCall, etc. |
| status | MessageStatus | sending, sent, delivered, read, failed |
| mediaUrl | String? | Media URL |
| thumbnailUrl | String? | Thumbnail |
| audioUrl | String? | Audio URL |
| audioDuration | int? | Audio duration (ms) |
| replyToMessageId | String? | Reply reference |
| reactions | List\<String\>? | Emoji reactions |
| isEdited | bool | Edit flag |
| isDeleted | bool | Soft delete flag |
| timestamp | DateTime | Send time |

#### ConversationModel (`conversations/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Conversation ID (deterministic: userId1_userId2) |
| participantIds | List\<String\> | User IDs |
| participantNames | Map\<String, String\> | ID → Name |
| participantPhotos | Map\<String, String?\> | ID → Photo URL |
| lastMessage | String? | Preview text |
| lastMessageTime | DateTime? | Last message timestamp |
| unreadCount | Map\<String, int\> | Per-user unread count |
| isTyping | Map\<String, bool\> | Per-user typing status |
| isGroup | bool | Group chat flag |
| groupName | String? | Group name |
| groupPhoto | String? | Group photo |
| metadata | Map? | Business chat info |
| createdAt | DateTime | Creation time |

#### CatalogItem (`users/{userId}/catalog/{catalogId}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Item ID |
| userId | String | Owner UID |
| name | String | Item name |
| description | String? | Description |
| price | double? | Price |
| currency | String | Currency (default: INR) |
| imageUrls | List\<String\> | Multiple images |
| type | CatalogItemType | product \| service |
| isAvailable | bool | Availability |
| isFeatured | bool | Featured flag |
| duration | int? | Service duration (minutes) |
| tags | List\<String\> | Search tags |
| category | String? | Category |
| viewCount | int | View counter |

#### BookingModel (`bookings/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Booking ID |
| customerId | String | Customer UID |
| customerName | String | Customer name |
| businessOwnerId | String | Business UID |
| businessName | String | Business name |
| serviceName | String? | Service booked |
| servicePrice | double? | Service price |
| status | BookingStatus | pending, confirmed, completed, cancelled |
| bookingDate | DateTime | Scheduled date |
| bookingTime | String? | Scheduled time (HH:mm) |
| duration | int? | Duration (minutes) |
| notes | String? | Customer notes |

#### ReviewModel (`business_reviews/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Review ID |
| reviewerId | String | Reviewer UID |
| businessId | String | Business UID |
| rating | double | Rating (1-5) |
| categoryRatings | Map\<String, double\>? | Per-category ratings |
| reviewText | String | Review content |
| images | List\<String\> | Review photos |
| isVerifiedPurchase | bool | Purchase verified |
| createdAt | DateTime | Review date |

### Enums

| Enum | Values |
|------|--------|
| AccountType | personal, business |
| AccountStatus | active, pendingVerification, suspended |
| VerificationStatus | none, pending, verified, rejected |
| CatalogItemType | product, service |
| MessageType | text, image, video, audio, file, location, sticker, gif, voiceCall, missedCall, videoCall |
| MessageStatus | sending, sent, delivered, read, failed |
| BookingStatus | pending, confirmed, completed, cancelled |
| InquiryStatus | pending, responded, negotiating, accepted, declined, completed, cancelled |
| FoodType | veg, nonVeg, egg, vegan |
| SpiceLevel | mild, medium, hot, extraHot |
| OrderType | dineIn, takeaway, delivery |
| FoodOrderStatus | pending, confirmed, preparing, ready, outForDelivery, delivered, completed, cancelled |

### Model Relationships

```
UserProfile ──1:0..1──→ BusinessProfile
UserProfile ──1:1─────→ VerificationData
UserProfile ──1:N─────→ CatalogItem
UserProfile ──1:N─────→ PostModel
UserProfile ──1:N─────→ BookingModel (as business)
UserProfile ──1:N─────→ ReviewModel (as business)
PostModel   ──M:N─────→ PostModel (matching)
ConversationModel ──1:N→ MessageModel
BusinessProfile ──1:1──→ BusinessHours ──1:7──→ DayHours
MenuCategoryModel ──1:N→ MenuItemModel
FoodOrderModel ──1:N───→ FoodOrderItem
```

---

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

## 7. AI / Matching Pipeline

### Overview

The matching system uses **no hardcoded categories**. All intent understanding is dynamic, powered by Gemini AI. The system uses a **dual-signal approach**: semantic similarity (768-dimensional embeddings) combined with keyword overlap.

### Pipeline Flow

```
┌──────────────────────────────────────────────────────────────┐
│ 1. USER INPUT (Voice or Text)                                │
│    "I want to buy an iPhone 14 Pro"                          │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 2. INTENT ANALYSIS (Gemini AI)                               │
│    - primary_intent: "buy iPhone 14 Pro"                     │
│    - action_type: "seeking"                                  │
│    - domain: "marketplace"                                   │
│    - complementary_intents: ["selling iPhone 14", ...]       │
│    - is_symmetric: false                                     │
│    - exchange_model: "paid"                                  │
│    - search_keywords: ["iphone", "14", "pro"]                │
│    - value_profile: []                                       │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 3. EMBEDDING GENERATION (768-dim)                            │
│    Text: "buy iPhone 14 Pro marketplace seeking"             │
│    → [0.45, -0.12, 0.89, ...] (768 values)                  │
│    → Cached for 24 hours                                     │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. POST STORED IN FIRESTORE                                  │
│    posts/{postId} with all fields + embedding + keywords     │
│    Expires in 30 days                                        │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 5. MATCH FINDING (Scoring Algorithm)                         │
│    Search embedding from complementary_intents               │
│    Compare against all active posts:                         │
│    ┌─ Semantic: cosine_similarity(search_emb, post_emb)      │
│    ├─ Keywords: shared + complementary keyword hits           │
│    ├─ Intent: offer↔seek bonus (+0.15)                       │
│    ├─ Location: distance-based score (×0.05)                 │
│    └─ Lifestyle: clash penalty (-0.15)                       │
│    Final threshold: ≥ 0.60                                   │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 6. REALTIME MATCHING                                         │
│    RealtimeMatchingService listens for new posts             │
│    If score ≥ 0.65 → Push notification to matched users      │
└──────────────────────────────────────────────────────────────┘
```

### Intent Analysis Structure (from Gemini)

```json
{
  "primary_intent": "buy iPhone 14 Pro",
  "action_type": "offering | seeking | neutral",
  "is_symmetric": false,
  "skill_level": "beginner | intermediate | advanced | expert | any",
  "exchange_model": "free | paid | barter | equity | flexible | unspecified",
  "domain": "marketplace | jobs | housing | services | education | fitness | ...",
  "complementary_intents": ["selling iPhone 14", "iPhone for sale", ...],
  "search_keywords": ["iphone", "14", "pro", "buy"],
  "value_profile": ["vegan", "pets", "no_smoking", ...],
  "title": "Looking to Buy iPhone 14 Pro",
  "description": "User wants to purchase an iPhone 14 Pro",
  "confidence": 0.95,
  "entities": { "product": "iPhone 14 Pro", "price_range": "$800-1000" }
}
```

### Scoring Formula

```
relevance = max(semantic_similarity, keyword_score × 0.70)

final_score = relevance
            + intent_bonus      (0.15 if offer↔seek + evidence)
            + location_bonus    (location_score × 0.05)
            - lifestyle_penalty (0.15 if lifestyle clash)
            - domain_penalty    (0.10 if domain mismatch)
```

### Thresholds & Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Pre-filter threshold | 0.40 | Skip if semantic similarity below |
| Final threshold | 0.60 | Minimum to surface as match |
| Realtime threshold | 0.65 | Minimum for push notification |
| Intent bonus | 0.15 | Offer ↔ seek complementarity |
| Location weight | 0.05 | Location proximity factor |
| Lifestyle penalty | 0.15 | Lifestyle incompatibility |
| Domain mismatch penalty | 0.10 | Different domains |
| Keyword damping | 0.70 | Keyword signal dampening |
| Query limit | 200 | Max posts fetched for matching |
| Max results | 20 | Top matches returned |
| Embedding dimension | 768 | Vector size |
| Cache duration | 24h | Embedding cache TTL |

### Hard Filters (Automatic Rejection)

1. **Same-side block**: Two sellers don't match (unless both symmetric, e.g., gym partners)
2. **Exchange model incompatibility**: free ↔ paid, equity ↔ paid
3. **Domain mismatch**: Different specific domains with no keyword overlap
4. **Below pre-filter**: Semantic similarity < 0.40

### Lifestyle Incompatibility Pairs

| Value A | Value B |
|---------|---------|
| vegan | meat_based, bbq, non_vegetarian |
| vegetarian | meat_based, bbq, non_vegetarian |
| pets | no_pets |
| smoking | no_smoking |
| quiet | loud |
| night_owl | early_bird |
| hunting | animal_rights |

### Location Scoring

| Service Type | 0 km | 50 km | 200 km | 500 km | >500 km |
|-------------|-------|-------|--------|--------|---------|
| in_person | 1.0 | 1.0 | ~0.6 | 0.0 | 0.0 |
| community | 1.0 | 1.0 | 1.0 | ~0.5 | 0.0 |
| professional | 1.0 | 1.0 | 1.0 | 1.0 | ~0.5 |
| digital | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

### Voice Assistant Function Tools

The voice assistant can execute these functions via Gemini function calling:

| Function | Description |
|----------|-------------|
| searchPosts(query) | Keyword search across posts |
| searchByEmbedding(text) | Semantic search via embeddings |
| searchNearby(text, radiusKm) | Location-based search |
| createPost(prompt) | Create new post |
| getMatches(postId) | Find matches for a post |
| findMatchesForMe() | Find best matches for user |
| getMyPosts() | List user's active posts |
| getUserProfile() | Get current user profile |
| getRecentConversations() | List recent chats |
| navigateTo(screen) | Navigate to app screen |

---

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

## 9. Screens & User Flows

### Complete Screen Inventory (62 screens)

#### Authentication Flow (6 screens)

| Screen | File | Purpose |
|--------|------|---------|
| SplashScreen | login/splash_screen.dart | 3-second animated launch |
| OnboardingScreen | login/onboarding_screen.dart | 4-page feature carousel |
| ChooseAccountTypeScreen | login/choose_account_type_screen.dart | Account type selection |
| LoginScreen | login/login_screen.dart | Email/phone/Google auth |
| ForgotPasswordScreen | login/forgot_password_screen.dart | 3-step password reset |
| ChangePasswordScreen | login/change_password_screen.dart | Password change (logged in) |

#### Home & Navigation (10 screens)

| Screen | File | Purpose |
|--------|------|---------|
| MainNavigationScreen | home/main_navigation_screen.dart | 5-tab root container |
| HomeScreen | home/home_screen.dart | AI post feed + discovery |
| ConversationsScreen | home/conversations_screen.dart | Chats/Groups/Calls tabs |
| LiveConnectTabScreen | home/live_connect_tab_screen.dart | People discovery |
| NearByScreen | home/near_by_screen.dart | Location-based feed |
| NearByPostsScreen | home/near_by_posts_screen.dart | Area-specific posts |
| ProfileWithHistoryScreen | home/profile_with_history_screen.dart | User profile + history |
| EditPostScreen | home/edit_post_screen.dart | Create/edit posts |
| VoiceAssistantScreen | home/voice_assistant_screen.dart | Voice AI interface |

#### E-Commerce (7 screens)

| Screen | File | Purpose |
|--------|------|---------|
| ProductDetailScreen | home/product/product_detail_screen.dart | Product view |
| SeeAllProductsScreen | home/product/see_all_products_screen.dart | Product catalog |
| CheckoutScreen | home/product/checkout_screen.dart | Cart + checkout |
| OrderSummaryScreen | home/product/order_summary_screen.dart | Order review |
| ConfirmingOrderScreen | home/product/confirming_order_screen.dart | Order processing |
| OrderTrackingScreen | home/product/order_tracking_screen.dart | Real-time tracking |
| MyOrdersScreen | home/product/my_orders_screen.dart | Order history |

#### Messaging (10 screens)

| Screen | File | Purpose |
|--------|------|---------|
| EnhancedChatScreen | chat/enhanced_chat_screen.dart | 1-on-1 messaging |
| GroupChatScreen | chat/group_chat_screen.dart | Group messaging |
| CreateGroupScreen | chat/create_group_screen.dart | Create group chat |
| GroupInfoScreen | chat/group_info_screen.dart | Group settings |
| MediaGalleryScreen | chat/media_gallery_screen.dart | 1-on-1 media gallery |
| GroupMediaGalleryScreen | chat/group_media_gallery_screen.dart | Group media gallery |
| PhotoViewerDialog | chat/photo_viewer_dialog.dart | Full-screen image viewer |
| VideoPlayerScreen | chat/video_player_screen.dart | Video playback |
| AudioPlayerDialog | chat/audio_player_dialog.dart | Voice message player |
| LinkPreviewDialog | chat/link_preview_dialog.dart | URL preview |

#### Calling (8 screens)

| Screen | File | Purpose |
|--------|------|---------|
| VoiceCallScreen | call/voice_call_screen.dart | 1-on-1 voice call |
| VideoCallScreen | call/video_call_screen.dart | 1-on-1 video call |
| IncomingVideoCallScreen | call/incoming_video_call_screen.dart | Incoming video (disabled) |
| GroupAudioCallScreen | call/group_audio_call_screen.dart | Group audio conference |
| GroupVideoCallScreen | call/group_video_call_screen.dart | Group video (disabled) |
| IncomingGroupAudioCallScreen | call/incoming_group_audio_call_screen.dart | Incoming group audio |
| IncomingGroupVideoCallScreen | call/incoming_group_video_call_screen.dart | Incoming group video (disabled) |
| CallHistoryScreen | call/call_history_screen.dart | Call history log |

#### Business (14 screens)

| Screen | File | Purpose |
|--------|------|---------|
| BusinessHubScreen | business/simple/business_hub_screen.dart | Business dashboard |
| CatalogManagementScreen | business/simple/catalog_management_screen.dart | Catalog CRUD |
| CatalogItemForm | business/simple/catalog_item_form.dart | Add/edit catalog item |
| CatalogItemDetail | business/simple/catalog_item_detail.dart | Item detail view |
| BookingsScreen | business/simple/bookings_screen.dart | Booking management |
| BookingRequestScreen | business/simple/booking_request_screen.dart | Handle booking |
| CustomerBookingsScreen | business/simple/customer_bookings_screen.dart | My bookings (customer) |
| ReviewsScreen | business/simple/reviews_screen.dart | View reviews |
| WriteReviewScreen | business/simple/write_review_screen.dart | Write review |
| ProfileViewsScreen | business/simple/profile_views_screen.dart | Who viewed profile |
| BusinessInfoEdit | business/simple/business_info_edit.dart | Edit business info |
| BusinessHoursEdit | business/simple/business_hours_edit.dart | Edit operating hours |
| PublicBusinessProfileScreen | business/simple/public_business_profile_screen.dart | Public business page |
| NearbyBusinessesScreen | business/simple/nearby_businesses_screen.dart | Discover businesses |

#### Profile & Settings (11 screens)

| Screen | File | Purpose |
|--------|------|---------|
| ProfileViewScreen | profile/profile_view_screen.dart | View any user's profile |
| ProfileEditScreen | profile/profile_edit_screen.dart | Edit own profile |
| SettingsScreen | profile/settings_screen.dart | App settings |
| PersonalizationScreen | profile/personalization_screen.dart | Theme settings |
| DownloadsScreen | profile/downloads_screen.dart | Downloaded files |
| LibraryScreen | profile/library_screen.dart | Saved content |
| HelpCenterScreen | profile/help_center_screen.dart | FAQ & support |
| SafetyTipsScreen | profile/safety_tips_screen.dart | Safety guidelines |
| PrivacyPolicyScreen | profile/privacy_policy_screen.dart | Privacy policy |
| TermsOfServiceScreen | profile/terms_of_service_screen.dart | Terms of service |
| UpgradePlanScreen | profile/upgrade_plan_screen.dart | Premium plans |

#### Utility (2 screens)

| Screen | File | Purpose |
|--------|------|---------|
| LocationSettingsScreen | location/location_settings_screen.dart | Location preferences |
| PerformanceDebugScreen | performance_debug_screen.dart | Dev performance debug |

### Complete User Flow Map

```
APP LAUNCH
├── SplashScreen (3 sec)
├── AuthWrapper check
│   ├── [Not logged in] → OnboardingScreen → ChooseAccountType → LoginScreen
│   └── [Logged in] → MainNavigationScreen
│
MAIN APP (5 Tabs)
├── Tab 0: HomeScreen
│   ├── Create Post → EditPostScreen
│   ├── Voice → VoiceAssistantScreen
│   ├── Post card → ProfileViewScreen / EnhancedChatScreen
│   └── Menu → AppDrawer
│
├── Tab 1: ConversationsScreen
│   ├── Chats → EnhancedChatScreen
│   │   ├── Voice call → VoiceCallScreen → FloatingCallService
│   │   ├── Media → MediaGalleryScreen → PhotoViewer/VideoPlayer
│   │   └── Catalog → ProductDetailScreen
│   ├── Groups → GroupChatScreen
│   │   ├── Group info → GroupInfoScreen
│   │   ├── Group call → GroupAudioCallScreen
│   │   └── Create → CreateGroupScreen
│   └── Calls → CallHistoryScreen
│
├── Tab 2: LiveConnectTabScreen
│   ├── User card → ProfileDetailBottomSheet / ProfileViewScreen
│   ├── Chat → EnhancedChatScreen
│   └── Connect → ConnectionRequest
│
├── Tab 3: BusinessHubScreen
│   ├── Catalog → CatalogManagementScreen → CatalogItemForm
│   ├── Bookings → BookingsScreen → BookingRequestScreen
│   ├── Reviews → ReviewsScreen → WriteReviewScreen
│   ├── Profile Views → ProfileViewsScreen
│   └── Edit Info → BusinessInfoEdit / BusinessHoursEdit
│
├── Tab 4: NearByScreen
│   ├── Post card → ProfileViewScreen / EnhancedChatScreen
│   ├── Business card → PublicBusinessProfileScreen
│   └── Products → SeeAllProductsScreen → CheckoutScreen
│
PROFILE (from tab 4 or drawer)
├── ProfileWithHistoryScreen
│   ├── Edit → ProfileEditScreen
│   ├── Settings → SettingsScreen
│   │   ├── Change Password → ChangePasswordScreen
│   │   ├── Location → LocationSettingsScreen
│   │   ├── Personalization → PersonalizationScreen
│   │   ├── Terms/Privacy/Safety → Static pages
│   │   └── Logout → OnboardingScreen
│   └── Business toggle → Business setup
```

### Form Summary

| Screen | Form Type | Key Fields |
|--------|-----------|-----------|
| LoginScreen | Authentication | Email/Phone, Password, OTP (6 digits) |
| ForgotPasswordScreen | Recovery | Phone, OTP, New Password (3 steps) |
| EditPostScreen | Content | Title, Description, Price, Currency, Images, Hashtags |
| ProfileEditScreen | Profile | Name, Phone, Location, Gender, DOB, Photo, Bio |
| CatalogItemForm | Business | Type, Name, Description, Price, Duration, Image |
| CreateGroupScreen | Group | Group name, Member selection |
| WriteReviewScreen | Review | Rating (1-5 stars), Review text |
| BusinessInfoEdit | Business | Name, Description, Category, Contact, Logo |
| BusinessHoursEdit | Schedule | Per-day open/close times |
| CheckoutScreen | Commerce | Quantity, Address, Payment, Coupon |

### Detailed Screen Documentation

#### HomeScreen (`home/home_screen.dart` — 3,206 lines)

ChatGPT-style AI chat interface. Users type natural language, Gemini AI processes intent, returns matches and conversational responses.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_intentController` | TextEditingController | User input field |
| `_chatScrollController` | ScrollController | Auto-scroll to latest message |
| `_conversation` | List<Map<String, dynamic>> | Chat message history |
| `_currentChatId` | String? | Active chat session ID |
| `_isProcessing` | bool | Shows loading indicator while AI processes |
| `_isRecording` | bool | Voice recording active state |
| `_speech` | SpeechToText | Speech recognition engine |
| `_tts` | FlutterTts | Text-to-speech engine |
| `_likedMessages` / `_dislikedMessages` | Set<String> | Message feedback tracking |
| `_suggestions` | List<String> | AI-generated quick reply suggestions |
| `_matches` | List<Map<String, dynamic>> | Semantic match results |

**Widget Tree:**
```
Scaffold
└── SafeArea
    └── Stack
        ├── Background (image + dark overlay)
        └── Column
            ├── Search input (with focus state toggle)
            ├── Expanded chat conversation (ListView of message bubbles)
            │   ├── User message bubbles (right-aligned, gradient)
            │   ├── AI response bubbles (left-aligned, glassmorphic)
            │   └── Match cards (inline results with Chat/Profile buttons)
            └── Bottom action bar (voice mic, send button, TTS toggle)
```

**User Interactions:**
- Text submit → `_processIntent()` sends to Gemini AI → renders response + matches
- Voice recording → `_startVoiceRecording()` / `_finishRecording()` with speech-to-text
- TTS toggle → `_toggleTts(key, text)` reads AI response aloud
- Message like/dislike → tracks feedback in `_likedMessages` / `_dislikedMessages`
- Chat auto-save → persists conversation to Firestore on each message

**Navigation Targets:** EnhancedChatScreen, ProductDetailScreen, SeeAllProductsScreen, VoiceAssistantScreen, PublicBusinessProfileScreen

**Services:** UniversalIntentService, RealtimeMatchingService, GeminiService, FirebaseAuth, PhotoCacheService, CatalogService

---

#### EnhancedChatScreen (`chat/enhanced_chat_screen.dart` — 11,529 lines)

Full-featured 1-on-1 messaging screen with media, audio recording/playback, search, reactions, and reply threading.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_messageController` | TextEditingController | Message input |
| `_conversationId` | String? | Active conversation ID |
| `_replyToMessage` | MessageModel? | Reply threading target |
| `_editingMessage` | MessageModel? | Message being edited |
| `_isTyping` | bool | Typing indicator state |
| `_showEmojiPicker` | bool | Emoji panel visibility |
| `_isSearching` / `_searchQuery` | bool / String | In-chat message search |
| `_searchResults` / `_currentSearchIndex` | List / int | Search result navigation |
| `_loadedMessages` | List | Paginated message list |
| `_hasMoreMessages` | bool | Pagination state |
| `_audioRecorder` | FlutterSoundRecorder? | Voice message recording |
| `_audioPlayer` | FlutterSoundPlayer? | Voice message playback |
| `_isMultiSelectMode` | bool | Bulk message selection |
| `_selectedMessageIds` | Set<String> | Selected messages for bulk actions |
| `_todayImageCount` / `_todayVideoCount` / `_todayAudioCount` | int | Daily media send limits |

**Widget Tree:**
```
PopScope
└── Scaffold
    ├── AppBar (user name, online status, call/search/menu icons)
    └── Stack
        ├── Background (image + dark overlay)
        └── SafeArea → Column
            ├── Search bar (conditional, with prev/next navigation)
            ├── Expanded message list (StreamBuilder on Firestore)
            │   ├── Date separator headers
            │   ├── ChatMessageBubble (text, media, audio, reply preview)
            │   └── Typing indicator bubble
            ├── Reply/edit preview bar (conditional)
            ├── Emoji picker panel (conditional, bottom)
            └── Input area (text field, emoji toggle, mic, attachment, send)
```

**User Interactions:**
- Send text/media/audio messages with reply threading
- Voice recording with waveform visualization and duration timer
- In-chat search with result highlighting and prev/next navigation
- Message reactions, edit, delete, copy, forward
- Multi-select mode for bulk delete
- Typing indicators (real-time Firestore updates)
- Image/video picker with daily send limits

**Navigation Targets:** VoiceCallScreen, MediaGalleryScreen, PhotoViewerDialog, MainNavigationScreen

**Services:** ConversationService, HybridChatService, ActiveChatService, NotificationService, FirebaseStorage, ImagePicker, FlutterSoundRecorder/Player

---

#### LiveConnectTabScreen (`home/live_connect_tab_screen.dart` — 3,252 lines)

People discovery screen with 2 tabs: "Discover Connect" (browse nearby) and "Smart Connect" (AI-matched). Features 6 connection type groups with pagination.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_tabController` | TabController | 2-tab navigation |
| `_nearbyPeople` / `_filteredPeople` | List<Map> | User lists |
| `_selectedInterests` / `_selectedConnectionTypes` / `_selectedActivities` | List<String> | Active filters |
| `_currentUserLat` / `_currentUserLon` | double? | GPS coordinates |
| `_distanceFilter` | double | Max distance km |
| `_selectedGenders` | List<String> | Gender filter |
| `_connectionStatusCache` / `_requestStatusCache` | Map | Connection state cache |
| `_hasMoreUsers` / `_lastDocument` | bool / DocumentSnapshot? | Cursor pagination |
| `_expandedConnectionGroups` / `_expandedActivityGroups` | Map<String, bool> | Group UI expand state |

**Widget Tree:**
```
Scaffold
├── AppBar with TabBar (Discover Connect | Smart Connect)
└── TabBarView
    ├── Tab 1: Discover (grid/list of user cards with filters)
    │   ├── Filter bar (interests, distance, gender, connection type)
    │   ├── Search bar with voice search
    │   └── User card grid (CachedNetworkImage, badges, distance)
    └── Tab 2: Smart Connect (AI-curated matches)
```

**User Interactions:**
- Tab switch, search/voice search, filter toggles
- Connection request send → `_sendConnectionRequest(userId)`
- Profile view → ProfileDetailBottomSheet or ProfileViewScreen
- Swipe card actions (skip/connect)
- Scroll pagination (loads 20 users per page)

**Navigation Targets:** EnhancedChatScreen, ProfileViewScreen

**Services:** ConnectionService, LocationService, FirebaseAuth, FirebaseFirestore, VoiceSearchMixin

---

#### ConversationsScreen (`home/conversations_screen.dart` — 2,980 lines)

3-tab messaging hub: Chats (1-on-1), Groups, Calls. Real-time updates via Firestore StreamBuilder.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_tabController` | TabController | 3 tabs: Chats, Groups, Calls |
| `_searchQuery` | String | Filter conversations by name |
| `_userCache` | Map<String, Map> | Avoid repeated Firestore reads |
| `_isCallSelectionMode` | bool | Bulk call delete mode |
| `_individualCalls` / `_groupCalls` | List | Call history (lazy-loaded on Calls tab) |
| `_isConversationSelectionMode` | bool | Bulk conversation delete mode |

**Widget Tree:**
```
Scaffold
├── AppBar with TabBar (Chats | Groups | Calls)
│   └── Search icon + voice search
└── TabBarView
    ├── Tab 0: Chats (StreamBuilder → conversation tiles with unread badges)
    ├── Tab 1: Groups (StreamBuilder → group tiles with member count)
    └── Tab 2: Calls (lazy-loaded call history with duration, type icons)
```

**User Interactions:**
- Search/voice search conversations
- Tap conversation → open chat, long-press → selection mode
- Swipe-to-delete conversations
- Create new group (FAB)
- Tab change triggers lazy call listener start/stop

**Navigation Targets:** EnhancedChatScreen, GroupChatScreen, CreateGroupScreen, VoiceCallScreen, GroupAudioCallScreen

**Services:** FirebaseAuth, FirebaseFirestore, CurrentUserCache, NotificationService, VoiceSearchMixin

---

#### LoginScreen (`login/login_screen.dart`)

Dual-mode authentication: email/password and phone OTP with 6-digit input boxes. Includes device session enforcement (single-device login).

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_isSignUpMode` | bool | Toggle login/signup form |
| `_emailOrPhoneController` / `_passwordController` | TextEditingController | Form inputs |
| `_isOtpSent` / `_verificationId` | bool / String? | Phone OTP flow state |
| `_otpBoxControllers` | List<TextEditingController> | 6 individual OTP digit boxes |
| `_otpFocusNodes` | List<FocusNode> | Auto-advance focus between OTP boxes |
| `_selectedCountryCode` | String | Phone country code (+91 default) |
| `_pendingUserId` | String? | Device login conflict resolution |
| `_animationController` / `_fadeAnimation` / `_slideAnimation` | AnimationController / Animation | Entry animations |

**Widget Tree:**
```
Scaffold
└── AnimatedBuilder (fade + slide entry)
    └── Stack
        ├── Background gradient + overlay
        └── SafeArea → SingleChildScrollView
            ├── Logo header
            ├── Form
            │   ├── Email/phone input (auto-detects mode)
            │   ├── Password field (conditional, email mode only)
            │   ├── OTP section (conditional, 6 digit boxes)
            │   └── Terms checkbox
            ├── Login/Sign Up button
            └── Forgot password link
```

**Navigation Targets:** MainNavigationScreen (success), ForgotPasswordScreen, ChooseAccountTypeScreen

**Services:** AuthService, FirebaseAuth, FirebaseFirestore

---

#### MainNavigationScreen (`home/main_navigation_screen.dart`)

Root container managing 5 bottom tabs with real-time listeners for unread counts and incoming calls.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_currentIndex` | int | Active tab index |
| `_tabController` | TabController | 5-tab controller |
| `_unreadSubscription` | StreamSubscription? | Unread message badge listener |
| `_incomingCallSubscription` | StreamSubscription? | Incoming call listener |
| `_isShowingIncomingCall` | bool | Prevent duplicate call dialogs |
| `_handledCallIds` | Set<String> | Prevent re-handling same call |

**5 Tabs:** HomeScreen → ConversationsScreen → LiveConnectTabScreen → BusinessHubScreen → NetworkingScreen

**Features:**
- Persists last tab index to SharedPreferences
- Haptic feedback on tab change
- WidgetsBindingObserver for online status updates on app lifecycle
- CallKit integration for native incoming call UI
- Unread badge counts on Messages tab

**Services:** LocationService, NotificationService, FirebaseAuth, FirebaseFirestore, CallKit, SharedPreferences

---

#### ProfileViewScreen (`profile/profile_view_screen.dart`)

View any user's profile. Adapts layout for personal vs business accounts. Logs profile views for business analytics.

**Widget Tree:**
```
Scaffold → SafeArea → Stack
├── SingleChildScrollView
│   ├── Image carousel (PageView with dot indicators)
│   ├── Profile info (name, bio, verification badges)
│   ├── Post details (if navigated from post card)
│   ├── Catalog grid (if business account)
│   └── Reviews section (if business account)
├── Top bar (back, online indicator, more options)
└── Bottom action bar (Message, Connect, Write Review buttons)
```

**Navigation Targets:** EnhancedChatScreen, CatalogItemDetailScreen, WriteReviewScreen

---

#### PublicBusinessProfileScreen (`business/simple/public_business_profile_screen.dart`)

Public-facing business profile with catalog, hours, and reviews.

**Widget Tree:**
```
Scaffold → CustomScrollView
├── SliverAppBar (flexible cover image)
└── SliverToBoxAdapter sections
    ├── Action row (message, call, review buttons)
    ├── About section (business description)
    ├── Catalog grid (available items only)
    ├── Business hours schedule
    └── Reviews with RatingSummary breakdown
```

**Navigation Targets:** EnhancedChatScreen, WriteReviewScreen, CatalogItemDetailScreen, ReviewsScreen, BookingRequestScreen

**Services:** CatalogService, ReviewService, FirebaseAuth, FirebaseFirestore

---

#### CatalogManagementScreen (`business/simple/catalog_management_screen.dart`)

Business inventory management with search, filters, grid/list toggle, and animated FAB.

**Widget Tree:**
```
Scaffold
├── AppBar (search field + filter dropdown)
├── StreamBuilder on catalog items
│   ├── Grid view (CatalogCardWidget cards)
│   └── List view (CatalogCardWidget rows)
└── Animated FAB (collapses on scroll down, expands on scroll up)
```

**User Interactions:**
- Search filters items by name/description
- Type filter dropdown (product/service/all)
- Grid/list toggle
- Item tap → bottom sheet (edit, mark sold/available, delete)
- FAB → add new catalog item

**Navigation Targets:** CatalogItemForm (add/edit)

**Services:** CatalogService, FirebaseAuth

---

#### OnboardingScreen (`login/onboarding_screen.dart`)

4-page feature carousel with 3D card effect (viewportFraction: 0.8). Purely presentational.

**Widget Tree:**
```
Scaffold → Stack
├── Background gradient + image overlay
└── SafeArea
    ├── Header (logo + Skip button)
    ├── PageView (4 onboarding cards with parallax effect)
    └── Bottom (dot indicators + Get Started button)
```

**Navigation Targets:** ChooseAccountTypeScreen

---

#### ProfileEditScreen (`profile/profile_edit_screen.dart`)

Edit own profile with form validation, photo upload, and business account toggle.

**Form Fields:** Name, Phone, Location (auto-detect), Bio, Gender dropdown, Occupation dropdown, Date of birth picker, Profile photo (tap to change)

**Navigation Targets:** BusinessInfoEdit (when business toggle activated)

**Services:** AuthService, UserManager, FirebaseAuth, FirebaseFirestore, FirebaseStorage, LocationService, ImagePicker, AccountTypeService

---

## 10. Reusable Widgets & Components

### Widget Inventory (18 files)

#### Badge Widgets (`account_badges.dart`)

| Widget | Purpose | Parameters |
|--------|---------|-----------|
| VerifiedBadge | Blue verified checkmark | size, showBackground |
| BusinessBadge | Orange business indicator | size, showLabel, compact |
| PendingVerificationBadge | Yellow pending badge | size, showLabel |
| AccountTypeBadge | Smart badge selector | accountType, verificationStatus, size |
| UsernameBadge | Inline username badge | accountType, verificationStatus |
| AccountTypeCard | Glassmorphic account card | accountType, onUpgrade |

#### Background & Animation

| Widget | File | Purpose |
|--------|------|---------|
| AppBackground | app_background.dart | Background with particles + blur |
| FloatingParticles | floating_particles.dart | 60-second particle animation loop |
| AudioVisualizer | audio_visualizer.dart | 3-wave audio visualization (idle/active) |
| VoiceOrb | voice_orb.dart | 4-state voice indicator (idle/listening/processing/speaking) |
| ComingSoonWidget | coming_soon_widget.dart | Feature placeholder with progress animation |

#### Chat Components (`chat_common.dart`)

| Widget | Purpose |
|--------|---------|
| ChatMessageInput | Chat input bar (text, emoji, mic, attachment) |
| ChatMessageBubble | Message bubble with gradient, timestamps, read receipts |
| ChatEmojiPicker | Emoji selection panel (8 columns, searchable) |
| CatalogChatBubble | Rich catalog item preview in chat |
| MatchCardWithActions | Match result card with Chat/Profile buttons |

#### Input Components

| Widget | File | Purpose |
|--------|------|---------|
| GlassTextField | other widgets/glass_text_field.dart | Glassmorphic text field (34 params) |
| GlassSearchField | other widgets/glass_text_field.dart | Search with voice recording UI |
| CountryCodePickerSheet | country_code_picker_sheet.dart | Searchable country code selector |

#### Avatar Components

| Widget | File | Purpose |
|--------|------|---------|
| SafeCircleAvatar | safe_circle_avatar.dart | Rate-limit-aware network avatar with fallback |
| UserAvatar | other widgets/user_avatar.dart | Simple cached network avatar |

#### Dialog & Sheet Components

| Widget | File | Purpose |
|--------|------|---------|
| DeviceLoginDialog | device_login_dialog.dart | Multi-device login security dialog |
| SelectParticipantsDialog | select_participants_dialog.dart | Group call participant picker |
| ProfileDetailBottomSheet | profile widgets/profile_detail_bottom_sheet.dart | Premium draggable profile sheet |

#### Navigation

| Widget | File | Purpose |
|--------|------|---------|
| AppDrawer | app_drawer.dart | ChatGPT-style navigation drawer with conversation history |
| CatalogCardWidget | catalog_card_widget.dart | Product/service card (compact/normal) |

### Design Patterns

1. **Glassmorphism**: Used in 10+ widgets (BackdropFilter + gradient + border)
2. **Custom Painters**: 7 widgets (audio waves, particles, shimmer, arcs)
3. **Multi-State Animations**: VoiceOrb (3 controllers), ProfileDetailBottomSheet (2 controllers)
4. **Rate-Limit Protection**: SafeCircleAvatar tracks failed/rate-limited URLs
5. **Responsive Sizing**: Widgets adapt to screen dimensions

---

## 11. Authentication & Security

### Authentication Methods

| Method | Package | Details |
|--------|---------|---------|
| Email/Password | firebase_auth | Standard signup/login |
| Google Sign-In | google_sign_in | OAuth2 with high-quality photo extraction |
| Phone OTP | firebase_auth | SMS verification (30 countries supported) |

### Authentication Flow

```
SplashScreen (3 sec)
    ↓
AuthWrapper (StreamBuilder<User?>)
    ├── [null] → OnboardingScreen → ChooseAccountType → LoginScreen
    │                                                       ├── Email login
    │                                                       ├── Google Sign-In
    │                                                       └── Phone OTP
    │                                                            ↓
    │                                                     Device Session Check
    │                                                       ├── [No conflict] → Save session → Main app
    │                                                       └── [Conflict] → DeviceLoginDialog
    │                                                            ├── "Logout Other Device" → Force logout
    │                                                            └── "Stay Logged In" → Both active
    └── [User] → MainNavigationScreen + Device monitoring
```

### Single-Device Session Management (WhatsApp-style)

Only one device can be active at a time:

```
Device A (logged in)                    Device B (new login)
├── localStorage: token_A              ├── Generate token_B
├── Firestore: activeDeviceToken=A     ├── Read Firestore: finds token_A
├── Listener: watching changes         ├── Show DeviceLoginDialog
│                                      │
│                                      User clicks "Logout Other Device"
│                                      ├── DELETE activeDeviceToken (immediate)
│                                      ├── SET forceLogout=true
│                                      ├── WAIT 1.5 seconds
│                                      └── SET activeDeviceToken=token_B
│
├── Listener detects forceLogout=true
├── _performRemoteLogout()
├── Clear all caches & subscriptions
├── FirebaseAuth.signOut()
└── Show login screen (~500ms)
```

**Protection Mechanisms:**
- 5-second initialization window (prevents false logouts during login)
- Timestamp validation (logout signal must be after listener started)
- Stale session detection (auto-clears sessions > 5 minutes old)

### Firestore Security Rules (`firestore.rules`)

| Collection | Read | Write | Special Rules |
|-----------|------|-------|---------------|
| users/{userId} | Authenticated | Owner only | Device fields writable by any auth user; self-verification blocked |
| posts | Authenticated | Owner | Active posts only |
| conversations | Participants only | Participants | Membership check |
| calls | Participants | Participants | - |
| notifications | Owner | Owner | - |
| bookings | Authenticated | Owner | - |
| business_reviews | Authenticated | Authenticated | - |

**Business Profile Stats**: Any authenticated user can increment `profileViews`, `catalogViews`, `enquiryCount`.

### Storage Security Rules (`storage.rules`)

| Path | Read | Write | Limits |
|------|------|-------|--------|
| profiles/{userId}/* | Authenticated | Owner | Images < 50MB |
| posts/{userId}/* | Authenticated | Owner | Images < 50MB |
| chat/{conversationId}/* | Authenticated | Owner | Images < 50MB, Video < 200MB |
| voice_notes/* | Authenticated | Owner | Audio < 5MB |
| catalog/{userId}/* | Authenticated | Owner | Images < 50MB |

### Permissions

#### Android (21 permissions)

| Permission | Purpose |
|-----------|---------|
| INTERNET | Network access |
| CAMERA | Video calls, profile photos |
| RECORD_AUDIO | Voice calls, voice messages |
| ACCESS_FINE_LOCATION | GPS positioning |
| ACCESS_COARSE_LOCATION | Approximate location |
| ACCESS_BACKGROUND_LOCATION | Background location updates |
| READ_MEDIA_IMAGES/VIDEO/AUDIO | Android 13+ media access |
| READ/WRITE_EXTERNAL_STORAGE | Legacy storage (API < 33) |
| BLUETOOTH, BLUETOOTH_CONNECT | Audio routing |
| READ_PHONE_STATE, CALL_PHONE | Call handling |
| USE_FULL_SCREEN_INTENT | Incoming call UI |
| WAKE_LOCK, VIBRATE | Notifications |
| FOREGROUND_SERVICE | Background operations |
| POST_NOTIFICATIONS | Android 13+ notifications |
| SYSTEM_ALERT_WINDOW | Floating call overlay |

#### iOS (Background Modes)

| Mode | Purpose |
|------|---------|
| remote-notification | FCM push notifications |
| voip | VoIP calls |
| audio | Background audio |
| fetch | Background data fetch |

#### iOS Permission Descriptions

| Permission | Description |
|-----------|-------------|
| Camera | "Video calls and profile photos" |
| Photo Library | "Select profile images" |
| Photo Library Additions | "Save photos to library" |
| Location When In Use | "Nearby users and location-based matching" |
| Microphone | "Voice calls" |

---

## 12. Theming & Design System

### Color System (`app_colors.dart` - 471 lines)

#### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| Primary | #6366F1 | Indigo - main brand color |
| Secondary | #8B5CF6 | Purple - accents |
| Accent | #EC4899 | Pink - highlights |
| Tertiary | #06B6D4 | Cyan - secondary accents |

#### Status Colors

| Name | Hex | Usage |
|------|-----|-------|
| Success | #10B981 | Emerald green |
| Warning | #F59E0B | Amber |
| Error | #EF4444 | Red |
| Info | #0EA5E9 | Sky blue |

#### Connection Type Colors

| Type | Hex | Color |
|------|-----|-------|
| Activity Partner | #00D67D | Green |
| Event Companion | #FFB800 | Yellow |
| Friendship | #FF6B9D | Pink |
| Dating | #FF4444 | Red |

#### Business Archetype Colors

| Type | Hex |
|------|-----|
| Retail | #22C55E (Green) |
| Menu | #F59E0B (Amber) |
| Appointment | #3B82F6 (Blue) |
| Hospitality | #14B8A6 (Teal) |
| Portfolio | #8B5CF6 (Purple) |

#### Background Colors

| Mode | Primary | Secondary | Tertiary |
|------|---------|-----------|---------|
| Dark | #000000 | #1C1C1E | #2C2C2E |
| Light | #F5F5F7 | #FFFFFF | - |

### Typography System (`app_text_styles.dart` - 682 lines)

**Font Family:** Poppins (Google Fonts)

| Category | Size | Weight | Usage |
|----------|------|--------|-------|
| Display Large | 34px | Bold | Hero text |
| Display Medium | 28px | w700 | Section headers |
| Display Small | 24px | Bold | Screen titles |
| Headline Large | 22px | w600 | Card titles |
| Headline Medium | 20px | Bold | Subsections |
| Title Large | 18px | Bold | List item titles |
| Title Medium | 17px | w600 | Dialog titles |
| Title Small | 16px | w600 | Small headings |
| Body Large | 16px | Normal | Primary content |
| Body Medium | 15px | Normal | Standard text |
| Body Small | 14px | Normal | Secondary content |
| Label Large | 13px | w500 | Buttons, labels |
| Label Medium | 12px | w500 | Tags, badges |
| Label Small | 11px | w500 | Fine print |
| Caption | 12px | w400 | Timestamps, hints |

### Spacing Scale

| Name | Value |
|------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 20px |
| xxl | 24px |

### Border Radius Scale

| Name | Value |
|------|-------|
| Small | 8px |
| Medium | 12px |
| Large | 16px |
| XLarge | 24px |

### Theme Modes

| Mode | Background | Card | Text |
|------|-----------|------|------|
| Dark | #0f0f23 | #1C1C1E | White |
| Glassmorphism | Light + blur | Glass overlay | Dark |

### Glassmorphism Design Pattern

Used throughout the app:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withAlpha(15%),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withAlpha(30%)),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: content,
  ),
)
```

---

## 13. Platform Configuration & Device Compatibility

### Android Configuration

| Setting | Value |
|---------|-------|
| Application ID | com.plink.supper |
| Compile SDK | 36 (Android 15) |
| Target SDK | 34 (Android 14) |
| Min SDK | Flutter-managed (~21+, Android 5.0) |
| NDK Version | 28.2.13676358 |
| Java Version | 17 |
| Kotlin Target | JVM 17 |
| Gradle Version | 8.12 |
| MultiDex | Enabled |
| Core Library Desugaring | 2.0.3 |
| Google Services Plugin | 4.4.2 |

### iOS Configuration

| Setting | Value |
|---------|-------|
| Bundle ID | com.plink.supper |
| Deployment Target | Flutter-managed (~12.0+) |
| Supported Orientations | Portrait, Landscape Left/Right |
| Background Modes | remote-notification, voip, audio, fetch |

### Web Configuration

| Setting | Value |
|---------|-------|
| Firebase SDK | 10.7.0 (compat) |
| Display | Standalone (PWA) |
| Orientation | Portrait primary |
| Auth Domain | suuper2.firebaseapp.com |

### Windows Configuration

| Setting | Value |
|---------|-------|
| CMake Minimum | 3.14 |
| C++ Standard | C++17 |
| Unicode | Enabled |

### macOS Configuration

| Setting | Value |
|---------|-------|
| Principal Class | NSApplication |
| Main Nib | MainMenu |

### Platform Support Matrix

| Feature | Android | iOS | Web | Windows | macOS | Linux |
|---------|---------|-----|-----|---------|-------|-------|
| Firebase Auth | Yes | Yes | Yes | Yes | Yes | Yes |
| Cloud Firestore | Yes | Yes | Yes | Yes | Yes | Yes |
| FCM Push | Yes | Yes | Partial | No | No | No |
| Voice Calls (WebRTC) | Yes | Yes | Yes | Partial | Partial | No |
| Camera/Photos | Yes | Yes | Partial | No | No | No |
| GPS Location | Yes | Yes | Partial | No | No | No |
| Voice Input (STT) | Yes | Yes | Partial | No | No | No |
| Local Notifications | Yes | Yes | No | No | No | No |
| CallKit | No | Yes | No | No | No | No |
| SQLite (offline) | Yes | Yes | No | Yes | Yes | Yes |

---

## 14. CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/ci.yml`)

**Trigger:** Push to `main` or Pull Request to `main`

#### Job 1: Analyze & Test (Ubuntu latest)

```yaml
Steps:
  1. Checkout code
  2. Install Flutter 3.35.7 (master channel)
  3. Create .env file (test values)
  4. flutter pub get
  5. flutter analyze --no-fatal-infos
  6. flutter test
```

#### Job 2: Build Android APK (Ubuntu latest, conditional)

**Condition:** Only on push to `main` (not PRs)
**Depends on:** Job 1 must pass

```yaml
Steps:
  1. Checkout code
  2. Setup Java 17 (Temurin)
  3. Install Flutter 3.35.7 (master channel)
  4. Create .env from GitHub Secrets (GEMINI_API_KEY)
  5. Create google-services.json from Secrets (GOOGLE_SERVICES_JSON)
  6. flutter pub get
  7. flutter build apk --release
  8. Upload APK artifact (release-apk)
```

### Build Commands

```bash
# Development
flutter run                     # Run app (debug)
flutter run -d chrome           # Run on web
flutter run -d windows          # Run on Windows

# Testing
flutter test                    # Run all tests
flutter analyze                 # Static analysis

# Production
flutter build apk               # Android APK
flutter build appbundle          # Play Store bundle
flutter build web                # Web build
flutter build windows            # Windows build

# Maintenance
flutter clean && flutter pub get # Full reset
flutter pub get                  # Install dependencies
```

---

## 15. Testing Strategy

### Test Summary

| Metric | Value |
|--------|-------|
| **Total Test Cases** | **161** |
| Unit Tests (models) | 146 |
| Widget Tests | 6 |
| Service Tests | 10 |
| Integration Tests | 5 |
| Test Files | 11 |
| Test Helper Files | 1 |

### Test Structure

```
test/
├── test_helpers.dart                          # Firebase mock setup (0 tests)
├── widget_test.dart                           # App shell rendering (6 tests)
├── models/
│   ├── booking_model_test.dart                # BookingModel (12 tests)
│   ├── catalog_item_test.dart                 # CatalogItem (12 tests)
│   ├── conversation_model_test.dart           # ConversationModel (18 tests)
│   ├── extended_user_profile_test.dart        # ExtendedUserProfile (22 tests)
│   ├── post_model_test.dart                   # PostModel (30 tests)
│   ├── review_model_test.dart                 # ReviewModel (16 tests)
│   └── user_profile_test.dart                 # UserProfile (30 tests)
└── services/
    └── account_type_service_test.dart         # AccountTypeService (10 tests)

integration_test/
└── scroll_performance_test.dart               # Performance (5 tests)
```

### Test Infrastructure

| Package | Purpose |
|---------|---------|
| flutter_test | Widget and unit testing framework |
| integration_test | Integration test driver |
| mockito | Mock object generation |
| fake_cloud_firestore | Firestore mock for testing |

### Test Helpers (`test_helpers.dart`)

```dart
setupFirebaseCoreMocks()    // Mocks Firebase Core, Auth, Firestore via MethodChannel
tearDownFirebaseCoreMocks()  // Cleanup mocked platform channels
// Also mocks SharedPreferences for theme/token persistence
```

---

### Detailed Test Cases by File

#### 1. Widget Tests — `widget_test.dart` (6 tests)

**Group: App Widget Tests**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | App shell renders correctly | MaterialApp, Scaffold, "Supper App" text found |
| 2 | ProviderScope wraps MaterialApp correctly | ProviderScope and MaterialApp both in widget tree |
| 3 | Bottom navigation bar structure test | 4 nav items: Discover, Messages, Networking, Profile with correct icons |
| 4 | Navigation bar tap changes index | Tapping tabs changes displayed text (Tab 0 → Tab 1 → Tab 3) |
| 5 | Loading indicator renders correctly | CircularProgressIndicator renders |
| 6 | Error screen structure test | Error icon, error text, and retry button all render |

---

#### 2. BookingModel Tests — `booking_model_test.dart` (12 tests)

**Group: BookingStatus**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses all statuses | pending, confirmed, completed, cancelled all parse correctly |
| 2 | fromString defaults to pending | null and unknown strings → BookingStatus.pending |

**Group: formattedDate**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | formats January correctly | DateTime(2024, 1, 15) → "Jan 15, 2024" |
| 4 | formats December correctly | DateTime(2024, 12, 25) → "Dec 25, 2024" |
| 5 | formats single-digit day | DateTime(2024, 3, 5) → "Mar 5, 2024" |

**Group: statusLabel**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 6 | returns correct labels for all statuses | Pending, Confirmed, Completed, Cancelled labels match |

**Group: timeAgo**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | just now for less than 1 minute | < 60 seconds → "Just now" |
| 8 | minutes ago | 30 minutes → "30m ago" |
| 9 | hours ago | 5 hours → "5h ago" |
| 10 | days ago | 3 days → "3d ago" |
| 11 | falls back to formattedDate after 7 days | 10 days → returns formattedDate string |

**Group: copyWith**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 12 | preserves unchanged fields | copyWith(status) updates status, preserves all other fields |

---

#### 3. CatalogItem Tests — `catalog_item_test.dart` (12 tests)

**Group: CatalogItemType**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses service | 'service' → CatalogItemType.service |
| 2 | fromString maps legacy booking to service | 'booking' → CatalogItemType.service (backwards compat) |
| 3 | fromString defaults to product | 'product', null, 'unknown' all → CatalogItemType.product |

**Group: formattedPrice**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 4 | null price returns Contact for price | null price → "Contact for price" |
| 5 | INR uses rupee symbol | 500 INR → "₹500" |
| 6 | USD uses dollar symbol | 25 USD → "$25" |
| 7 | whole number omits decimals | 100.0 INR → "₹100" |
| 8 | fractional price shows 2 decimals | 99.99 INR → "₹99.99" |
| 9 | unknown currency uses currency code | 50 EUR → "EUR50" |

**Group: copyWith**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | preserves unchanged fields | copyWith(name) updates name, preserves others |
| 11 | can update multiple fields | copyWith(price, currency, isAvailable) updates all three |

**Group: defaults**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 12 | default values are correct | currency=INR, type=product, isAvailable=true, viewCount=0, isFeatured=false, tags=[] |

---

#### 4. ConversationModel Tests — `conversation_model_test.dart` (18 tests)

**Group: getOtherParticipantId**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | returns the other participant | user-1 → user-2, user-2 → user-1 |
| 2 | returns empty string when only self | Single participant → '' |

**Group: getDisplayName**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | returns other participant name for 1-on-1 | user-1 sees "Bob", user-2 sees "Alice" |
| 4 | returns group name for group chat | isGroup=true → "Team Chat" |
| 5 | returns Group Chat when group has no name | isGroup=true, no name → "Group Chat" |
| 6 | returns Unknown User when not in names map | Missing participant → "Unknown User" |

**Group: getDisplayPhoto**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | returns other participant photo for 1-on-1 | user-1 → bob.jpg |
| 8 | returns group photo for group chat | isGroup=true → groupPhoto URL |
| 9 | returns null for group without photo | isGroup=true, no photo → null |

**Group: unread messages**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | hasUnreadMessages true when count > 0 | unreadCount=3 → true |
| 11 | hasUnreadMessages false when count is 0 | unreadCount=0 → false |
| 12 | hasUnreadMessages false when user not in map | Missing user → false |
| 13 | getUnreadCount returns correct count | count=5 → 5 |
| 14 | getUnreadCount returns 0 for missing user | Missing → 0 |

**Group: typing**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | isUserTyping true when typing | isTyping=true → true |
| 16 | isUserTyping false when not typing | isTyping=false → false |
| 17 | isUserTyping false for missing user | Missing → false |

**Group: business chat**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 18 | isBusinessChat returns true with metadata flag | metadata['isBusinessChat']=true → true |

*Additional business chat tests:* isBusinessChat false without metadata, business getters extract from metadata (businessId, businessName, businessLogo, businessSenderId), getDisplayNameWithBusiness shows business/personal name based on sender, getDisplayPhotoWithBusiness shows logo or falls back to participant photo, copyWith preserves unchanged fields.

---

#### 5. ExtendedUserProfile Tests — `extended_user_profile_test.dart` (22 tests)

**Group: displayLocation**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | returns city when set | city='Mumbai' → 'Mumbai' |
| 2 | returns location when city is null | city=null → 'Maharashtra' |
| 3 | returns Location not set when both null | both null → 'Location not set' |
| 4 | returns Location not set when city is empty | city='' → 'Location not set' |

**Group: formattedDistance**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 5 | returns null when distance is null | null → null |
| 6 | returns meters when < 1 km | 0.5 km → '500 m away' |
| 7 | returns km when >= 1 km | 3.7 km → '3.7 km away' |
| 8 | rounds meters to nearest integer | 0.123 km → '123 m away' |

**Group: hasConnectionType**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 9 | returns true when type is present | 'friendship' in list → true |
| 10 | returns false when type is absent | 'dating' not in list → false |

**Group: activityNames**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 11 | returns list of activity names | [Activity(Running), Activity(Swimming)] → ['Running', 'Swimming'] |
| 12 | returns empty list when no activities | null → [] |

**Group: helper getters**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 13 | isBusiness returns true for business type | accountType=business → isBusiness=true |
| 14 | isPersonal returns true for personal type | default → isPersonal=true |
| 15 | isVerifiedAccount checks verification | verified → true, unverified → false |
| 16 | isPendingVerification checks pending | pending → true |

**Group: fromMap**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 17 | parses legacy string activities | ['Running', 'Yoga'] → string list |
| 18 | parses map activities | [{'name': 'Swimming'}] → name extracted |
| 19 | display name falls back to phone | name='' → uses phone number |
| 20 | display name falls back from User to phone | name='User' → uses phone number |
| 21 | extracts business name from businessProfile | businessName='My Shop', category='Retail' |
| 22 | extracts verification status | verification.status='verified' → VerificationStatus.verified |

---

#### 6. PostModel Tests — `post_model_test.dart` (30 tests)

**Group: matchesIntent** (16 intent-matching test cases)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | offering matches seeking | offering ↔ seeking = true |
| 2 | selling matches buying | selling ↔ buying = true |
| 3 | giving matches requesting | giving ↔ requesting = true |
| 4 | lost matches found | lost ↔ found = true |
| 5 | hiring matches job_seeking | hiring ↔ job_seeking = true |
| 6 | renting matches rent_seeking | renting ↔ rent_seeking = true |
| 7 | symmetric intents with same action type | is_symmetric=true, same action → true |
| 8 | free vs paid exchange incompatibility | free offering ↔ paid seeking = false |
| 9 | equity vs paid exchange incompatibility | equity ↔ paid = false |
| 10 | same non-symmetric action type | selling ↔ selling = false |
| 11 | neutral action type always matches | neutral ↔ any action = true |
| 12 | meetup matches meetup (legacy symmetric) | meetup ↔ meetup = true |
| 13 | dating matches dating (legacy symmetric) | dating ↔ dating = true |
| 14 | friendship matches friendship (legacy) | friendship ↔ friendship = true |
| 15 | connecting matches connecting (legacy) | connecting ↔ connecting = true |
| 16 | unrelated action types return false | hiring ↔ selling = false |

**Group: matchesPrice** (7 price-matching test cases)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 17 | both no price returns true | both null → true |
| 18 | seller price within buyer max | 50 within max=100 → true |
| 19 | seller price above buyer max | 150 > max=100 → false |
| 20 | seller price within buyer min-max range | 75 within [50, 100] → true |
| 21 | seller price below buyer min | 30 < min=50 → false |
| 22 | reversed roles: buyer range includes seller | seller=80, buyer max=100 → true |
| 23 | only one side has price | one null → true |

**Group: computed getters** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 24 | primaryIntent returns from analysis | analysis['primary_intent'] → getter |
| 25 | primaryIntent falls back to originalPrompt | no analysis → originalPrompt |
| 26 | actionType from analysis | analysis['action_type'] → getter |
| 27 | actionType defaults to neutral | missing → 'neutral' |
| 28 | searchKeywords from analysis | ['plumber', 'repair', 'pipe'] |
| 29 | categoryDisplay formats domain | 'home_services' → 'Home Services' |
| 30 | emotionalTone defaults to casual | missing → 'casual' |

---

#### 7. ReviewModel Tests — `review_model_test.dart` (16 tests)

**Group: RatingSummary** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | empty factory creates zeroed summary | distribution[5]=0, totalReviews=0 |
| 2 | getPercentage returns 0 when no reviews | empty → 0% |
| 3 | getPercentage calculates correct distribution | 5-star=50%, 4-star=30%, 1-star=5% |
| 4 | getPercentage returns 0 for missing rating | 3-star missing → 0% |
| 5 | fromMap parses string keys to int | {'5': 25} → distribution[5]=25 |
| 6 | toMap converts int keys to string | distribution[5]=10 → {'5': 10} |
| 7 | fromMap/toMap round-trip | round-trip preserves all values |

**Group: formattedDate** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 8 | minutes ago | 15 min → '15 min ago' |
| 9 | hours ago | 3 hours → '3 hours ago' |
| 10 | yesterday | 1 day → 'Yesterday' |
| 11 | days ago | 4 days → '4 days ago' |
| 12 | weeks ago | 14 days → '2 weeks ago' |
| 13 | months ago | 60 days → '2 months ago' |
| 14 | years ago | 400 days → '1 years ago' |

**Group: copyWith & defaults** (2 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | copyWith preserves unchanged fields | rating updated, other fields preserved |
| 16 | default values correct | images=[], isVerifiedPurchase=false, isVisible=true, isFlagged=false |

---

#### 8. UserProfile Tests — `user_profile_test.dart` (30 tests)

**Group: AccountType** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses business variants | 'business', 'Business', 'business account' → business |
| 2 | fromString defaults to personal | null, 'unknown', '' → personal |
| 3 | displayName returns correct labels | personal → 'Personal Account', business → 'Business Account' |

**Group: AccountStatus** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 4 | fromString parses all statuses | 'suspended', 'pending_verification' parse correctly |
| 5 | fromString defaults to active | null, 'unknown' → active |
| 6 | displayName returns correct labels | active → 'Active', pendingVerification → 'Pending Verification' |

**Group: VerificationStatus** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | fromString parses all statuses | 'pending', 'verified', 'rejected' parse correctly |
| 8 | fromString defaults to none | null, 'xyz' → none |
| 9 | displayName returns correct labels | none → 'Not Verified', verified → 'Verified' |

**Group: DayHours** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | formatted shows open-close times | '09:00' - '18:00' → '09:00 - 18:00' |
| 11 | formatted shows Closed when isClosed | isClosed=true → 'Closed' |
| 12 | formatted shows Not set when null | null times → 'Not set' |
| 13 | fromMap creates correct instance | map → open='10:00', close='22:00' |
| 14 | toMap round-trips correctly | round-trip preserves values |

**Group: BusinessHours** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | defaultHours creates Mon-Fri 9-18, Sat 10-16, Sun closed | Schedule matches expected defaults |
| 16 | fromMap creates schedule from nested map | monday open='08:00', tuesday isClosed=true |
| 17 | toMap round-trips correctly | round-trip preserves schedule |

**Group: BusinessProfile** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 18 | fromMap with null returns empty profile | null → businessName=null, profileViews=0, isLive=false |
| 19 | fromMap handles legacy field names | companyName → businessName, industry → softLabel |
| 20 | fromMap prefers new field names over legacy | New field names override legacy |
| 21 | copyWith preserves unchanged fields | Updates businessName, preserves rest |
| 22 | isCurrentlyOpen delegates to hours | No hours → false |

**Group: VerificationData** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 23 | fromMap with null returns default | null → status=none, verifiedAt=null |
| 24 | fromMap parses status correctly | 'verified' → VerificationStatus.verified |
| 25 | toMap round-trips status | pending → 'pending' |

**Group: UserProfile** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 26 | isBusiness true when businessProfile set | businessProfile set → true |
| 27 | isBusiness false when null | null → false |
| 28 | isVerifiedAccount checks verification | verified → true, unverified → false |
| 29 | copyWith preserves unchanged fields | Updates name, preserves email and uid |
| 30 | id defaults to uid | id == uid |

---

#### 9. AccountTypeService Tests — `account_type_service_test.dart` (10 tests)

**Group: getAccountFeatures**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | personal account has limited features | canBuySell=true, maxPosts=5, verifiedBadge=false, portfolio=false, analytics=false |
| 2 | business account has full features | maxPosts=-1 (unlimited), verifiedBadge=true, portfolio=true, analytics=true, maxTeamMembers=10 |

**Group: isFeatureAvailable**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | personal cannot access portfolio | portfolio → false |
| 4 | business can access portfolio | portfolio → true |
| 5 | personal can buy/sell | canBuySell → true |
| 6 | unknown feature returns false | 'nonexistent' → false for both types |

**Group: getPostLimit**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | personal limit is 5 | personal → 5 |
| 8 | business limit is -1 (unlimited) | business → -1 |

**Group: getAccountTypeInfo**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 9 | personal account info | name='Personal Account', icon='person', color is int |
| 10 | business account info | name='Business Account', icon='business', color is int |

---

#### 10. Integration Tests — `scroll_performance_test.dart` (5 tests)

**Group: Performance Tests**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | Chat list scroll performance | 5 scroll cycles (up/down fling) complete in < 3000ms |
| 2 | Message list rendering performance | Message list scrolls smoothly after tapping chat tile |
| 3 | Navigation performance | Tab navigation across 3 tabs completes in < 2000ms |
| 4 | Image loading performance | Images render, count > 0 after 2-second load wait |
| 5 | All tabs navigation possible | BottomNavigationBar has ≥ 3 items |

---

### Test Coverage Matrix

```
┌─────────────────────────┬───────┬────────┬───────────┬──────────┬─────────┐
│ Model / Area            │ Parse │ Format │ Serialize │ Compute  │ Copy    │
├─────────────────────────┼───────┼────────┼───────────┼──────────┼─────────┤
│ BookingModel            │  ✓    │  ✓     │           │  ✓       │  ✓      │
│ CatalogItem             │  ✓    │  ✓     │           │          │  ✓      │
│ ConversationModel       │       │        │           │  ✓       │  ✓      │
│ ExtendedUserProfile     │  ✓    │  ✓     │  ✓        │  ✓       │         │
│ PostModel               │       │        │           │  ✓       │         │
│ ReviewModel             │  ✓    │  ✓     │  ✓        │          │  ✓      │
│ UserProfile             │  ✓    │  ✓     │  ✓        │  ✓       │  ✓      │
│ AccountTypeService      │       │        │           │  ✓       │         │
├─────────────────────────┼───────┼────────┼───────────┼──────────┼─────────┤
│ Widget (App shell)      │       │        │           │  ✓       │         │
│ Integration (Perf)      │       │        │           │  ✓       │         │
└─────────────────────────┴───────┴────────┴───────────┴──────────┴─────────┘

Legend: Parse = enum/string parsing, Format = display formatting,
        Serialize = fromMap/toMap round-trip, Compute = computed getters/logic,
        Copy = copyWith preservation
```

### Recommended Test Expansion

#### Widget Testing (Priority: High)

| Widget | Test Areas |
|--------|-----------|
| SafeCircleAvatar | Fallback rendering, rate-limit handling |
| CatalogCardWidget | Compact vs normal, availability badge |
| ChatMessageBubble | Sent vs received, read receipts |
| VoiceOrb | State transitions, animation states |
| MatchCardWithActions | Score display, action button callbacks |
| GlassTextField | Input handling, search variant |

#### Feature Testing (Priority: High)

| Feature | Test Areas |
|---------|-----------|
| Authentication | Login/signup flows, OTP verification, device session |
| Post Creation | Intent analysis mock, embedding generation |
| Matching | Score calculation, threshold filtering |
| Chat | Message sending, typing indicators, media |
| Business | Catalog CRUD, booking status changes |

#### Integration Testing (Priority: Medium)

| Flow | Test Areas |
|------|-----------|
| End-to-End Auth | Splash → Login → Home |
| Post & Match | Create post → Find matches → View results |
| Chat Flow | Open conversation → Send message → Receive |
| Business Flow | Enable business → Add catalog → Receive booking |

---

## 16. Performance & Optimization

### Caching Strategy

| Cache | Storage | TTL | Max Size | Purpose |
|-------|---------|-----|----------|---------|
| Embedding Cache | In-memory (LRU) | 24 hours | 1000 entries | Avoid re-computing embeddings |
| Match Cache | In-memory (LRU) | 30 minutes | 1000 entries | Avoid re-running match queries |
| Message Cache | In-memory | 10 minutes | 20 conversations × 50 msgs | Fast message access |
| Photo URL Cache | In-memory | 1 hour | 100 entries | Avoid Firestore reads for photos |
| Current User Cache | In-memory + Firestore | 5 minutes | 1 entry | Fast current user access |
| Firestore Cache | Disk (native) | Persistent | 50MB | Offline support |
| Image Cache | Disk | Persistent | 50 items | CachedNetworkImage |

### Rate Limiting & Debouncing

| Operation | Limit | Purpose |
|-----------|-------|---------|
| Location updates | 60s + 100m movement | Prevent Firestore flooding |
| Post creation | 5-10/day (by account type) | Prevent spam |
| Photo URL retries | 5-minute cooldown | Handle 429 errors |
| Firestore queries | 200 docs max per match | Control costs |
| Service initialization | Once per app lifecycle | Singleton pattern |

### Memory Management

| Component | Strategy |
|-----------|----------|
| AppOptimizer | 100MB max memory cache, 50 image cache entries, 30-min cleanup |
| MemoryManager | 10MB max buffer, 1MB optimal chunk, 1-min periodic cleanup |
| Image Compression | Before upload (flutter_image_compress) |
| Video Compression | Before upload (video_compress) |
| LRU Eviction | Oldest entries removed when cache full |

### Firestore Optimization

- `limit()` on all queries (mandatory rule)
- `persistenceEnabled: true` with 50MB cache
- Pagination with `startAfter` cursor
- Debounced writes to prevent thrashing
- Batch operations with 500-item limit
- Index-backed queries (firestore.indexes.json)

### Build Optimization

| Setting | Value | Purpose |
|---------|-------|---------|
| MultiDex | Enabled | Support >65K methods |
| ProGuard | Enabled (release) | Code shrinking |
| Core Library Desugaring | 2.0.3 | Java 17 backport |
| Gradle Daemon | Disabled | Memory stability |
| JVM Args | -Xmx2048m | Build memory |

---

## 17. API Configuration & Environment

### Environment Variables (`.env`)

| Variable | Purpose |
|----------|---------|
| GEMINI_API_KEY | Google Gemini AI API key |
| GOOGLE_CLIENT_ID | Google Sign-In OAuth client ID |
| FIREBASE_WEB_API_KEY | Firebase Web API key |
| FIREBASE_WEB_AUTH_DOMAIN | Firebase Auth domain |
| FIREBASE_WEB_PROJECT_ID | Firebase project ID |
| FIREBASE_WEB_STORAGE_BUCKET | Firebase Storage bucket |
| FIREBASE_WEB_MESSAGING_SENDER_ID | FCM sender ID |
| FIREBASE_WEB_APP_ID | Firebase Web app ID |
| FIREBASE_ANDROID_API_KEY | Firebase Android API key |
| FIREBASE_ANDROID_APP_ID | Firebase Android app ID |
| FIREBASE_IOS_API_KEY | Firebase iOS API key |
| FIREBASE_IOS_APP_ID | Firebase iOS app ID |
| FIREBASE_IOS_BUNDLE_ID | Firebase iOS bundle ID |

### API Configuration (`api_config.dart`)

| Setting | Value |
|---------|-------|
| Gemini Flash Model | gemini-2.5-flash |
| Gemini Embedding Model | gemini-embedding-001 |
| API Base URL | https://generativelanguage.googleapis.com |
| Temperature | 0.7 |
| Top K | 40 |
| Top P | 0.95 |
| Max Output Tokens | 1024 |
| Embedding Dimension | 768 |
| Connection Timeout | 30 seconds |
| Receive Timeout | 30 seconds |
| API Call Timeout | 45 seconds |
| Max Retries | 3 |
| Retry Delay | 2 seconds |

### Firebase Project

| Setting | Value |
|---------|-------|
| Project ID | suuper2 |
| Auth Domain | suuper2.firebaseapp.com |
| Storage Bucket | suuper2.firebasestorage.app |
| Realtime Database | suuper2-default-rtdb.firebaseio.com |
| Android Package | com.plink.supper |

### WebRTC Configuration

| Setting | Value |
|---------|-------|
| STUN Server 1 | stun:stun.l.google.com:19302 |
| STUN Server 2 | stun:openrelay.metered.ca:80 |
| TURN Server | openrelay.metered.ca (443, TCP/UDP) |
| ICE Candidate Pool | 10 |

### Geocoding API Fallback Chain

| Priority | API | Type |
|----------|-----|------|
| 1 (Web) | BigDataCloud | Free, CORS-friendly |
| 2 (Web) | OpenCage | Free tier |
| 3 (Mobile) | OSM Nominatim | Free |
| 4 (Fallback) | Flutter geocoding package | Local |

---

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

## Appendix A: Key File Paths Quick Reference

| Purpose | Path |
|---------|------|
| Entry Point | lib/main.dart |
| Firebase Config | lib/firebase_options.dart |
| API Config | lib/res/config/api_config.dart |
| Colors | lib/res/config/app_colors.dart |
| Typography | lib/res/config/app_text_styles.dart |
| Theme | lib/config/app_theme.dart |
| Auth Service | lib/services/auth_service.dart |
| Gemini AI | lib/services/ai_services/gemini_service.dart |
| Post Service | lib/services/unified_post_service.dart |
| Matching Service | lib/services/unified_matching_service.dart |
| Chat Service | lib/services/chat_services/conversation_service.dart |
| Security Rules | firestore.rules |
| Storage Rules | storage.rules |
| CI/CD | .github/workflows/ci.yml |
| Environment | .env |

---

---

## Appendix C: Supported Countries (Phone Auth)

India (+91), USA (+1), UK (+44), Australia (+61), UAE (+971), Saudi Arabia (+966), Singapore (+65), Malaysia (+60), Germany (+49), France (+33), Italy (+39), Japan (+81), South Korea (+82), China (+86), Brazil (+55), Mexico (+52), South Africa (+27), Nigeria (+234), Pakistan (+92), Bangladesh (+880), Nepal (+977), Sri Lanka (+94), Philippines (+63), Indonesia (+62), Thailand (+66), Vietnam (+84), Russia (+7), Spain (+34), Netherlands (+31), Sweden (+46)

---

*This documentation was generated from a comprehensive codebase analysis of 140+ Dart files across the Supper Flutter application.*
