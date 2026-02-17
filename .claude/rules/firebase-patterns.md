---
paths:
  - "lib/services/**"
  - "lib/providers/**"
---

# Firebase & Service Patterns

## FirebaseProvider (ALWAYS use this)
```dart
import 'package:supper/services/firebase_provider.dart';
final firestore = FirebaseProvider.firestore;
final auth = FirebaseProvider.auth;
final currentUserId = FirebaseProvider.currentUserId;
final userDoc = FirebaseProvider.getUserDoc(userId);
final posts = FirebaseProvider.postsCollection;
```
NEVER create new Firestore/Auth instances. Always use FirebaseProvider singleton.

## Post Operations (ALWAYS use UnifiedPostService)
```dart
final service = UnifiedPostService();
final result = await service.createPost(originalPrompt: userInput, price: price, currency: 'USD');
final matches = await service.findMatches(postId);
```

## Firestore Query Rules
- ALWAYS add `.limit()` to every query
- NEVER use compound WHERE without indexes
- Use pagination (20 items per page)
- Use StreamBuilder for real-time data

## Database Collections
- posts/ — Single source of truth (userId, originalPrompt, title, description, intentAnalysis, embedding[768], keywords, location, price, isActive, createdAt, expiresAt)
- users/ — Profiles (uid, name, email, photoUrl, bio, location, interests, isOnline)
- conversations/ — Chats with messages subcollection
- notifications/ — Cross-user notifications (userId, senderId, title, body, type, read)
- connection_requests/ — Connection requests (senderId, receiverId, status, message)
- NEVER use old collections: user_intents, intents, processed_intents, embeddings
