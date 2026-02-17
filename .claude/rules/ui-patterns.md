---
paths:
  - "lib/screens/**"
  - "lib/widgets/**"
---

# UI & Widget Patterns

## Screen Navigation (Bottom Tabs)
1. Home (UniversalMatchingScreen) — Create posts, find matches
2. Messages (ConversationsScreen) — Chat conversations
3. Networking (NetworkingScreen) — Browse nearby people
4. Profile (ProfileWithHistoryScreen) — User profile, post history

## Chat Components (lib/widgets/chat_common.dart)
- formatDisplayName(String name) — Title Case conversion
- chatThemeColors — Gradient themes for message bubbles
- ChatMessageInput — Input with emoji picker
- ChatEmojiPicker — Emoji picker widget
- ChatMessageBubble — Gradient bubbles with read receipts

## Live Connect Filters
- Near Me: toggles independently
- Category filters ( Friendship, Business, Sports): mutually exclusive — only ONE at a time

## Intent Clarification Dialog
```dart
final clarification = await UnifiedIntentProcessor().checkClarificationNeeded(userInput);
if (clarification['needsClarification'] == true) {
  final answer = await ConversationalClarificationDialog.show(context,
    originalInput: userInput,
    question: clarification['question'],
    options: List<String>.from(clarification['options']),
  );
}
```

## Performance
- Use CachedNetworkImage for photos
- Lazy load with pagination (20 items)
- Use MemoryManager for memory management
- Firestore offline persistence enabled in main.dart
