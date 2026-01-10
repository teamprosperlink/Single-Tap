# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Supper** is a Flutter-based AI-powered matching app that connects people for various purposes (marketplace, dating, friendship, jobs, lost & found, etc.) through intelligent intent understanding and semantic matching.

### Core Technology Stack
- **Flutter 3.35.7** (Dart 3.9.2)
- **Firebase**: Authentication, Firestore, Storage, Cloud Messaging
- **Google Gemini AI**: Intent analysis, semantic embeddings, natural language understanding
- **WebRTC**: Real-time peer-to-peer communication

## Development Commands

### Running the App
```bash
flutter run              # Run on connected device/emulator
flutter run -d chrome    # Run on web
flutter run --release    # Production build
```

### Testing
```bash
flutter test                                # Run all tests
flutter test test/widget_test.dart          # Run specific test
flutter test test/performance/              # Run performance tests
```

### Building
```bash
flutter build apk                           # Android APK
flutter build appbundle                     # Android App Bundle (for Play Store)
flutter build ios                           # iOS build (requires macOS)
flutter build web                           # Web build
```

### Cleaning & Dependencies
```bash
flutter clean                              # Clean build artifacts
flutter pub get                            # Install dependencies
flutter pub upgrade                        # Update dependencies
flutter pub outdated                       # Check for outdated packages
```

## Architecture Overview

### Key Architectural Principles

1. **AI-Driven Intent Understanding**: No hardcoded categories. The system uses Gemini AI to understand user intent dynamically from natural language input.

2. **Semantic Matching**: Posts are matched using vector embeddings and cosine similarity, not keyword matching. The matching algorithm considers:
   - Intent complementarity (buyer ↔ seller, lost ↔ found, etc.)
   - Semantic similarity of embeddings (70% weight)
   - Location proximity (15% weight)
   - Price compatibility (when applicable)

3. **Single Source of Truth**: All user posts are stored in the `posts` collection only. Old collections (`user_intents`, `intents`, `processed_intents`) are automatically deleted on first app launch.

### Core Services Architecture

#### Intent & Matching Pipeline
```
User Input → UnifiedIntentProcessor → Gemini AI Analysis → UnifiedPostService
                                                                ↓
                                           posts/{postId} (with embedding)
                                                                ↓
                                        UnifiedMatchingService (semantic search)
                                                                ↓
                                              Matched Profiles
```

**Key Services:**
- `UniversalIntentService`: Processes user input and creates posts
- `UnifiedIntentProcessor`: Handles clarification dialogs when intent is ambiguous
- `UnifiedPostService`: ⭐ PRIMARY service for all post operations (create, find matches, delete)
- `UnifiedMatchingService`: Performs semantic matching using AI embeddings
- `GeminiService`: Interacts with Google Gemini API for embeddings and intent analysis
- `NotificationService`: Handles FCM tokens, local notifications, and cross-user Firestore notifications
- `ConnectionService`: Manages connection requests (send, accept, reject, cancel)

#### Data Flow
1. User types natural language prompt (e.g., "iPhone", "looking for friend in NYC")
2. System analyzes intent using Gemini AI
3. If ambiguous, shows clarification dialog
4. Creates post with AI-generated embedding in `posts` collection
5. Finds matches using semantic similarity
6. Returns matched user profiles

### Database Structure

#### Firestore Collections

