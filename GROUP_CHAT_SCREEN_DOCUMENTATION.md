# GROUP CHAT SCREEN - COMPREHENSIVE DOCUMENTATION

**File:** `lib/screens/chat/group_chat_screen.dart`
**Total Lines:** 8,193
**Last Updated:** March 2026
**Widget Type:** `ConsumerStatefulWidget` (Riverpod)
**Mixin:** `WidgetsBindingObserver`

---

## TABLE OF CONTENTS

1. [Overview](#1-overview)
2. [Dependencies & Imports](#2-dependencies--imports)
3. [Widget Parameters](#3-widget-parameters)
4. [State Variables](#4-state-variables)
5. [Lifecycle Methods](#5-lifecycle-methods)
6. [Messaging System](#6-messaging-system)
7. [SingleTap AI Bot Integration](#7-singletap-ai-bot-integration)
8. [Media Handling](#8-media-handling)
9. [Voice Recording & Playback](#9-voice-recording--playback)
10. [Group Audio Calling](#10-group-audio-calling)
11. [Message Actions](#11-message-actions)
12. [Search Functionality](#12-search-functionality)
13. [Mention System (@mentions)](#13-mention-system-mentions)
14. [Chat Themes](#14-chat-themes)
15. [Daily Media Limits](#15-daily-media-limits)
16. [UI Build Methods](#16-ui-build-methods)
17. [Forward Message Screen](#17-forward-message-screen)
18. [Voice Preview Popup](#18-voice-preview-popup)
19. [Firestore Data Structure](#19-firestore-data-structure)
20. [Navigation Flow](#20-navigation-flow)
21. [Business Rules & Constraints](#21-business-rules--constraints)
22. [Performance Optimizations](#22-performance-optimizations)

---

## 1. OVERVIEW

`GroupChatScreen` is a feature-rich group chat interface that supports:
- Real-time text messaging with optimistic UI updates
- Image, video, and voice message support
- @mention system for group members and SingleTap AI bot
- Group audio calling with stale call cleanup
- Message editing, deleting (for me / for everyone), replying, forwarding
- Multi-select mode for bulk operations
- In-chat search with navigation between results
- Customizable chat themes (gradient colors)
- Daily media upload limits (4 per type per 24 hours)
- Date separators (Today, Yesterday, weekday name, or full date)
- Read receipts with WhatsApp-style tick system
- Active call banner with "Join" functionality
- Typing indicators for multiple users

---

## 2. DEPENDENCIES & IMPORTS

| Package | Purpose |
|---------|---------|
| `cloud_firestore` | Real-time message stream & all CRUD operations |
| `firebase_auth` | Current user authentication |
| `firebase_storage` | Media file uploads (images, videos, audio) |
| `cached_network_image` | Cached display of profile photos & media |
| `intl` | Date/time formatting (`DateFormat`) |
| `image_picker` | Camera photo/video and gallery selection |
| `emoji_picker_flutter` | Emoji keyboard overlay |
| `flutter_riverpod` | State management (`ConsumerStatefulWidget`) |
| `flutter_sound` | Voice recording (`FlutterSoundRecorder`) and playback (`FlutterSoundPlayer`) |
| `permission_handler` | Microphone, camera, storage permissions |
| `path_provider` | Temporary directory for voice recordings |
| `dio` | Download media files for saving to device |
| `video_player` | Video duration validation before upload |
| `shared_preferences` | Persist daily media counters across sessions |

### Internal Imports

| Module | Purpose |
|--------|---------|
| `GroupChatService` | Send messages, typing status, mark as read, system messages |
| `NotificationService` | FCM notifications for calls |
| `GeminiService` | AI text generation (fallback when no products found) |
| `ProductApiService` | Product search for AI bot responses |
| `FloatingCallService` | Check if call is in floating overlay |
| `AppColors` | Theme colors and gradients |
| `GlassTextField` | Glassmorphism-styled text input |
| `PhotoUrlHelper` | Validate photo URLs |
| `SnackBarHelper` | Consistent error/success/info snackbars |

---

## 3. WIDGET PARAMETERS

```dart
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;    // Firestore conversation document ID
  final String groupName;  // Initial group name (may update from stream)
}
```

---

## 4. STATE VARIABLES

### Core Messaging
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_messageController` | `TextEditingController` | - | Text input controller |
| `_scrollController` | `ScrollController` | - | ListView scroll control |
| `_isSending` | `bool` | `false` | Lock to prevent double-send |
| `_optimisticMessages` | `List<Map>` | `[]` | Messages shown before server confirms |
| `_messagesPerPage` | `int` (static const) | `20` | Pagination page size |
| `_hasMoreMessages` | `bool` | `true` | Whether older messages exist |
| `_isLoadingMore` | `bool` | `false` | Loading indicator for pagination |
| `_lastDocument` | `DocumentSnapshot?` | `null` | Cursor for pagination |

### Group Info (populated from Firestore stream)
| Variable | Type | Description |
|----------|------|-------------|
| `_currentGroupName` | `String` | Live group name from Firestore |
| `_groupPhoto` | `String?` | Group avatar URL |
| `_memberNames` | `Map<String, String>` | `userId → displayName` mapping |
| `_memberPhotos` | `Map<String, String?>` | `userId → photoUrl` mapping |
| `_typingUsers` | `List<String>` | User IDs currently typing |

### Media Counters (persisted in SharedPreferences)
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_todayImageCount` | `int` | `0` | Images sent in last 24h |
| `_todayVideoCount` | `int` | `0` | Videos sent in last 24h |
| `_todayAudioCount` | `int` | `0` | Voice messages sent in last 24h |
| `_lastMediaCountReset` | `DateTime?` | `null` | Last counter reset timestamp |
| `_isMediaOperationInProgress` | `bool` | `false` | Lock for concurrent uploads |
| `_isCounterLoaded` | `bool` | `false` | Whether counters loaded from storage |
| `_isCounterLoading` | `bool` | `false` | Prevent concurrent counter loads |

### UI State
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_showEmojiPicker` | `bool` | `false` | Emoji keyboard visibility |
| `_showScrollButton` | `bool` | `false` | Scroll-to-bottom FAB (appears at 500px from bottom) |
| `_isSearching` | `bool` | `false` | Search mode active |
| `_searchQuery` | `String` | `''` | Current search text |
| `_searchResults` | `List<Map>` | `[]` | Matching messages |
| `_currentSearchIndex` | `int` | `0` | Current result position |
| `_isMultiSelectMode` | `bool` | `false` | Multi-select mode |
| `_selectedMessageIds` | `Set<String>` | `{}` | Selected message IDs |
| `_replyToMessage` | `Map?` | `null` | Message being replied to |
| `_editingMessage` | `Map?` | `null` | Message being edited |
| `_currentTheme` | `String` | `'default'` | Active chat theme key |
| `_isStartingCall` | `bool` | `false` | Prevent double call initiation |

### Voice Recording
| Variable | Type | Description |
|----------|------|-------------|
| `_audioRecorder` | `FlutterSoundRecorder?` | Lazy-initialized recorder |
| `_isRecording` | `bool` | Currently recording |
| `_isRecorderInitialized` | `bool` | Recorder opened |
| `_recordingPath` | `String?` | Temp file path for recording |
| `_recordingTimer` | `Timer?` | Duration counter timer |
| `_recordingDuration` | `int` | Seconds recorded |

### Voice Playback
| Variable | Type | Description |
|----------|------|-------------|
| `_audioPlayer` | `FlutterSoundPlayer?` | Lazy-initialized player |
| `_isPlayerInitialized` | `bool` | Player opened |
| `_currentlyPlayingMessageId` | `String?` | Which message is playing |
| `_isPlaying` | `bool` | Playback active |
| `_playbackProgress` | `double` | 0.0 to 1.0 progress |
| `_playerSubscription` | `StreamSubscription?` | Progress listener |

### Mention System
| Variable | Type | Description |
|----------|------|-------------|
| `_showMentionSuggestions` | `bool` | Show dropdown |
| `_filteredMembers` | `List<Map>` | Matching members for query |
| `_mentionStartIndex` | `int` | Position of `@` in text |

### Cached Streams
| Variable | Type | Description |
|----------|------|-------------|
| `_messagesStream` | `Stream<QuerySnapshot>` | Cached to prevent re-subscription on setState |
| `_activeCallStream` | `Stream<QuerySnapshot>` | Cached via StreamController; auto-cancels on permission error |
| `_activeCallStreamError` | `bool` | If true, stops rendering call banner |

---

## 5. LIFECYCLE METHODS

### `initState()`
1. Adds `WidgetsBindingObserver`
2. Calls `markAsRead()` on the group
3. Adds scroll listeners (`_onScroll` for pagination, `_scrollListener` for scroll button)
4. Loads chat theme from Firestore
5. Caches messages stream: `conversations/{groupId}/messages` ordered by `timestamp desc`, limit 20
6. Caches active call stream: `group_calls` where `groupId` matches; wraps in `StreamController` to catch permission errors
7. Initializes daily media counters with progressive retry (immediate → post-frame → 300ms → 1s)

### `dispose()`
1. Removes observer
2. Disposes all controllers (message, scroll, search, focus nodes)
3. Clears typing status
4. Cancels active call stream subscription and controller
5. Cancels recording timer, player subscription
6. Closes audio recorder and player

### `didChangeAppLifecycleState()`
- On `paused` or `inactive`: clears typing status (without UI rebuild)

---

## 6. MESSAGING SYSTEM

### Send Message Flow (`_sendMessage()`)
1. If `_editingMessage` is set, delegates to `_saveEditedMessage()` instead
2. Validates text is non-empty and `_isSending` is false
3. **Immediately locks** `_isSending = true` to prevent double-send race condition
4. Clears text input and reply state
5. Creates **optimistic message** with `isOptimistic: true` flag
6. Scrolls to bottom
7. Clears typing status
8. Extracts @mentions from text
9. Calls `GroupChatService.sendMessage()` with optional `replyToMessageId` and `mentions`
10. On success: removes optimistic message (real one arrives via stream)
11. If text contains `@SingleTap` → triggers AI handler asynchronously
12. On failure: removes optimistic message, shows error snackbar
13. Finally: resets `_isSending`

### Message Stream Processing (in `build()`)
1. Listens to cached `_messagesStream`
2. Deduplicates by message ID using `Set`
3. Tracks `_lastDocument` for pagination
4. Combines optimistic messages (newest) with Firestore messages
5. **Filters applied:**
   - `deletedFor` array - hides messages where current user is in array
   - Filters out 1-on-1 call messages from group (by checking `callId` and `actionType`)
   - Search filter when `_isSearching && _searchQuery.isNotEmpty`
6. Stores all messages in `_allMessages` for search
7. Auto-scrolls to bottom only if user is within 200px of bottom

### Pagination (`_loadMoreMessages()`)
- Triggers when scroll reaches 100px from maxScrollExtent
- Uses `startAfterDocument(_lastDocument)` with limit 20
- Sets `_hasMoreMessages = false` when no more docs returned

---

## 7. SINGLETAP AI BOT INTEGRATION

**Constants:**
- `_kAiSenderId = 'SINGLETAP_AI'`
- `_kAiName = 'SingleTap'`

### How It Works (`_handleSingleTapAiMention()`)
1. Triggered when message text contains `@SingleTap` (case-insensitive)
2. **Duplicate prevention:** `_isAiProcessing` flag (guaranteed reset in `finally`)
3. Extracts query text after `@SingleTap` mention
4. **Cache check:** LRU cache of 50 entries (`_aiResponseCache`)
5. **Rate limit:** 2-second minimum between AI calls
6. **Product search first:** Uses `ProductApiService().searchWithResponse(query)`
7. **Gemini fallback:** If no products found, uses `GeminiService.generateContent()` with SingleTap AI persona prompt
8. Single retry after 2s if Gemini returns null
9. Writes AI response to group via `_writeAiMessageToGroup()`

### AI Message Structure (Firestore)
```javascript
{
  senderId: 'SINGLETAP_AI',
  senderName: 'SingleTap AI',
  text: 'AI response text',
  isAiMessage: true,
  isSystemMessage: false,
  products: [{name, brand, price, image, category, rating, listing_id, user_id}],
  readBy: [],
  status: 1,
  timestamp: serverTimestamp
}
```

### AI Message UI
- Purple gradient bubble (`#6366F1` to `#8B5CF6` at 15%/10% opacity)
- "SingleTap AI" label in cyan (`#00E5FF`)
- App logo avatar (14px radius)
- Markdown rendering: **bold**, *italic*, `code`, bullet points, numbered lists, headings
- Product cards: horizontal scrollable list (140px wide, 190px tall) with image, name, brand, price
- Tapping product card navigates to `ProductDetailScreen`

---

## 8. MEDIA HANDLING

### Image Sending
1. **Pick from gallery** (`_pickImage()`):
   - Uses `pickMultiImage()` - max 4 images per selection
   - Quality: 85%, max 1920x1920
   - Checks daily limit before incrementing counter
   - Creates optimistic message with local file path
   - Background upload to `chat_media/{userId}/{timestamp}.jpg`

2. **Take photo** (`_takePhoto()`):
   - Uses `pickImage(source: ImageSource.camera)`
   - Same quality and limit checks
   - Same optimistic + background upload flow

### Video Sending
1. **Record video** (`_recordVideo()`):
   - Requests camera + microphone permissions
   - Max duration: 28 seconds
   - Max file size: 25MB
   - Validates duration using `VideoPlayerController`
   - Daily limit check

2. **Pick from gallery** (`_pickVideo()`):
   - Single video at a time
   - Same 28s / 25MB limits
   - Duration validated with `VideoPlayerController`

### Upload Flow (Images & Videos)
1. Create optimistic message with `isLocalFile: true` and local path
2. Show immediately with local file preview
3. Upload to Firebase Storage in background
4. On success: add Firestore message, update conversation metadata, remove optimistic
5. On failure: remove optimistic, show error

### Conversation Metadata Updates
- Images: `lastMessage: '📷 Photo'`
- Videos: `lastMessage: '🎥 Video'`

### Save Media to Device
All save methods (`_saveImage`, `_saveVideo`, `_saveAudio`, `_saveFile`):
- Request storage/photos permission
- Download via `Dio` with `ResponseType.bytes`
- Save to `/storage/emulated/0/Pictures/Plink/` (Android)
- Trigger media scanner for gallery visibility
- File naming: `plink_{timestamp}.{ext}`

---

## 9. VOICE RECORDING & PLAYBACK

### Recording Flow
1. `_startRecording()`:
   - Request microphone permission
   - Lazy-initialize `FlutterSoundRecorder`
   - Record to temp directory as `.aac` (Codec.aacADTS)
   - Bitrate: 64kbps, Sample rate: 22kHz
   - Timer counts seconds
   - Haptic feedback on start

2. `_showVoiceRecordingPopup()`:
   - Stops recording
   - Shows `_VoicePreviewPopup` dialog with play/delete/send options

3. `_sendVoiceMessage()`:
   - Checks daily audio limit
   - Creates optimistic message
   - Uploads to `chat_media/{userId}/voice_{groupId}_{timestamp}.aac`
   - Sends via `GroupChatService.sendMessage()` with `voiceUrl` and `voiceDuration`
   - Deletes local file after upload

### Playback (`_playAudio()`)
- Lazy-initializes `FlutterSoundPlayer`
- Toggle play/pause for same message
- Stop + play new for different message
- Subscription interval: 50ms for smooth waveform
- Progress tracked as 0.0–1.0

### Audio Player UI (`_buildAudioMessagePlayer`)
- Glass background with gradient
- 32px circular play/pause button (iOS blue)
- 25-bar waveform visualization (animated based on progress)
- Duration display (MM:SS format)
- Uploading state: orange spinner overlay

---

## 10. GROUP AUDIO CALLING

### Start Call (`_startGroupAudioCall()`)
1. `_isStartingCall` lock prevents multiple simultaneous calls
2. **Stale call cleanup:** Checks all active calls for current user
   - Calls older than 2 minutes with inactive participant → auto-end
   - Checks `participants/{userId}/isActive` sub-document
3. Gets group members, deduplicates by userId
4. Creates `group_calls` document:
   ```javascript
   {
     groupId, groupName, callerId, callerName,
     participants: [userId...],
     isVideo: false, status: 'calling',
     createdAt: serverTimestamp
   }
   ```
5. Batch-writes participant sub-documents (caller `isActive: true`, others `isActive: false`)
6. Creates optimistic call system message
7. Sends real system message via `GroupChatService.sendSystemMessage()`
8. Stores `systemMessageId` in call document
9. Sends FCM notifications to all other members
10. Navigates to `GroupAudioCallScreen`

### Active Call Banner (`_buildActiveCallBanner()`)
- Streams `group_calls` where `groupId` matches
- Sorts client-side by `createdAt`, finds first with `status == 'active'`
- Hides if call is in floating overlay (`FloatingCallService`)
- **Safety net:** Auto-ends calls older than 45 seconds with no active participants
- Shows participant avatars (max 2), member count, "Join" button
- Green banner (#00A884)

### Join Call (`_joinActiveCall()`)
- Adds user to `participants` array if not present
- Navigates to `GroupAudioCallScreen`

### Call Card Tap (`_handleCallCardTap()`)
- If `callDuration > 0` → call ended, show message
- Checks `status == 'active'` in Firestore
- Navigates to `GroupAudioCallScreen`

---

## 11. MESSAGE ACTIONS

### Long Press Options (`_showMessageOptions()`)
Dark popup dialog (RGB 32,32,32) with white border:
- **Reply** - Sets `_replyToMessage`, focuses input
- **Forward** - Opens `_ForwardMessageScreen`
- **Copy** - Copies text to clipboard (only if text non-empty)
- **Save Image/Video/Audio/Document** - Downloads to device (shown conditionally)
- **Edit** - Only for own text messages, sets `_editingMessage`
- **Select** - Enters multi-select mode
- **Delete** - Shows delete dialog (red, destructive)

### Edit Message (`_editMessage()` / `_saveEditedMessage()`)
- Populates text field with original text
- Clears reply mode (mutually exclusive)
- Updates Firestore: `text`, `isEdited: true`, `editedAt: serverTimestamp`

### Delete Message
**Delete for me** (`_deleteMessageForMe()`):
- Adds current user to `deletedFor` array using `FieldValue.arrayUnion`

**Delete for everyone** (`_deleteMessageForEveryone()`):
- Deletes media from Firebase Storage (image, audio, voice URLs)
- If call message: deletes `group_calls` document (by `callId` or `systemMessageId`)
- Updates message: `isDeleted: true`, `text: 'This message was deleted'`, nullifies all media fields

**Delete Dialog** (`_showDeleteDialog()`):
- Glassmorphism dialog with BackdropFilter blur
- "Delete for everyone" (red button, only for own messages)
- "Delete for me" (red button)
- "Cancel" (glass button)

### Call Message Delete (`_showCallDeleteOptions()` / `_deleteCallForMe()`)
- Select or Delete options only
- Delete for me: adds to `deletedFor` in both message AND `group_calls` document
- Falls back to `systemMessageId` lookup if `callId` missing

### Multi-Select Mode
- Enter via `_enterMultiSelectMode()` (from long press → Select)
- Toggle individual messages
- Auto-exits when last message deselected
- AppBar shows selection count + Forward/Delete actions
- **Forward selected**: sends each message to each recipient
- **Delete selected**: checks ownership, shows dialog

### Swipe to Reply
- Implemented via `Dismissible` with `DismissDirection.startToEnd`
- `confirmDismiss` always returns false (doesn't actually dismiss)
- Sets `_replyToMessage` and focuses input

---

## 12. SEARCH FUNCTIONALITY

### Toggle (`_toggleSearch()`)
- Switches `_isSearching` flag
- Focuses search field on enter
- Clears results on exit

### Search (`_performSearch()`)
- Filters `_allMessages` by case-insensitive text containment
- Navigates to first result

### Navigation
- `_previousSearchResult()` / `_nextSearchResult()` - wraps around
- Scrolls to target using estimated position (`index * 100.0`)

### Highlighting
- `_buildHighlightedText()` highlights matches with yellow background + bold
- Works alongside mention highlighting

---

## 13. MENTION SYSTEM (@MENTIONS)

### Detection (`_handleMentionDetection()`)
- Triggered on every text change
- Finds last `@` before cursor that starts at beginning or after space/newline
- Extracts query after `@`
- Filters `_memberNames` (excluding current user)
- Always includes **SingleTap AI** option if query matches

### Insertion (`_insertMention()`)
- Replaces text from `@` to cursor with `@UserName `
- Repositions cursor after mention
- Keeps focus on text field

### Extraction (`_extractMentions()`)
- Regex `@\w+` finds all mentions
- Looks up user ID by name in `_memberNames`
- Returns list of `{userId, name}` maps

### Display (`_buildTextWithMentions()`)
- Renders mentions in cyan (`#00E5FF` for sent, `#00B8D4` for received light mode)
- Bold weight (w600)
- Falls back to search highlighting if no mentions

### Mention Suggestions UI (`_buildMentionSuggestions()`)
- Black dropdown (90% opacity) with rounded corners
- Max height 200px, scrollable
- SingleTap AI entry at top with app logo and cyan text
- Members with avatar, name
- Dividers between items

---

## 14. CHAT THEMES

### Storage
- Theme key stored in `conversations/{groupId}/chatTheme`
- Uses `AppColors.chatThemeGradients` map

### Theme Picker (`_showThemePicker()`)
- Dark dialog (RGB 32,32,32) with white border
- "None (Default)" button with check icon
- Gradient circle buttons (50x50) for each theme
- Selected theme shows white border + glow shadow + check icon

### Application
- Message area background: theme gradient at 30%/20% opacity
- Default theme: transparent (shows background image)
- Sent message bubbles: NOT affected by theme (use glass gradient)

---

## 15. DAILY MEDIA LIMITS

### Rules
- **4 images per 24 hours** (per group per user)
- **4 videos per 24 hours** (per group per user)
- **4 voice messages per 24 hours** (per group per user)
- Counters reset after 24 hours from last reset

### Storage Key Format
`{groupId}_{userId}_{imageCount|videoCount|audioCount|lastReset}`

### Check Flow (`_wouldExceedLimit()`)
1. Load counter if not loaded
2. Block if counter can't be verified (userId null)
3. Reset if 24h passed
4. Return `currentCount + requestCount > 4`

### Error Message (Hindi/Urdu)
`"Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye."`

### Counter Initialization Retry
Progressive retry strategy handles Firebase Auth initialization delay:
- Attempt 1: Immediate
- Attempt 2: After first frame
- Attempt 3: After 300ms
- Attempt 4: After 1 second

---

## 16. UI BUILD METHODS

### Main Build (`build()`)
Structure:
```
Scaffold
├── AppBar (gradient, transparent)
├── Stack
│   ├── Gradient Background (AppColors.splashGradient)
│   ├── SafeArea (bottom: false)
│   │   ├── SearchResultsBar (conditional)
│   │   ├── ActiveCallBanner (conditional)
│   │   ├── Messages ListView (reverse: true)
│   │   ├── ReplyPreview (conditional)
│   │   ├── EditPreview (conditional)
│   │   ├── MessageInput
│   │   └── EmojiPicker (conditional)
│   └── ScrollToBottomButton (conditional)
```

### AppBar (`_buildAppBar()`)
- Transparent with gradient overlay (40% → 20% → 0% black)
- White 1px bottom border
- **Normal mode:** Group avatar, name, typing indicator, member count → tap opens GroupInfoScreen
- **Search mode:** GlassTextField search input
- **Multi-select mode:** Selection count, forward button, delete button
- Actions: Call button (disabled when starting), More/Close button

### Message Bubble (`_buildMessageBubble()`)
- **Text messages:** Glass gradient background, white border, sender name + separator line (received only)
- **Images:** Rounded corners, sender name overlay (black 60% opacity), CachedNetworkImage, upload spinner for optimistic
- **Videos:** Black container with play icon, sender name overlay, upload overlay for optimistic
- **Voice:** Custom waveform player (see section 9)
- **Deleted messages:** Grey italic text "This message was deleted"
- Supports reply preview bubble

### System Messages (`_buildSystemMessage()`)
- **Call messages:** Positioned right (caller) or left (others), call icon with status (outgoing/missed/incoming), duration, participant count, "Join" button for active calls
- **Regular:** Centered glass pill with italic white text

### Date Separators (`_buildDateSeparator()`)
- "Today", "Yesterday", weekday name (within 7 days), "MMM D, YYYY" (older)
- Glass pill style with gradient + white border

### Message Status Icons (`_buildMessageStatusIcon()`)
- Single grey tick ✓ = Sent (readCount = 1, only sender)
- Double grey tick ✓✓ = Read by some (readCount > 1 but < totalMembers)
- Double blue tick ✓✓ = Read by all (readCount >= totalMembers)

### Message Input (`_buildMessageInput()`)
- Mention suggestions dropdown (conditional)
- White 0.5px separator line
- Gradient background (40% → 50% black)
- **Left:** Attachment button (add_circle icon, 44px)
- **Center:** Glass text field with emoji toggle
- **Right:** AnimatedSwitcher between:
  - **Send button** (arrow up icon, glass circle, 42px) when text present
  - **Mic button** (mic icon, 42px; expands to 90px red pill when recording with timer + stop icon)

### Emoji Picker (`_buildEmojiPicker()`)
- Height: 35% of screen (clamped 200–350)
- Category tabs with iOS blue indicator
- Recent emojis limit: 28

---

## 17. FORWARD MESSAGE SCREEN

**Class:** `_ForwardMessageScreen` (private StatefulWidget)

### Features
- Loads contacts from user's conversations (limit 50, sorted by lastMessageTime)
- Search bar filters by name
- Multi-select with chips (green, horizontal scroll)
- Contact list with avatar, name, email, check circle

### Forward Logic (`_sendForwardedMessage()`)
1. Find or create 1-on-1 conversation with recipient
2. Send message with `isForwarded: true` flag
3. Supports text, image, audio forwarding
4. Updates conversation metadata + unread count

---

## 18. VOICE PREVIEW POPUP

**Class:** `_VoicePreviewPopup` (private StatefulWidget)

### Features
- Dark popup (RGB 32,32,32) with white border
- Audio player with play/pause toggle
- 20-bar waveform visualization with progress
- Duration display (MM:SS)
- **Delete button:** Red, cancels and deletes local file
- **Send button:** Glass gradient, sends voice message

---

## 19. FIRESTORE DATA STRUCTURE

### Messages Collection
`conversations/{groupId}/messages/{messageId}`

```javascript
// Text message
{
  senderId: string,
  text: string,
  timestamp: serverTimestamp,
  isSystemMessage: false,
  readBy: [userId...],
  status: number,
  replyToMessageId: string?,    // Reply reference
  mentions: [{userId, name}],   // @mention data
  isEdited: bool?,
  editedAt: timestamp?,
  isDeleted: bool?,
  deletedAt: timestamp?,
  deletedFor: [userId...],      // Per-user soft delete
  isForwarded: bool?
}

// Image message
{
  senderId: string,
  text: '',
  imageUrl: string,             // Firebase Storage URL
  timestamp: serverTimestamp,
  readBy: [userId...]
}

// Video message
{
  senderId: string,
  text: '',
  videoUrl: string,
  timestamp: serverTimestamp,
  readBy: [userId...]
}

// Voice message
{
  senderId: string,
  text: '',
  voiceUrl: string,
  voiceDuration: int,           // seconds
  timestamp: serverTimestamp,
  readBy: [userId...]
}

// AI message
{
  senderId: 'SINGLETAP_AI',
  senderName: 'SingleTap AI',
  text: string,
  isAiMessage: true,
  products: [{name, brand, price, image, category, rating, listing_id, user_id}],
  timestamp: serverTimestamp,
  readBy: [],
  status: 1
}

// Call system message
{
  senderId: 'system',
  text: 'Voice call',
  isSystemMessage: true,
  actionType: 'call',
  callId: string,
  callerId: string,
  callerName: string,
  callDuration: int,            // 0 = missed/ongoing
  participantCount: int,
  timestamp: serverTimestamp
}
```

### Conversation Document
`conversations/{groupId}`

```javascript
{
  groupName: string,
  groupPhoto: string?,
  participants: [userId...],
  participantNames: {userId: name},
  participantPhotos: {userId: photoUrl},
  isTyping: {userId: bool},
  lastMessage: string,
  lastMessageTime: timestamp,
  lastMessageSenderId: string,
  chatTheme: string?            // Theme key
}
```

### Group Calls Document
`group_calls/{callId}`

```javascript
{
  groupId: string,
  groupName: string,
  callerId: string,
  callerName: string,
  participants: [userId...],
  isVideo: false,
  status: 'calling' | 'ringing' | 'active' | 'connected' | 'ended',
  createdAt: serverTimestamp,
  endedAt: serverTimestamp?,
  systemMessageId: string?,
  deletedFor: [userId...]
}

// Sub-collection: group_calls/{callId}/participants/{userId}
{
  userId: string,
  name: string,
  photoUrl: string?,
  isActive: bool,
  joinedAt: timestamp?,
  createdAt: serverTimestamp
}
```

---

## 20. NAVIGATION FLOW

```
GroupChatScreen
├── → GroupInfoScreen (tap group name / more button)
│   ├── Returns 'search' → toggles search mode
│   └── Returns 'theme' → shows theme picker
├── → GroupAudioCallScreen (start call / join call)
├── → _ForwardMessageScreen (forward message)
├── → PhotoViewerDialog (tap image)
├── → VideoPlayerScreen (tap video)
├── → ProductDetailScreen (tap AI product card)
└── → Image.file fullscreen (tap local/optimistic image)
```

---

## 21. BUSINESS RULES & CONSTRAINTS

| Rule | Value |
|------|-------|
| Messages per page | 20 |
| Max images per selection | 4 |
| Max images per 24h | 4 |
| Max videos per 24h | 4 |
| Max audio per 24h | 4 |
| Max video duration | 28 seconds |
| Max video file size | 25 MB |
| Voice recording codec | AAC ADTS |
| Voice recording bitrate | 64 kbps |
| Voice recording sample rate | 22,050 Hz |
| AI response cache size | 50 entries |
| AI rate limit | 2 seconds between calls |
| Stale call threshold | 2 minutes (for call initiation cleanup) |
| Auto-end call threshold | 45 seconds with no active participants |
| Scroll button threshold | 500px from bottom |
| Auto-scroll threshold | 200px from bottom |
| Media save directory | `/Pictures/Plink/` (Android) |
| Typing status | Cleared on dispose and app pause |
| Optimistic messages | Shown at 70% opacity |

---

## 22. PERFORMANCE OPTIMIZATIONS

1. **Cached streams:** `_messagesStream` and `_activeCallStream` created once in `initState()`, preventing re-subscription on `setState()`
2. **Active call stream error handling:** Cancels subscription on first error to prevent permission-denied retry spam
3. **Message deduplication:** Uses `Set<String>` to filter duplicate doc IDs
4. **Optimistic messages:** Immediate UI feedback before server round-trip
5. **Background uploads:** Image/video/voice uploads don't block UI thread
6. **Lazy audio initialization:** `FlutterSoundRecorder` and `FlutterSoundPlayer` only initialized on first use
7. **Counter loading lock:** Prevents concurrent SharedPreferences reads
8. **Media operation lock:** `_isMediaOperationInProgress` prevents concurrent uploads
9. **Call initiation lock:** `_isStartingCall` prevents duplicate call creation
10. **AI response cache:** 50-entry LRU cache for repeated queries
11. **Conditional auto-scroll:** Only scrolls to bottom if user is already near bottom (within 200px)
12. **Client-side filtering:** Active call sorting and filtering done client-side (no composite index needed)
13. **Progressive counter retry:** Handles Firebase Auth initialization delay gracefully
14. **Subscription duration:** 50ms for smooth waveform animation during audio playback
15. **Image quality reduction:** 85% quality, max 1920px for smaller upload sizes

---

## APPENDIX: KEY CONSTANTS

```dart
const String _kAiSenderId = 'SINGLETAP_AI';
const String _kAiName = 'SingleTap';
static const int _messagesPerPage = 20;
static const Map<String, List<Color>> chatThemes = AppColors.chatThemeGradients;
```

## APPENDIX: ATTACHMENT OPTIONS

The attachment popup (dark dialog) offers:
1. **Take Photo** (camera_alt icon) → `_takePhoto()`
2. **Record Video** (videocam icon) → `_recordVideo()`
3. **Photo from Gallery** (image icon) → `_pickImage()`
4. **Video from Gallery** (video_library icon) → `_pickVideo()`
