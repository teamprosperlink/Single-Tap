# Messages Module — Complete Screen Documentation

**App:** Supper
**Module:** Messages / Chat
**Total Screens:** 13 (11 standalone screens/dialogs + 2 business screens)
**Last Updated:** 16 Mar 2026

---

## Table of Contents

1. [Conversations Screen (Main Container)](#1-conversations-screen-main-container)
2. [Enhanced Chat Screen (1-on-1 Chat)](#2-enhanced-chat-screen-1-on-1-chat)
3. [Group Chat Screen](#3-group-chat-screen)
4. [Create Group Screen](#4-create-group-screen)
5. [Group Info Screen](#5-group-info-screen)
6. [Media Gallery Screen (1-on-1)](#6-media-gallery-screen-1-on-1)
7. [Group Media Gallery Screen](#7-group-media-gallery-screen)
8. [Audio Player Dialog](#8-audio-player-dialog)
9. [Link Preview Dialog](#9-link-preview-dialog)
10. [Photo Viewer Dialog](#10-photo-viewer-dialog)
11. [Video Player Screen](#11-video-player-screen)
12. [Business Conversations Screen](#12-business-conversations-screen)
13. [Business Messages Tab](#13-business-messages-tab)

**Services:**
- [A. ActiveChatService](#a-activechatservice)
- [B. AiChatService](#b-aichatservice)
- [C. HybridChatService](#c-hybridchatservice)
- [D. GroupChatService](#d-groupchatservice)
- [E. ConversationService](#e-conversationservice)
- [F. chat_common.dart (Shared Widgets)](#f-chat_commondart-shared-widgets)

---

## 1. Conversations Screen (Main Container)

**File:** `lib/screens/chat/conversations_screen.dart`
**Class:** `ConversationsScreen` (StatefulWidget with `TickerProviderStateMixin`, `VoiceSearchMixin`)
**Purpose:** The Messages tab of the main navigation (bottom tab index 1). Provides a unified interface for managing all user communications: one-on-one chats, group chats, and voice call history through a three-tab layout.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `onBack` | `VoidCallback?` | No | `null` | Optional back callback (currently unused) |

### Entry Point

| Entry Point | Location | Navigation Target |
|-------------|----------|-------------------|
| **Bottom Navigation Tab** | 2nd tab (index 1) | ConversationsScreen (this screen) |

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│                   "Messages"            [person_add]│
│                  (centered)                        │
│                                                    │
│    [ Chats ]       [ Groups ]       [ Calls ]      │
└────────────────────────────────────────────────────┘
```

| Element | Position | Behavior |
|---------|----------|----------|
| **Leading** | Left | `SizedBox.shrink()` (hidden, no back button), `leadingWidth: 0` |
| **Title** | Center | "Messages" (Poppins, 20px, bold, white) |
| **Person Add Icon** | Right action | Circular button: `Icons.person_add`, white, 22px. On Chats/Calls tab → opens `_NewMessageScreen`. On Groups tab → opens `CreateGroupScreen` |

### AppBar Styling

- **Background gradient:** `#282828` → `#404040` (top to bottom)
- **Bottom border:** White 0.5px
- **Toolbar height:** 56px
- **Transparent elevation, no shadow**
- **Action button container:** circle, `Colors.white` at 15% alpha, border `Colors.white` at 30% alpha, 1px

### Tab Bar (3 Tabs)

| Tab Index | Tab Name | Content | Description |
|-----------|----------|---------|-------------|
| 0 | **Chats** | `_buildChatsList(isGroup: false)` | All 1-on-1 conversations |
| 1 | **Groups** | `_buildChatsList(isGroup: true)` | All group conversations |
| 2 | **Calls** | `_buildCallsList()` | Voice call history (individual + group) |

### Tab Bar Styling

- **Indicator:** White, full-tab width, 2px weight
- **Selected label:** White, Poppins 15px, weight 600
- **Unselected label:** White 60% opacity, Poppins 15px, normal weight
- **Divider:** Transparent

### Selection Mode Header

When user long-presses a conversation/call, multi-select mode activates:

```
┌────────────────────────────────────────────────────┐
│ [X]  "N selected"              [Select All] [🗑️]   │
└────────────────────────────────────────────────────┘
```

- **Background:** `Colors.grey.shade900`
- **Padding:** horizontal 16, vertical 8
- **Select All:** Text button
- **Delete:** Red delete icon, shows confirmation dialog

### Search Bar

- **Widget:** `GlassSearchField`
- **Margin:** `EdgeInsets.fromLTRB(20, 8, 20, 12)`
- **Hint text:** "Search conversations..."
- **Border radius:** 16
- **Features:** Microphone button (`showMic: true`), voice search
- **Voice search locale:** `en_IN`, listens up to 30 seconds
- **Filtering:** Client-side substring match on display name (lowercased)

### Conversation Tile Layout

```
┌─────────────────────────────────────────────────────┐
│ margin: 12h, 3v  |  borderRadius: 16               │
│ gradient: white@25% → white@15%                     │
│ border: white@30%, 1px                              │
│                                                     │
│ [☐?] [Avatar 44px]  Name    [Source Tag]            │
│                      2m ago                         │
│                 [🎤?] Last msg...      [N unread]   │
└─────────────────────────────────────────────────────┘
```

| Field | Styling | Details |
|-------|---------|---------|
| **Avatar** | CircleAvatar radius 22 (44px) | `CachedNetworkImage` or colored fallback circle with initial letter |
| **Name** | Poppins, 13.5px, w600, white | `formatDisplayName()` Title Case, ellipsis |
| **Source Tag** | Pill badge, 11px | See Source Tag Colors table |
| **Time** | Poppins, 10px, white 50% | `timeago.format(...)` |
| **Last Message** | Poppins, 11.5px, white 60% | "Typing..." if typing, else message preview |
| **Unread Badge** | Green `#25D366`, rounded 12 | Poppins, 11px, bold, white. Caps at "99+" |
| **Voice indicator** | `Icons.mic`, 13px, white | Shown if lastMessage contains "Voice message" |

### Avatar Fallback Colors (15 colors, hash-based)

`#6366F1`, `#8B5CF6`, `#EC4899`, `#EF4444`, `#F97316`, `#22C55E`, `#14B8A6`, `#06B6D4`, `#3B82F6`, `#A855F7`, `#F43F5E`, `#10B981`, `#0EA5E9`, `#6D28D9`, `#D946EF`

### Source Tag Colors

| Source | Icon | Background | Border |
|--------|------|------------|--------|
| **Networking** | `Icons.hub_outlined` | `#3B82F6` at 20% | `#3B82F6` at 40% |
| **Nearby** | `Icons.near_me_outlined` | `#22C55E` at 20% | `#22C55E` at 40% |
| **Business** | `Icons.business_outlined` | `#EAB308` at 20% | `#EAB308` at 40% |
| **Chat** (default) | `Icons.chat_bubble_outline` | `#9CA3AF` at 20% | `#9CA3AF` at 40% |

**Tag styling:** padding horizontal 7 vertical 3, border radius 8, border width 0.5, icon 11px, text Poppins 11px w600

### Call Tile Layout (Calls Tab)

```
┌── Dismissible (swipe left to delete) ──────────────┐
│ margin: 12h, 3v | gradient: white@25% → white@15%  │
│ borderRadius: 16, border: white@30%, 1px            │
│                                                     │
│ [☐?] [Avatar 48px]  Name/GroupName  [Source Tag]    │
│                      [↗] joined N          [📞]     │
│                      2m ago                         │
└─────────────────────────────────────────────────────┘
```

**Call status icons (size 14):**
- `Icons.call_missed` (red) — missed / no_answer / timeout
- `Icons.call_missed_outgoing` (red) — declined / rejected / busy / canceled
- `Icons.call_made` (green) — outgoing calls
- `Icons.call_received` (green) — incoming calls

**Dismissible delete background:** Red, border radius 14, trash icon aligned right

### Call Type Tag Additional Sources

| Source | Icon | Color |
|--------|------|-------|
| **Group Call** | `Icons.groups_outlined` | `#8B5CF6` (Purple) |
| **Call History** | `Icons.history` | `#F97316` (Orange) |

### Empty States

| Tab | Icon (80px, grey[700]) | Title (20px, bold, white) | Subtitle (14px, grey[600]) |
|-----|------------------------|---------------------------|----------------------------|
| Chats | `chat_bubble_outline` | "No chats yet" | "Start a new conversation" |
| Groups | `group_outlined` | "No groups yet" | "Create a group to get started" |
| Calls | `call_outlined` | "No calls yet" | "Your call history will appear here" |

### Data Sources (Firestore)

| Collection | Query | Limit |
|------------|-------|-------|
| `conversations` | `where('participants', arrayContains: currentUserId)` | `limit(50)` |
| `users/{userId}/hiddenConversations` | `.get()` | No limit |
| `users/{userId}` | `.doc(userId).get()` or `.snapshots()` | Single doc |
| `calls` | `where('participants', arrayContains: uid).orderBy('timestamp', descending: true)` | `limit(30)` |
| `group_calls` | `where('participants', arrayContains: uid).orderBy('createdAt', descending: true)` | `limit(30)` |

### Special Features

1. **Source Tag Migration:** One-time migration (`conversation_sources_migrated_v3`) retroactively tags old conversations by checking `connection_requests` to determine if the user is a connection (Networking) or not (Nearby).
2. **Typing Indicator:** Reads `isTyping` map from conversation document. Shows "Typing..." in message preview.
3. **User Data Caching:** In-memory `Map<String, Map<String, dynamic>>` cache with batch prefetching (10 users at a time).
4. **Call Cleanup:** Auto-ends calls stuck in `calling`/`ringing` state for >5 minutes.
5. **Hidden Conversations:** Reads from `users/{uid}/hiddenConversations` subcollection + legacy `deletedBy` array.
6. **Video Call Prevention:** Blocks with SnackBar: "Video calling is not available".
7. **Lazy Call Listeners:** Call streams start only when Calls tab becomes active, stopped when leaving.

### Navigation

| From | To | Parameters |
|------|----|------------|
| Conversation tile (direct) | `EnhancedChatScreen` | `otherUser`, `chatId`, `source` |
| Conversation tile (group) | `GroupChatScreen` | `groupId`, `groupName` |
| Person_add (Chats tab) | `_NewMessageScreen` | `currentUserId` |
| Person_add (Groups tab) | `CreateGroupScreen` | none (returns groupId) |
| Call button (individual) | `VoiceCallScreen` | `callId`, `otherUser`, `isOutgoing: true` |
| Call button (group) | `GroupAudioCallScreen` | `callId`, `groupId`, `userId`, `userName`, `groupName`, `participants` |

### _NewMessageScreen (Private Inner Class)

Full-screen contacts picker for starting a new 1-on-1 chat.

- **AppBar:** "New Message", Poppins 20px bold white, gradient `#282828` → `#323232`
- **Contact list:** Streams all non-group conversations to extract unique contacts
- **Contact tile:** Glass card with avatar (online green dot indicator 14x14), name (Poppins 16px w600 white), subtitle "Active now" (green) or "Tap to message"
- **Empty state:** `people_outline` icon, "No contacts yet", "Start chatting with people from Home or Live Connect"
- **Navigation:** Tap contact → `EnhancedChatScreen` via `pushReplacement`

### Body Background

```
Gradient: #404040 (top) → #000000 (bottom)
```

---

## 2. Enhanced Chat Screen (1-on-1 Chat)

**File:** `lib/screens/chat/enhanced_chat_screen.dart`
**Class:** `EnhancedChatScreen` (ConsumerStatefulWidget with `WidgetsBindingObserver`, `TickerProviderStateMixin`)
**Purpose:** The primary 1-on-1 chat screen. Provides full-featured real-time messaging: text, images, videos, voice recording, voice calling, AI @mention integration, message editing, reply-to, forwarding, multi-select, search, chat themes, and message status tracking.
**Total Lines:** ~12,489

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `otherUser` | `UserProfile` | Yes | — | The other user's profile |
| `initialMessage` | `String?` | No | `null` | Auto-sends on screen open |
| `chatId` | `String?` | No | `null` | Pre-existing chatId |
| `isBusinessChat` | `bool` | No | `false` | Business conversation flag |
| `business` | `BusinessModel?` | No | `null` | Business info for business chats |
| `source` | `String?` | No | `null` | Origin: "Nearby", "Networking", "Chat", "Call" |

### AppBar Layout — Normal Mode

```
┌────────────────────────────────────────────────────────┐
│ [←]  [Avatar+Online] Name          [📹] [📞] [⋮]      │
│                      Active now / Typing...            │
│────────────────────────────────────────────────────────│
```

| Element | Details |
|---------|---------|
| **Back button** | `Icons.arrow_back_ios_rounded`, white, 22px |
| **Avatar** | CircleAvatar radius 18, circular white border 2px at 70%. Online dot: 10x10 green circle, positioned bottom-right |
| **Name** | `_otherName`, w600, ellipsis |
| **Business badge** | `#00D67D` at 20% bg, "Business" text 9px w600 |
| **Status subtitle** | "Typing..." (primary color, italic) / "Active now" (green) / "Active {timeago}" (grey) / "Status hidden" (grey) |
| **Video call** | `Icons.videocam_rounded`, white70, 24px |
| **Voice call** | `Icons.call_rounded`, white70, 24px |
| **More** | `Icons.more_vert_rounded`, white70, 24px → opens `_ChatInfoScreen` |

**AppBar gradient:** `#66000000` → `#33000000` → `#00000000` (top to bottom)
**Bottom divider:** 1px solid white

### AppBar Layout — Multi-Select Mode

```
┌────────────────────────────────────────────────────────┐
│ [X]          "N selected"           [forward] [delete] │
└────────────────────────────────────────────────────────┘
```

- **Background:** `Colors.blue` at 90%
- **Title:** Poppins 18px w600 white

### Online Status Logic

- `showOnlineStatus == false` → "Status hidden"
- `isOnline == true` AND `lastSeen` within 5 minutes → "Active now" (green)
- Otherwise → "Active {timeago}" (grey)

### Message Bubble Layout

**Structure:** `Dismissible` (swipe-to-reply) → `GestureDetector` → `TweenAnimationBuilder` (300ms scale+opacity) → bubble container

**Bubble Shape (ClipRRect + BackdropFilter blur 10x10):**
- topLeft: 16px, topRight: 16px
- bottomLeft: 16px (sent) / 0px (received)
- bottomRight: 0px (sent) / 16px (received)

**Bubble Decoration (text/audio):**
- Gradient: `Colors.white` at 25% → 15% (topLeft to bottomRight)
- Border: 1px solid white
- Max width: 70% screen

**Text Style:** Poppins, 14px, height 1.35, letterSpacing -0.2
- Sent: white
- Received: `AppColors.iosGrayDark` (light) / white (dark)

### Message Types Supported

| Type | Rendering | Details |
|------|-----------|---------|
| **Text** | `_buildTextWithMentions()` | @mention highlighting |
| **Image** | `_buildImageMessage()` | CachedNetworkImage, max 180px height, orange upload overlay |
| **Video** | `_buildVideoMessagePlayer()` | Black 200px container with play icon |
| **Audio** | `_buildAudioBubbleWithTime()` | 25-bar waveform, play/pause button |
| **Voice Call** | `_buildCallMessageBubble()` | Glass card with call icon |
| **Video Call** | `_buildCallMessageBubble()` | Glass card with video icon |
| **Missed Call** | `_buildCallMessageBubble()` | Red icon for receiver |
| **AI Message** | `_buildAiMessageBubble()` | Purple gradient with "Single Tap AI" label |
| **Deleted** | `_buildDeletedMessageBubble()` | Grey italic "This message was deleted" |

### Read Receipts

| Status | Icon | Details |
|--------|------|---------|
| `sending` | `CircularProgressIndicator` | 12x12, stroke 1.5, white 50% |
| `sent` | `Icons.check_rounded` | 16px, white 70% — single tick |
| `delivered` | `Icons.done_all_rounded` | 16px, white 70% — double grey tick |
| `read` | `Icons.done_all_rounded` | 16px, `Colors.blue` — double blue tick |
| `failed` | `Icons.error_outline_rounded` | 16px, `AppColors.iosRed` |

### Typing Indicator

**User typing:** CircleAvatar with user photo + 3 animated dots in grey bubble
**AI typing:** Purple circle (`#6366F1`) with `Icons.auto_awesome` + "Single Tap AI is thinking" text + 3 pulsing dots

**Dot animation:** `TweenAnimationBuilder` 0.4→1.0 opacity, staggered `400 + (index * 150)` ms, `Curves.easeInOut`

### Input Area

```
┌────────────────────────────────────────────────────────┐
│ ─────────────── 0.5px white@30% border ────────────── │
│                                                        │
│ [+]  [ Message...                    😊 ]  [↑] / [🎤] │
│                                                        │
│ ── Emoji Picker (35% screen height, 200-350px) ────── │
└────────────────────────────────────────────────────────┘
```

| Element | Details |
|---------|---------|
| **Plus button** | `Icons.add_circle`, white 80%, 44px. Opens camera/gallery options |
| **Text field** | Max 5 lines, rounded 20, white 15% bg, white 30% border. Hint: "Message" |
| **Emoji toggle** | `Icons.emoji_emotions_outlined` / `Icons.keyboard_rounded`, white 90%, 24px |
| **Send button** | 42x42 circle, white 20% bg, white 30% border. `Icons.arrow_upward_rounded`, white, 20px |
| **Mic button** | 42x42 (90 wide when recording), `Icons.mic_rounded`, white 80%, 28px. Recording: red bg with glow, timer + stop icon |

**Input gradient:** `#66000000` → `#80000000`

### Voice Recording

- **Codec:** AAC ADTS, 64kbps, 22050 Hz
- **Recording UI:** Mic button expands to 90px wide, red bg with glow shadow, timer (Poppins 10px bold white) + stop icon
- **Preview popup:** `_VoicePreviewPopup` with waveform, play/pause, delete, send buttons

### Audio Message Player

- **Layout:** 70% screen width, padding h10 v8
- **Play/pause:** 32x32 circle, `AppColors.iosBlue` bg (orange during upload), white icon 20px
- **Waveform:** 25 bars, 2px wide, predefined height pattern. Active: white, Inactive: white 40%
- **Duration:** Poppins 10px w500, white 90%

### @Mention System

- Typing `@` triggers suggestion popup (black 92%, rounded 14, max height 220)
- **AI entry:** Gradient circle `#6366F1` → `#8B5CF6`, "Single Tap AI", subtitle "Ask me anything"
- **Mention colors:** AI → `#818CF8`, User → `#00E5FF` (sent) / `#00B8D4` (received light)
- `_MentionTextEditingController` highlights mentions live in the input field
- When message contains `@Single Tap AI`, `AiChatService.processAiMention()` is invoked

### Message Long-Press Options

Dialog: dark bg `rgb(32,32,32)`, rounded 16, white border, close button top-right

| Option | Icon | Condition |
|--------|------|-----------|
| **Reply** | `Icons.reply` | Always |
| **Forward** | `Icons.forward` | Always |
| **Copy** | `Icons.copy` | Text messages only |
| **Save Image/Video/Audio/Document** | `Icons.download` | Media messages with URL |
| **Edit** | `Icons.edit` | Own text messages only |
| **Select** | `Icons.check_circle_outline` | Always |
| **Delete** | `Icons.delete` (red) | Always |

### Chat Info Screen (`_ChatInfoScreen`)

Full-page route with glass-morphism option tiles:

1. **View Profile** → `_UserProfileSheet` (DraggableScrollableSheet, initial 0.4, max 0.9)
2. **Mute/Unmute Notifications** → Switch toggle, updates `conversations/{id}.isMuted`
3. **Search in Conversation** → Activates in-chat search mode
4. **Change Theme** → Theme picker dialog with `chatThemeColors` swatches (50x50 circles)
5. **Media Gallery** → `MediaGalleryScreen`
6. **Block User** → Confirmation dialog, writes to `users/{uid}/blocked_users/{otherUid}`
7. **Delete Conversation (Clear Chat)** → Soft-delete via `deletedFor` array on each message

### Date Separators

- Glass pill: gradient white 25%→15%, white border, rounded 12
- Text: Poppins 12px w500, grey, letterSpacing -0.2
- Format: "Today", "Yesterday", day name (7 days), "MMM D, YYYY"

### Daily Media Rate Limiting

- **Limits:** 4 images, 4 videos, 4 audio per day per conversation
- **Tracked in:** SharedPreferences
- **Resets:** At midnight

### Scroll Behavior

- `reverse: true` (newest at bottom)
- Scroll-to-bottom button: 36x36 circle, bottom 16 right 16, `Icons.keyboard_arrow_down_rounded`, blue
- Pagination: 20 messages per page, cursor-based via `_lastDocument`

### Navigation

| To | Trigger | Route |
|----|---------|-------|
| `VoiceCallScreen` | Call button | `MaterialPageRoute` |
| `_ChatInfoScreen` | More button | `MaterialPageRoute` |
| `_ForwardMessageScreen` | Forward action | `MaterialPageRoute` (returns `List<UserProfile>`) |
| `PhotoViewerDialog` | Tap image | `showDialog` |
| `VideoPlayerScreen` | Tap video | `MaterialPageRoute` |
| `MediaGalleryScreen` | Chat Info → Media Gallery | `MaterialPageRoute` |

### Body Background

```
AppColors.splashGradient with optional chat theme overlay (30%/20% alpha)
```

---

## 3. Group Chat Screen

**File:** `lib/screens/chat/group_chat_screen.dart`
**Class:** `GroupChatScreen` (ConsumerStatefulWidget with `WidgetsBindingObserver`)
**Purpose:** Full-featured group messaging screen with text, images, videos, voice messages, group voice calling, @mentions, message editing/reply/forward/delete, multi-select, search, chat themes, and optimistic rendering.
**Total Lines:** ~7,951

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | `String` | Yes | Firestore document ID from `conversations` collection |
| `groupName` | `String` | Yes | Display name of the group |

### AppBar Layout — Normal Mode

```
┌────────────────────────────────────────────────────────┐
│ [←]  [GroupAvatar] GroupName          [📞] [⋮]         │
│                    5 members / Typing...               │
│────────────────────────────────────────────────────────│
```

| Element | Details |
|---------|---------|
| **Back button** | `Icons.arrow_back_ios_rounded`, white, 22px |
| **Group avatar** | CircleAvatar radius 18, white border 2px at 50%. CachedNetworkImage or `Icons.group` |
| **Group name** | `_currentGroupName`, Poppins 16px w600, white |
| **Subtitle** | Member count "N members" (grey 12px) or typing indicator (primary color, italic) |
| **Call button** | `Icons.call_rounded`, white70, 24px → `_startGroupAudioCall` |
| **More button** | `Icons.more_vert_rounded`, white70, 24px → `_showGroupInfo` (GroupInfoScreen) |

**AppBar gradient:** `#66000000` → `#33000000` → `#00000000`
**Bottom divider:** 1px solid white

**Title area is tappable** → navigates to `GroupInfoScreen`

### Group-Specific Message Features

**Sender name on received messages:**
- **Text messages:** Inside bubble at top, Poppins 10.5px w600 white, followed by white divider 20%
- **Image/Video:** Overlay bar at top of media, 60% black bg, Poppins 11px w600 white
- **Voice messages:** Inside player container at top, Poppins 12px w600 white, with divider

### Typing Indicator (Multiple Users)

- 1 user: "John is typing..."
- 2 users: "John and Jane are typing..."
- 3+ users: "3 people are typing..."
- AI typing: "Single Tap AI is thinking..."
- Combinations joined with space

### AI Thinking Indicator

- Purple circle avatar (14px) with `Icons.auto_awesome`
- Gradient bubble `#6366F1` at 30% → `#8B5CF6` at 20%
- Text "Single Tap AI is thinking" at `#6366F1`, 11px, w500
- 3 animated pulsing dots (staggered 400ms + 150ms per dot)

### AI Message Bubble

- Label: SingleTap.png logo (14x14) + "Single Tap AI" in `#6366F1`, Poppins 11px w600
- Bubble gradient: `#6366F1` at 30% → `#8B5CF6` at 20%
- Border: `#6366F1` at 50%, 1px
- Shape: rounded top + right, sharp bottom-left
- Bold text rendered in `#818CF8` w600

### Active Call Banner

```
┌─────────────────────────────────────────────────────┐
│ 🟢 [Avatars]  🔊 Tap to join call  2 members [Join] │
│    Background: #00A884 (WhatsApp green), radius 12  │
└─────────────────────────────────────────────────────┘
```

- Stacked participant avatars (up to 2), call icon, member count
- White "Join" pill button
- Auto-ends stale calls older than 45 seconds with no active participants

### Read Receipts (Group-Specific)

| Condition | Icon | Details |
|-----------|------|---------|
| readCount ≤ 1 (only sender) | `Icons.check_rounded` (14px) | Single grey tick |
| readCount > 1 but < totalMembers | `Icons.done_all_rounded` (14px) | Double grey tick |
| readCount ≥ totalMembers | `Icons.done_all_rounded` (14px, blue) | Double blue tick |

### Video Constraints

- Maximum file size: **25MB**
- Maximum duration: **28 seconds**
- Validated via `VideoPlayerController` before upload

### Daily Media Limits

- **4 images, 4 videos, 4 audio** per user per group per 24 hours
- Tracked in SharedPreferences with keys: `{groupId}_{userId}_imageCount` etc.
- Limit error message (Urdu/Roman Urdu): "Already aap ki daily limit khatam ho gayi hai..."

### Message Deletion

- **Delete for me:** Adds userId to `deletedFor` array, filtered client-side
- **Delete for everyone (own messages only):** Sets `isDeleted: true`, clears media URLs, deletes from Storage

### Navigation

| To | Trigger | Parameters |
|----|---------|------------|
| `GroupInfoScreen` | AppBar title/more tap | `groupId`, `groupName`, `groupPhoto`, `memberIds`. Returns `'search'` or `'theme'` |
| `GroupAudioCallScreen` | Call button / Join banner | `callId`, `groupId`, `userId`, `userName`, `groupName`, `participants` |
| `VideoPlayerScreen` | Tap video | `videoUrl`, `isLocalFile` |
| `PhotoViewerDialog` | Tap network image | `imageUrl` |
| `_ForwardMessageScreen` | Forward action | Returns `List<Map>` of recipients |

### Body Background

```
AppColors.splashGradient with optional chat theme overlay (30%/20% alpha)
```

---

## 4. Create Group Screen

**File:** `lib/screens/chat/create_group_screen.dart`
**Class:** `CreateGroupScreen` (ConsumerStatefulWidget)
**Purpose:** Single-page flow for creating a new group chat. User types group name, searches/selects members, and taps "Create".

### Constructor Parameters

```dart
const CreateGroupScreen({super.key});
```

No custom parameters. All data fetched from Firestore and Riverpod `currentUserIdProvider`.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│ [←]              "New Group"              [Create] │
│    Background: #404040, bottom border: white 1px   │
└────────────────────────────────────────────────────┘
```

| Element | Details |
|---------|---------|
| **Back** | `Icons.arrow_back_ios_new`, white |
| **Title** | "New Group", Poppins 20px bold white, centered |
| **Create** | White text, 16px w600. Shows `CircularProgressIndicator` (20x20, stroke 2) when creating |

### UI Layout

```
┌────────────────────────────────────────────────────┐
│ [Group name field]  [Search users field]           │
│ padding: fromLTRB(16, 16, 16, 8), gap: 10px       │
├────────────────────────────────────────────────────┤
│ [Selected Chip] [Selected Chip] [Selected Chip]... │
│ height: 50, padding: h16, scrollable horizontal    │
├────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────┐ │
│ │ [Avatar 48px ✓] Name            [○ / ✓ check] │ │
│ │ gradient: white@25%→15%, radius: 16            │ │
│ ├────────────────────────────────────────────────┤ │
│ │ [Avatar 48px]   Name            [○]           │ │
│ └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### Text Fields

| Field | Hint | Icon | Border Radius |
|-------|------|------|---------------|
| **Group name** | "Group name" | `Icons.group`, white70, 20px | 12 |
| **Search** | "Search users..." | `Icons.search`, white70, 20px | 12 |

Both use `GlassTextField` with glassmorphism: `BackdropFilter` blur 10x10, white 15% bg, white 30% 1.5px border

### Selected Member Chips

- **Background:** white at 15% alpha
- **Border:** white at 30% alpha
- **Label:** User name, white
- **Delete icon:** `Icons.close`, 18px, white70
- **Margin:** right 8 between chips

### User List Item

| State | Gradient | Name Weight | Trailing |
|-------|----------|-------------|----------|
| **Unselected** | white@25% → white@15% | normal | `Icons.circle_outlined`, white 30% |
| **Selected** | white@30% → white@20% | w600 | `Icons.check_circle`, white |

**Avatar:** CircleAvatar radius 24 (48px), white 30% border 1.5px. Photo or initial letter.
**Selected badge:** 20x20 white circle with black check (12px), positioned bottom-right of avatar.
**Tap:** `HapticFeedback.selectionClick()`

### Validation

1. Group name must not be empty → orange SnackBar "Please enter a group name"
2. At least 1 member selected → orange SnackBar "Please select at least one member"

### Data Source

- `_firestore.collection('users').snapshots()` — **no limit** (all users, real-time stream)
- Client-side filtering by name substring match

### Navigation

- **Back:** `Navigator.pop(context)`
- **Create success:** `Navigator.pop(context, groupId)` — returns new group ID to caller

### Body Background

```
Gradient: #404040 (top) → #000000 (bottom)
```

---

## 5. Group Info Screen

**File:** `lib/screens/chat/group_info_screen.dart`
**Class:** `GroupInfoScreen` (ConsumerStatefulWidget)
**Purpose:** Group information and settings panel. Shows group photo/name, members list with admin badges, and management actions.
**Total Lines:** ~1,515

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | `String` | Yes | Firestore document ID |
| `groupName` | `String` | Yes | Group display name |
| `groupPhoto` | `String?` | No | Group photo URL |
| `memberIds` | `List<String>` | Yes | List of member user IDs |

### Custom AppBar

```
┌────────────────────────────────────────────────────┐
│ [←]              "Group Info"              [48px]   │
│ padding: h8 v8 | Title: 20px w600 white centered   │
│────────────────────────────────────────────────────│
```

Below: 1px white divider

### UI Layout

```
┌────────────────────────────────────────────────────┐
│  ┌── Group Profile Card (glass, radius 16) ─────┐ │
│  │        [Group Photo 90px]  📷                 │ │
│  │        Group Name  ✏️                         │ │
│  │        5 members                              │ │
│  │        [+ Add Members]                        │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  ┌── Option Tiles (glass, radius 16) ───────────┐ │
│  │ 🔔 Mute Notifications          [Switch]      │ │
│  │ 🔍 Search in Conversation       [>]           │ │
│  │ 🎨 Change Theme                 [>]           │ │
│  │ 🖼️ Media Gallery                [>]           │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  ┌── Members Section (glass, radius 16) ────────┐ │
│  │ Members                                       │ │
│  │ ─────────────────────────                     │ │
│  │ [Avatar] John (You)                           │ │
│  │ [Avatar] Jane              Group Admin  [💬]   │ │
│  │ [Avatar] Bob                            [💬]   │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  ┌── More Options (glass, radius 16) ───────────┐ │
│  │ 🚪 Leave Group                  [>]           │ │
│  │ 🗑️ Delete Conversation           [>]           │ │
│  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### Glass-Morphism Effect (used in all cards)

- `ClipRRect(borderRadius: 16)` + `BackdropFilter(blur: sigma 10x10)`
- Background: white at 10% alpha
- Border: white at 10% alpha

### Group Profile Card Details

| Element | Details |
|---------|---------|
| **Group photo** | CircleAvatar radius 45 (90px). Tappable → camera/gallery picker. Camera overlay badge: `AppColors.iosBlue` circle with camera icon |
| **Photo upload** | Max 512x512, quality 80, uploads to `group_photos/{groupId}.jpg` |
| **Group name** | 28px bold white. Tappable → edit dialog (max 50 chars) |
| **Edit icon** | `Icons.edit_outlined`, white 60%, 20px |
| **Members count** | 16px, white 70% |
| **Add Members button** | `AppColors.iosBlue` bg, padding h24 v12 |

### Members List

| Field | Details |
|-------|---------|
| **Avatar** | CircleAvatar radius 20, grey[800] bg. Photo or initial letter (16px white) |
| **Name** | White, w500. Current user shows "(You)" suffix |
| **Admin badge** | "Group Admin" text in `#4FC3F7` (light blue), 12px w500. Shown when memberId == createdBy |
| **Message button** | `Icons.message_rounded`, white, 22px. Opens `EnhancedChatScreen` with member |
| **Divider** | white 30%, thickness 0.5 |

### Edit Group Name Dialog

- Background: `rgb(32,32,32)`, border radius 20, white border
- TextField: autofocus, maxLength 50, filled with white 10%, radius 12
- Buttons: "Cancel" (ghost, white border) + "Save" (`AppColors.iosBlue`, radius 12)

### Add Members Dialog (`_AddMembersDialog`)

- maxHeight 750, maxWidth 520, dark bg `rgb(32,32,32)`, white border, radius 16
- Search field: "Search users...", search icon, filled white 10%, radius 12
- Selected count badge: `AppColors.iosBlue` at 20% bg
- User list: CircleAvatar radius 24, check/uncheck trailing icon
- Buttons: "Cancel" (ghost) + "Add" (`AppColors.iosBlue`, disabled: grey[800])

### Leave Group

- Confirmation dialog with red circle icon (`Icons.exit_to_app_rounded`)
- Title: "Leave Group?", 20px bold white
- On confirm: removes from participants, transfers ownership if creator, double-pops (info + chat)

### Delete Conversation (Clear Chat)

- Confirmation dialog with red circle icon (`Icons.delete_rounded`)
- Title: "Clear Chat?", 20px bold white
- Soft-delete: adds userId to `deletedFor` array on all messages (batch update)
- Single pop (info screen only)

### Navigation

| Action | Navigation | Result |
|--------|-----------|--------|
| Back | `Navigator.pop(context)` | No result |
| Search | `Navigator.pop(context, 'search')` | Returns `'search'` string |
| Change Theme | `Navigator.pop(context, 'theme')` | Returns `'theme'` string |
| Media Gallery | `Navigator.push` | `GroupMediaGalleryScreen(groupId, groupName)` |
| Message member | `Navigator.push` | `EnhancedChatScreen(otherUser: userProfile)` |
| Leave Group | Double pop | Returns to conversation list |

### Body Background

```
AppColors.splashGradient over AppColors.backgroundDark scaffold
```

---

## 6. Media Gallery Screen (1-on-1)

**File:** `lib/screens/chat/media_gallery_screen.dart`
**Class:** `MediaGalleryScreen` (StatefulWidget with `SingleTickerProviderStateMixin`)
**Purpose:** Displays all media shared in a 1-on-1 conversation across four tabs.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `conversationId` | `String` | Yes | Firestore conversation document ID |
| `otherUserName` | `String` | Yes | Other user's display name |

### AppBar & Tab Layout

```
┌────────────────────────────────────────────────────┐
│ [←]           Media Gallery                        │
│ Background: splashDark1, bottom border: white 1px  │
├────────────────────────────────────────────────────┤
│ [ Photos ]  [ Videos ]  [ Links ]  [ Files ]       │
│ indicator: white 3px | selected: 15px w600 white   │
│ unselected: white60 15px w500                      │
└────────────────────────────────────────────────────┘
```

### Tab Content

**Photos Tab:**

```
┌──────────────────────────────────────────────────┐
│ [60x60 thumb]  Photo              [🗑️]            │
│                Mon, Mar 2 • 3:42 PM              │
│ glass: white@25%→15%, radius 16, blur 10x10      │
└──────────────────────────────────────────────────┘
```

**Videos Tab:**

```
┌──────────────────────────────────────────────────┐
│ [80x60 thumb+▶]  Video            [🗑️]            │
│                   Wed • 5:30 PM                  │
└──────────────────────────────────────────────────┘
```

**Links Tab:**

```
┌──────────────────────────────────────────────────┐
│ [🔗]  https://examp...            [🗑️ red]         │
│        Today • 9:00 AM                           │
│ glass: white@25%→15%, radius 12                  │
└──────────────────────────────────────────────────┘
```

**Files Tab:**

```
┌──────────────────────────────────────────────────┐
│ [🎤]  Voice Message               [🗑️]            │
│        Yesterday • 4:22 PM                       │
└──────────────────────────────────────────────────┘
```

### Features

- **Real-time streaming:** `StreamBuilder` on each tab with Firestore `.limit(500)`
- **Soft-delete per user:** `deletedFor` array with `FieldValue.arrayUnion`
- **Smart detection:** Checks file extensions + keyword heuristics + Firebase Storage paths
- **Delete confirmation:** AlertDialog before every delete

### Empty State (all tabs)

- 120x120 glass circle with icon (60px, white 30%)
- Title: "No [Photos/Videos/Links/Files]" (20px w600)
- Subtitle: "[Type] shared in this chat will appear here" (14px, white 60%)

### Actions

| Action | Trigger | Result |
|--------|---------|--------|
| View photo | Tap photo item | `PhotoViewerDialog.show()` |
| Play video | Tap video item | Push `VideoPlayerScreen` |
| View link | Tap link item | `LinkPreviewDialog.show()` |
| Play voice | Tap voice file | `AudioPlayerDialog.show()` |
| Open file | Tap non-voice file | `launchUrl()` external browser |
| Delete | Tap trash icon | Confirmation → soft-delete |

### Body Background

```
AppColors.splashGradient
```

---

## 7. Group Media Gallery Screen

**File:** `lib/screens/chat/group_media_gallery_screen.dart`
**Class:** `GroupMediaGalleryScreen` (StatefulWidget with `SingleTickerProviderStateMixin`)
**Purpose:** Same as MediaGalleryScreen but for group conversations.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | `String` | Yes | Group conversation document ID |
| `groupName` | `String` | Yes | Group display name |

### Differences from MediaGalleryScreen

| Feature | MediaGalleryScreen | GroupMediaGalleryScreen |
|---------|-------------------|----------------------|
| Title | "Media Gallery" | "Group Media Gallery" |
| Photo viewer | `PhotoViewerDialog` | Inline `_showPhotoViewer()` with `InteractiveViewer` + timestamp pill |
| Link tap | `LinkPreviewDialog` | Opens URL directly in browser |
| Firestore query | `.limit(500)` | **No limit** (performance concern) |
| Date format (today) | "Mon, Mar 16 • 3:42 PM" | "Today • 3:42 PM" |
| Date format (yesterday) | "Sun, Mar 15" | "Yesterday • 3:42 PM" |
| Date format (this week) | "Wed, Mar 11" | "Wednesday • 3:42 PM" |
| File download | `launchUrl()` | Not implemented (empty else branch) |

---

## 8. Audio Player Dialog

**File:** `lib/screens/chat/audio_player_dialog.dart`
**Class:** `AudioPlayerDialog` (StatefulWidget)
**Purpose:** Modal dialog for playing audio/voice messages with play/pause, seek, rewind/forward.

### Constructor & Static Factory

```dart
AudioPlayerDialog({required String audioUrl, String title = 'Voice Message'})
static Future<void> show(BuildContext context, String audioUrl, {String? title})
```

### UI Layout

```
┌──────────────────────────────────────────────┐
│ Voice Message                          [X]   │
│                                              │
│              ┌──────────┐                    │
│              │  🎤 / 🎵  │   80x80 circle    │
│              └──────────┘   white@15% bg     │
│                                              │
│  ====O===================================    │
│  01:23                            03:45      │
│                                              │
│       [⏪10]      [ ▶ ]       [10⏩]         │
└──────────────────────────────────────────────┘
```

### Styling

- **Container gradient:** `#404040` → `#000000`
- **Border:** 1px white, radius 16
- **Padding:** 24px all
- **Title:** 18px w600
- **Waveform circle:** 80x80, white 15% bg. Icon: `Icons.graphic_eq` (playing) / `Icons.mic` (paused), white 40px
- **Slider:** Track 4px, white active, white24 inactive, white thumb radius 6
- **Time text:** 12px, white70
- **Play/Pause:** Circle white 25% bg, white border 1px. Icon 32px white
- **Rewind/Forward:** white70, 28px

### Features

- Play/Pause toggle
- Seek bar (Slider)
- Rewind 10s / Forward 10s with bounds checking
- Duration display MM:SS
- Auto-reset on completion
- Error state with red icon
- Uses `audioplayers` package

---

## 9. Link Preview Dialog

**File:** `lib/screens/chat/link_preview_dialog.dart`
**Class:** `LinkPreviewDialog` (StatelessWidget)
**Purpose:** Modal dialog showing URL preview with copy and open-in-browser actions.

### Constructor & Static Factory

```dart
LinkPreviewDialog({required String url, String? messageText, DateTime? timestamp})
static Future<void> show(BuildContext context, String url, {String? messageText, DateTime? timestamp})
```

### UI Layout

```
┌──────────────────────────────────────────────┐
│ Link Preview                           [X]   │
│                                              │
│         ┌──────────┐                         │
│         │   🔗     │  80x80, white@15%       │
│         └──────────┘                         │
│       www.example.com (16px w600)            │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ https://example.com/long/path...  [📋] │  │
│  │ white@8% bg, radius 8, 13px white70    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Message text... (14px white70, max 4)  │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  [ Copy ]                [  Open Link  ]     │
│  (ghost, flex:1)         (white bg, flex:2)  │
└──────────────────────────────────────────────┘
```

### Styling

- **Container max width:** 400px
- **Container gradient:** `#404040` → `#000000`
- **Border:** 1px white, radius 16
- **Domain section:** white 10% bg, radius 12, padding 24
- **URL section:** white 8% bg, radius 8, padding 12
- **Copy button:** OutlinedButton, white30 border, radius 8
- **Open Link button:** ElevatedButton, white bg black text, radius 8

### Features

- Domain extraction via `Uri.parse().host`
- Copy to clipboard with green SnackBar
- Open in external browser via `launchUrl`
- Message text display (if provided, max 4 lines)

---

## 10. Photo Viewer Dialog

**File:** `lib/screens/chat/photo_viewer_dialog.dart`
**Class:** `PhotoViewerDialog` (StatefulWidget)
**Purpose:** Modal dialog for viewing photos with pinch-to-zoom and zoom controls.

### Constructor & Static Factory

```dart
PhotoViewerDialog({required String imageUrl, String title = 'Photo'})
static Future<void> show(BuildContext context, String imageUrl, {String? title})
```

**Barrier color:** `Colors.black87`

### UI Layout

```
┌──────────────────────────────────────────────┐
│ Photo                    [⬇️ download] [X]   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │                                        │  │
│  │     (Full image, pinch-to-zoom         │  │
│  │      via InteractiveViewer)            │  │
│  │     min: 0.5x, max: 4.0x              │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│      [-]    🔄 Reset Zoom    [+]             │
└──────────────────────────────────────────────┘
```

### Styling

- **Max height:** 80% screen
- **Max width:** 90% screen
- **Container gradient:** `#404040` → `#000000`
- **Border:** 1px white, radius 16
- **Loading:** `CircularProgressIndicator`
- **Error:** Red icon 48px + text

### Features

- Pinch-to-zoom (InteractiveViewer, 0.5x–4.0x)
- Zoom in/out buttons (±0.5 step)
- Reset zoom button
- Download opens URL in external browser
- `CachedNetworkImage` for loading

---

## 11. Video Player Screen

**File:** `lib/screens/chat/video_player_screen.dart`
**Class:** `VideoPlayerScreen` (StatefulWidget)
**Purpose:** Fullscreen video player with auto-hiding controls.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `videoUrl` | `String` | Yes | — | Network URL or local file path |
| `isLocalFile` | `bool` | No | `false` | Whether URL is a local file |

### UI Layout

```
┌──────────────────────────────────────────────┐
│ [X]                  (top gradient overlay)   │
│                                              │
│                                              │
│              ┌──────────┐                    │
│              │    ▶     │  64px white         │
│              └──────────┘  black@50% circle   │
│                                              │
│  ============================================ │
│  [▶]  01:23 / 05:45   (bottom gradient)      │
└──────────────────────────────────────────────┘
```

### Styling

- **Scaffold background:** black
- **Top gradient:** `black@70%` → transparent
- **Bottom gradient:** `black@70%` → transparent
- **Close button:** white, 28px, SafeArea
- **Center play overlay:** `black@50%` circle, play icon 64px white (shown when paused + controls visible)
- **Progress bar:** white played, white38 buffered, white24 background
- **Time text:** white, 14px

### Features

- Auto-play on init
- Auto-hide controls after 3 seconds
- Tap to toggle controls
- Scrubbing via `VideoProgressIndicator`
- Play/Pause at center (64px) and bottom (32px)
- Time display MM:SS / MM:SS
- Supports both network and local files
- Preserves aspect ratio

---

## 12. Business Conversations Screen

**File:** `lib/screens/business/business_conversations_screen.dart`
**Class:** `BusinessConversationsScreen` (StatefulWidget)
**Purpose:** Standalone screen showing all conversations for a specific business. Has own Scaffold with back button.

### Constructor Parameters

| Parameter | Type | Required |
|-----------|------|----------|
| `business` | `BusinessModel` | Yes |

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│ [←]  [Logo]  Messages                 [Business]   │
│               BusinessName              (green)    │
└────────────────────────────────────────────────────┘
```

- **Business badge:** `#00D67D` at 20% bg, "Business" text

### Features

- Glass-morphism UI with `BackdropFilter` blur 10
- Search bar: frosted-glass, "Search conversations..."
- Conversation tiles: avatar (deterministic color), name (Title Case), time ago, last message, unread badge
- Unread badge: up to 99, then "99+"
- `HapticFeedback.lightImpact()` on tap
- Navigation to `EnhancedChatScreen` with `isBusinessChat: true, source: 'Business'`

### Avatar Colors (10 colors)

`#6366F1`, `#8B5CF6`, `#EC4899`, `#EF4444`, `#F97316`, `#22C55E`, `#14B8A6`, `#06B6D4`, `#3B82F6`, `#A855F7`

---

## 13. Business Messages Tab

**File:** `lib/screens/business/business_messages_tab.dart`
**Class:** `BusinessMessagesTab` (StatefulWidget)
**Purpose:** Tab-embeddable version of business conversations (no Scaffold). Adds advanced user search — searches both existing conversations AND all users in the `users/` collection.

### Differences from BusinessConversationsScreen

| Feature | BusinessConversationsScreen | BusinessMessagesTab |
|---------|---------------------------|---------------------|
| Scaffold | Yes (with back button) | No (embedded in tab) |
| Search | Conversations only | Conversations + all users |
| Username search | No | Yes (`@username` prefix supported) |
| User cache | No | In-memory `_userCache` |
| Bottom padding | No | 80px (for nav bar) |

### User Search

- Three-phase: (1) existing conversations, (2) `users` by `nameLower`, (3) `users` by `username`
- Capitalised fallback if `nameLower` yields no results
- Deduplication via `seenUserIds` set
- Results show both conversation tiles and user search results with @username display

---

## Services

### A. ActiveChatService

**File:** `lib/services/active_chat_service.dart`
**Purpose:** Singleton that tracks which chat is currently open to suppress duplicate notifications.

| Method | Description |
|--------|-------------|
| `setActiveChat({conversationId, userId})` | Register open chat |
| `clearActiveChat()` | Clear when leaving chat |
| `isConversationActive(id)` | Check if conversation is on-screen |
| `isUserChatActive(userId)` | Check if user's chat is on-screen |

**No Firestore usage.** Pure in-memory service.

---

### B. AiChatService

**File:** `lib/services/ai_chat_service.dart`
**Purpose:** Handles `@Single Tap AI` in-chat assistant. Calls Gemini API with key rotation and model fallback, saves AI response to Firestore.

**Model chain:** `gemini-2.5-flash` → `gemini-2.0-flash` → `gemini-2.0-flash-lite`
**API version fallback:** `v1beta` → `v1`
**Rate limit management:** `_exhaustedKeys` (15-min TTL), `_rateLimitedKeys` (2-min TTL)

| Firestore Path | Usage |
|----------------|-------|
| `conversations/{id}/messages` | Write AI responses |
| `conversations/{id}` | Update `lastMessage`, `isTyping` |

**AI Message Structure:**
```javascript
{
  senderId: 'singletap_ai',
  text: String,
  timestamp: serverTimestamp,
  isAiMessage: true,
  isSystemMessage: false,
  status: 2  // delivered
}
```

---

### C. HybridChatService

**File:** `lib/services/hybrid_chat_service.dart`
**Purpose:** Hybrid local SQLite + Firebase messaging. Messages saved locally first for instant display, then synced to Firebase.

**Key capabilities:**
- `sendMessage()` — Local-first with async Firebase sync
- `uploadMedia()` — Compress + upload to `chat_media/{userId}/`
- `markMessagesAsRead/Delivered()` — Batch update with deduplication guards
- `editMessage()`, `deleteMessage()` — Local + Firebase sync
- `searchMessages()` — Full-text search in local SQLite

**Message Status Flow:**
1. `sending` — Clock icon
2. `sent` — Single tick
3. `delivered` — Double grey ticks
4. `read` — Double colored ticks

---

### D. GroupChatService

**File:** `lib/services/group_chat_service.dart`
**Purpose:** Full group chat management: creation, membership, messaging with mentions/notifications, per-user read tracking, typing indicators.

**Key methods:**
- `createGroup()` — Creates `group_{uuid}` conversation
- `addMembers()` / `removeMember()` — Admin-only, with system messages
- `makeAdmin()` / `removeAdmin()` — Creator-only
- `sendMessage()` — Batch write (message + metadata), increments `unreadCount`, FCM for mentions
- `markAsRead()` — Resets `unreadCount`, adds to `readBy` on last 50 messages
- `leaveGroup()` — Ownership transfer if creator, group deletion if last member

**Group Conversation Structure:**
```javascript
{
  id: 'group_{uuid}',
  isGroup: true,
  groupName: String,
  groupPhoto: String?,
  participants: [String],
  participantNames: {userId: name},
  participantPhotos: {userId: photoUrl},
  admins: [String],
  createdBy: String,
  unreadCount: {userId: int},
  isTyping: {userId: bool},
  readBy: {userId: Timestamp}
}
```

---

### E. ConversationService

**File:** `lib/services/chat_services/conversation_service.dart`
**Purpose:** Core conversation lifecycle for personal and business chats. Handles creation, retrieval, messaging, duplicate cleanup, and orphan detection.

**Key methods:**
- `generateConversationId(uid1, uid2)` — Deterministic sorted ID
- `getOrCreateConversation(otherUser, {source})` — With background validation
- `sendMessage()` — Write + update lastMessage + increment unreadCount
- `cleanupDuplicateConversations()` — Merge messages, delete duplicates
- `deleteOrphanedConversations()` — Remove conversations with missing participants

**Business methods:**
- `generateBusinessConversationId(businessId, userId)` — Format: `business_{bid}_{uid}`
- `getOrCreateBusinessConversation()` — With business metadata
- `sendBusinessMessage()` — Adds `isBusinessMessage: true`, `businessId`, `businessName`

**Self-healing:** `_validateAndFixParticipants()` reconstructs participants array from conversation ID if corrupted.

---

### F. chat_common.dart (Shared Widgets)

**File:** `lib/widgets/chat widgets/chat_common.dart`
**Purpose:** Shared, reusable chat UI components and utilities.

#### `formatDisplayName(String name)` → `String`
Converts any name to Title Case. E.g., "JOHN DOE" → "John Doe"

#### Chat Theme Colors (`chatThemeColors`)

| Theme | Color 1 | Color 2 | Description |
|-------|---------|---------|-------------|
| `default` | `#404040` | `#000000` | Dark gray to black |
| `sunset` | `#FF6B6B` | `#FF8E53` | Red to orange |
| `ocean` | `#00B4DB` | `#0083B0` | Cyan to blue |
| `forest` | `#56AB2F` | `#A8E063` | Green gradient |
| `berry` | `#8E2DE2` | `#4A00E0` | Purple |
| `midnight` | `#232526` | `#414345` | Dark gray |
| `rose` | `#FF0844` | `#FFB199` | Pink to peach |
| `golden` | `#F7971E` | `#FFD200` | Orange to gold |

#### `ChatMessageInput` Widget

Unified message input bar with attachment, emoji toggle, mic, and send button.

| Prop | Type | Description |
|------|------|-------------|
| `controller` | `TextEditingController` | Text input controller |
| `focusNode` | `FocusNode` | Keyboard focus |
| `showEmojiPicker` | `bool` | Emoji picker state |
| `isSending` | `bool` | Shows loading spinner |
| `onSend` | `VoidCallback` | Send action |
| `onAttachment` | `VoidCallback` | Attachment action |
| `onEmojiToggle` | `VoidCallback` | Emoji toggle |
| `onMicTap` | `VoidCallback?` | Mic tap (shows mic when no text) |
| `onChanged` | `Function(String)` | Text change callback |
| `onTextFieldTap` | `VoidCallback` | Text field tap |

#### `ChatEmojiPicker` Widget

Consistent emoji picker. Height: 35% screen (200–350px). 8 columns, 28px emoji, search enabled.

#### `ChatMessageBubble` Widget

Glass-morphism message bubble with:
- Asymmetric corners (18px everywhere, 4px on sender's side)
- Gradient: white@25% → white@15%, 1px white border
- Read receipts: `done_all` green `#34C759` (read) / `done` white 70% (unread)
- Sender name in `primaryColor` for group received messages

---

## Cross-Screen Navigation Map

```
MainNavigationScreen (Tab Index 1)
    └── ConversationsScreen
        ├── [Chats Tab] ─── tap ──→ EnhancedChatScreen
        │                              ├── _ChatInfoScreen
        │                              │    ├── MediaGalleryScreen
        │                              │    │    ├── PhotoViewerDialog
        │                              │    │    ├── VideoPlayerScreen
        │                              │    │    ├── LinkPreviewDialog
        │                              │    │    └── AudioPlayerDialog
        │                              │    └── _UserProfileSheet
        │                              ├── VoiceCallScreen
        │                              └── _ForwardMessageScreen
        │
        ├── [Groups Tab] ─── tap ──→ GroupChatScreen
        │                              ├── GroupInfoScreen
        │                              │    ├── GroupMediaGalleryScreen
        │                              │    │    ├── _showPhotoViewer (inline)
        │                              │    │    ├── VideoPlayerScreen
        │                              │    │    └── AudioPlayerDialog
        │                              │    └── EnhancedChatScreen (DM member)
        │                              ├── GroupAudioCallScreen
        │                              └── _ForwardMessageScreen
        │
        ├── [Calls Tab] ─── call ──→ VoiceCallScreen / GroupAudioCallScreen
        │
        ├── [person_add Chats] ──→ _NewMessageScreen ──→ EnhancedChatScreen
        └── [person_add Groups] ──→ CreateGroupScreen ──→ GroupChatScreen

Business (separate entry):
    BusinessConversationsScreen ──→ EnhancedChatScreen (isBusinessChat: true)
    BusinessMessagesTab ──→ EnhancedChatScreen (isBusinessChat: true)
```

---

## Firestore Collections Summary

| Collection | Screen(s) | Purpose |
|------------|-----------|---------|
| `conversations` | All chat screens | Conversations (1-on-1, group, business) |
| `conversations/{id}/messages` | EnhancedChat, GroupChat, MediaGallery | Message subcollection |
| `users/{uid}` | All screens | User profiles, online status |
| `users/{uid}/hiddenConversations` | ConversationsScreen | Hidden conversation IDs |
| `users/{uid}/blocked_users/{otherId}` | EnhancedChatScreen | Blocked users |
| `calls` | ConversationsScreen | Individual call records |
| `group_calls` | ConversationsScreen, GroupChat | Group call records |
| `connection_requests` | ConversationsScreen | Source tag migration |

---

## Common Styling Reference

| Element | Value |
|---------|-------|
| **Primary gradient** | `#404040` → `#000000` (top to bottom) |
| **AppBar gradient** | `#282828` → `#404040` (or `#66000000` → transparent) |
| **Glass card gradient** | white@25% → white@15% (topLeft to bottomRight) |
| **Glass card border** | white@30%, 1px, radius 16 |
| **Dialog background** | `rgb(32, 32, 32)` with white border |
| **Font family** | Poppins (throughout all screens) |
| **Unread badge** | `#25D366` (green) |
| **AI accent** | `#6366F1` (indigo) |
| **Business accent** | `#00D67D` (green) |
| **Mention (sent)** | `#00E5FF` (cyan) |
| **Mention (AI)** | `#818CF8` (light indigo) |
| **Active call** | `#00A884` (WhatsApp green) |
| **Reply accent** | `#E91E63` (pink) |