**posts/** - Single source of truth for all user posts
```javascript
{
  userId: string,
  originalPrompt: string,           // What user typed
  title: string,                    // AI-generated
  description: string,              // AI-generated
  intentAnalysis: {                 // AI understanding (no hardcoded categories!)
    primary_intent: string,
    action_type: "seeking" | "offering" | "neutral",
    domain: string,
    entities: {...},
    complementary_intents: [...],
    search_keywords: [...]
  },
  embedding: number[],              // 768-dim vector for semantic search
  keywords: string[],
  location: string,
  latitude: number,
  longitude: number,
  price: number,
  priceMin: number,
  priceMax: number,
  isActive: boolean,
  createdAt: timestamp,
  expiresAt: timestamp,
  clarificationAnswers: {...}
}
```

**users/** - User profiles
```javascript
{
  uid: string,
  name: string,
  email: string,
  photoUrl: string,
  bio: string,
  location: string,
  latitude: number,
  longitude: number,
  interests: string[],
  isOnline: boolean,
  lastSeen: timestamp
}
```

**conversations/** - Chat conversations
```javascript
{
  participants: [userId1, userId2],
  lastMessage: string,
  lastMessageTime: timestamp,
  unreadCount: {userId: number},
  messages/{messageId}: {
    senderId: string,
    receiverId: string,
    text: string,
    imageUrl: string,
    timestamp: timestamp,
    read: boolean
  }
}
```

**notifications/** - Cross-user notifications
```javascript
{
  userId: string,           // Target user who should receive notification
  senderId: string,         // User who triggered the notification
  title: string,
  body: string,
  type: string,             // 'connection_request', 'connection_accepted', 'message', etc.
  data: {...},              // Additional payload data
  read: boolean,
  createdAt: timestamp
}
```

**connection_requests/** - Connection requests between users
```javascript
{
  senderId: string,
  senderName: string,
  senderPhoto: string,
  receiverId: string,
  message: string,
  status: 'pending' | 'accepted' | 'rejected',
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Screen Navigation Structure

Main navigation (bottom tabs):
1. **Discover** (`UniversalMatchingScreen`) - Create posts and find matches
2. **Messages** (`ConversationsScreen`) - Chat conversations
3. **Live Connect** (`LiveConnectTabScreen`) - Browse nearby people with filters
4. **Profile** (`ProfileWithHistoryScreen`) - User profile and post history

## Critical Implementation Details

### Voice Calling (IMPORTANT)

**Current Issue**: When user A calls user B, both users see their own profile instead of the other person's profile during the call. This needs to be fixed.

**Key Points:**
- **Voice-only calling** - NO video calling feature should be implemented
- Firestore for call signaling
- FCM for push notifications

### AI Configuration

API keys and model settings are centralized in `lib/config/api_config.dart`:
- Gemini Flash model for intent analysis
- Text-embedding-004 for semantic embeddings (768 dimensions)
- **IMPORTANT**: In production, API keys should be moved to environment variables or secure storage

### Automatic Data Migration

On first app launch, `DatabaseCleanupService` automatically:
- Deletes old collections (`user_intents`, `intents`, `processed_intents`, `embeddings`)
- Marks cleanup as complete in SharedPreferences
- Never runs again (one-time operation)
- Handles errors gracefully (non-fatal)

### Location Services

- Background location updates every 10 minutes (rate-limited)
- Silent permission requests (only asks on first launch)
- Privacy-protected: shows city name only, not exact GPS
- Auto-refreshes stale location (>24 hours old)

### Performance Optimizations

The app uses several optimization strategies:
- **Firestore offline persistence** with unlimited cache (enabled in `main.dart`)
- **Photo caching** via `PhotoCacheService` and `CachedNetworkImage`
- **Embedding caching** for 24 hours
- **Memory management** via `MemoryManager`
- **Lazy loading** with pagination (20 items per page)
- **Single status stream** to avoid duplicate Firestore queries

## Common Development Patterns

### Creating a Post
```dart
import 'package:supper/services/unified_post_service.dart';

final service = UnifiedPostService();
final result = await service.createPost(
  originalPrompt: "selling iPhone 13",
  price: 800,
  currency: "USD",
);

if (result['success']) {
  final postId = result['postId'];
  // Handle success
}
```

### Finding Matches
```dart
final matches = await UnifiedPostService().findMatches(postId);
// Returns List<PostModel> sorted by similarity score
```

### Understanding Intent with Clarification
```dart
final clarification = await UnifiedIntentProcessor().checkClarificationNeeded(userInput);

if (clarification['needsClarification'] == true) {
  // Show clarification dialog to user
  final answer = await ConversationalClarificationDialog.show(
    context,
    originalInput: userInput,
    question: clarification['question'],
    options: List<String>.from(clarification['options']),
  );
}
```

### Location Updates
```dart
import 'package:supper/services/location_service.dart';

final locationService = LocationService();

// Get current location (silent, no UI)
await locationService.updateUserLocation();

// Check if location needs refresh
await locationService.checkAndRefreshStaleLocation();
```

## Important Constraints & Guidelines

### What NOT to Do
- ❌ Never hardcode categories or intents - rely on AI understanding
- ❌ Never create video calling features (voice-only)
- ❌ Never query without `limit()` in Firestore (performance)
- ❌ Never commit API keys to version control
- ❌ Never use compound WHERE clauses without Firestore indexes
- ❌ Never store data in old collections (`user_intents`, `intents`, etc.)
- ❌ Never show exact GPS coordinates (privacy)

### What TO Do
- ✅ Use `UnifiedPostService` for all post operations
- ✅ Use semantic matching (embeddings + similarity)
- ✅ Handle errors gracefully with user-friendly messages
- ✅ Validate all user input using `PostValidator`
- ✅ Use `StreamBuilder` for real-time updates
- ✅ Cache frequently accessed data
- ✅ Use pagination for large lists
- ✅ Test on both iOS and Android

## Firestore Indexes Required

The app requires composite indexes for certain queries. See `FIRESTORE_INDEXES.md` and `FIRESTORE_INDEX_SETUP.md` for details.

Common indexes:
- `conversations`: `participants` (array) + `lastMessageTime` (desc)
- `posts`: `userId` (asc) + `isActive` (asc) + `createdAt` (desc)
- `messages`: `timestamp` (desc) + `read` (asc)

## Testing & Debugging

### Performance Testing
See `PERFORMANCE_TESTING_GUIDE.md` for scroll performance benchmarks.

### Debug Tools
- `PerformanceDebugScreen` - Monitor app performance
- `DatabaseCleanupService.getCleanupStatus()` - Check migration status
- Firebase Console - Monitor Firestore usage and indexes

### Common Issues

**Posts not matching:**
- Verify post has `embedding` field (auto-generated)
- Check `isActive: true` and `expiresAt` > now
- Ensure complementary intents exist (buyer needs seller)

**Location not updating:**
- Check permissions granted
- Verify location service initialized
- Location updates every 10 minutes (rate-limited)

**Call profile issue:**
- See "Voice Calling (IMPORTANT)" section above for current bug to fix

## Additional Documentation

- `QUICK_START_GUIDE.md` - New data storage system guide
- `DATA_STORAGE_FIX_SUMMARY.md` - Technical migration details
- `CALL_FLOW_DOCUMENTATION.md` - Voice calling specification
- `WEBRTC_SETUP.md` - WebRTC configuration
- `SMART_MATCHING_EXPLAINED.md` - Matching algorithm details
- `LIVE_CONNECT_IMPLEMENTATION_GUIDE.md` - Live Connect feature docs

## Shared UI Components

### chat_common.dart
Located at `lib/widgets/chat_common.dart`, provides reusable chat components:
- `formatDisplayName(String name)`: Converts names to Title Case
- `chatThemeColors`: Predefined gradient themes for message bubbles
- `ChatMessageInput`: Unified message input with emoji picker toggle
- `ChatEmojiPicker`: Consistent emoji picker widget
- `ChatMessageBubble`: Gradient message bubbles with read receipts

## Project Status

Current branch: `main`
Version: 1.0.0+1

### Recent Changes (from git log)
- Cross-user notification system via Firestore
- Connection request/accept notifications to correct users
- Shared chat UI components (chat_common.dart)
- Title Case name formatting across all screens
- Enhanced Live Connect features with filters
- Voice calling implementation (with known profile display bug)

## Live Connect Filter Behavior

The Live Connect screen has quick filters with specific selection rules:
- **Near Me**: Can be toggled independently (works alongside any category filter)
- **Category Filters** (Dating, Friendship, Business, Sports): **Mutually exclusive** - only ONE can be selected at a time. Selecting a new category automatically deselects the previous one.
