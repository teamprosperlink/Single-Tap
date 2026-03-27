# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Single Tap** is a Flutter-based AI-powered matching app that connects people for various purposes (marketplace, dating, friendship, jobs, lost & found, networking, etc.) through intelligent intent understanding and semantic matching.

### Core Technology Stack
- **Flutter** (Dart SDK `^3.8.1`)
- **Firebase**: Authentication, Firestore, Storage, Cloud Messaging
- **Google Gemini AI**: Intent analysis, semantic embeddings, natural language understanding
- **WebRTC**: Real-time peer-to-peer voice calling

## Development Commands

```bash
# Run
flutter run                    # Run on connected device/emulator
flutter run -d chrome          # Run on web
flutter run --release          # Production build

# Test
flutter test                   # Run all tests

# Build
flutter build apk              # Android APK
flutter build appbundle        # Android App Bundle (Play Store)
flutter build ios              # iOS (requires macOS)
flutter build web              # Web build

# Dependencies
flutter clean                  # Clean build artifacts
flutter pub get                # Install dependencies
```

## Architecture Overview

### Key Architectural Principles

1. **AI-Driven Intent Understanding**: No hardcoded categories. Uses Gemini AI to understand user intent dynamically from natural language input.

2. **Semantic Matching**: Posts matched using vector embeddings and cosine similarity:
   - Intent complementarity (buyer <-> seller, lost <-> found, etc.)
   - Semantic similarity of embeddings (70% weight)
   - Location proximity (15% weight)
   - Price compatibility (when applicable)

3. **Single Source of Truth**: All user posts stored in `posts` collection only.

### Core Services

| Service | Location | Purpose |
|---|---|---|
| `UniversalIntentService` | `lib/services/` | Processes user input, creates posts |
| `UnifiedPostService` | `lib/services/` | PRIMARY service for all post operations |
| `UnifiedMatchingService` | `lib/services/` | Semantic matching using AI embeddings |
| `GeminiService` | `lib/services/location_services/` | Gemini API for embeddings & intent analysis |
| `NotificationService` | `lib/services/` | FCM tokens, local & Firestore notifications |
| `ConnectionService` | `lib/services/` | Connection requests (send, accept, reject, cancel) |
| `LocationService` | `lib/services/location_services/` | GPS location management |
| `PhotoCacheService` | `lib/services/profile services/` | Photo caching |
| `AuthService` | `lib/services/` | Firebase authentication |
| `BusinessService` | `lib/services/` | Business profiles |
| `GroupChatService` | `lib/services/` | Group chat functionality |
| `VoiceCallService` | `lib/services/other services/` | 1:1 voice calls |
| `GroupVoiceCallService` | `lib/services/other services/` | Group voice calls |

### Data Flow
```
User Input -> UniversalIntentService -> Gemini AI Analysis -> UnifiedPostService
                                                                  |
                                             posts/{postId} (with embedding)
                                                                  |
                                          UnifiedMatchingService (semantic search)
                                                                  |
                                                Matched Profiles
```

### Screen Structure

**Main navigation uses TabBar** (no BottomNavigationBar):

| Tab | Screen | Description |
|---|---|---|
| Home | `HomeScreen` | Main feed / discovery |
| Chat | `ConversationsScreen` | Chat conversations |
| Networking | Networking screens | "Around Me" + "My Network" sub-tabs |
| Nearby | Nearby screens | Browse nearby people |
| Professional | Dashboard | Professional profile |
| Business | Dashboard | Business profile |

**Screen folders** in `lib/screens/`:
- `business/` - Business profiles, archetypes, dashboards
- `call/` - Voice call screens
- `chat/` - Conversations and chat
- `home/` - Main home screen
- `location/` - Location screens
- `login/` - Authentication
- `near by/` - Local discovery
- `networking/` - Networking profiles, onboarding, live connect
- `product/` - Product detail/listings
- `professional/` - Professional dashboard
- `profile/` - User profile management

### Database Structure (Firestore)

**posts/** - All user posts (single source of truth)
```javascript
{
  userId, originalPrompt, title, description,
  intentAnalysis: {
    primary_intent, action_type: "seeking"|"offering"|"neutral",
    domain, entities, complementary_intents, search_keywords
  },
  embedding: number[],  // 768-dim vector
  keywords, location, latitude, longitude,
  price, priceMin, priceMax,
  isActive, createdAt, expiresAt, clarificationAnswers
}
```

**users/** - User profiles
```javascript
{
  uid, name, email, photoUrl, bio,
  location, latitude, longitude, interests,
  isOnline, lastSeen
}
```

**conversations/** - Chat conversations with subcollection `messages/`

**notifications/** - Cross-user notifications (connection requests, messages, etc.)

**connection_requests/** - Connection requests between users

## Critical Constraints

### DO NOT
- Never hardcode categories or intents - rely on AI understanding
- Never create video calling features (voice-only)
- Never query Firestore without `limit()`
- Never commit API keys to version control
- Never show exact GPS coordinates (privacy)

### DO
- Use `UnifiedPostService` for all post operations
- Use semantic matching (embeddings + cosine similarity)
- Handle errors gracefully with user-friendly messages
- Use `StreamBuilder` for real-time updates
- Cache frequently accessed data
- Use pagination for large lists

## Shared UI Components

### chat_common.dart
Located at `lib/widgets/chat widgets/chat_common.dart`:
- `formatDisplayName(String name)`: Title Case conversion
- `chatThemeColors`: Gradient themes for message bubbles
- `ChatMessageInput`: Message input with emoji picker
- `ChatEmojiPicker`: Emoji picker widget
- `ChatMessageBubble`: Gradient bubbles with read receipts

## Performance

- Firestore offline persistence with unlimited cache (in `main.dart`)
- Photo caching via `PhotoCacheService` and `CachedNetworkImage`
- Embedding caching for 24 hours
- Memory management via `MemoryManager` (`lib/res/utils/memory_manager.dart`)
- Lazy loading with pagination (20 items per page)

## Firestore Indexes Required

Common composite indexes:
- `conversations`: `participants` (array) + `lastMessageTime` (desc)
- `posts`: `userId` (asc) + `isActive` (asc) + `createdAt` (desc)

## Live Connect Filter Behavior

- **Near Me**: Toggles independently (works alongside any category filter)
- **Category Filters** (Dating, Friendship, Business, Sports): Mutually exclusive - only ONE at a time
