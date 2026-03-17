# Drawer Module — Complete Screen Documentation

**App:** Single Tap
**Module:** App Drawer + Profile Menu Screens
**Total Screens:** 13 (1 drawer widget + 8 destination screens + 4 inline/sub-screens)
**Last Updated:** 17 Mar 2026

---

## Table of Contents

1. [App Drawer (Sidebar Menu)](#1-app-drawer-sidebar-menu)
2. [Downloads Screen](#2-downloads-screen)
3. [Notifications Screen](#3-notifications-screen)
4. [Library Screen](#4-library-screen)
5. [Profile Screen](#5-profile-screen)
6. [Upgrade Plan Screen](#6-upgrade-plan-screen)
7. [Personalization Screen](#7-personalization-screen)
8. [Settings Screen](#8-settings-screen)
9. [Help Center Screen](#9-help-center-screen)
10. [New Chat (Drawer Feature)](#10-new-chat-drawer-feature)
11. [My Posts Screen](#11-my-posts-screen)
12. [Chat History (Inline Feature)](#12-chat-history-inline-feature)
13. [Edit Profile Screen](#13-edit-profile-screen)

---

## 1. App Drawer (Sidebar Menu)

**File:** `lib/widgets/common widgets/app_drawer.dart`
**Class:** `AppDrawer` (StatefulWidget)
**Purpose:** Right-side end-drawer providing access to all app features. Contains feature cards (main menu), expandable chat history, and a bottom profile bar with a popup menu for profile/settings/help/logout.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `onNewChat` | `Future<void> Function()?` | No | `null` | Callback to save current conversation and start new chat |
| `onNavigate` | `Function(int)?` | No | `null` | Callback to navigate bottom tabs |
| `onLoadChat` | `Function(String chatId)?` | No | `null` | Callback to load a specific chat by ID |
| `onNewChatInProject` | `Function(String projectId)?` | No | `null` | Callback to create new chat within a project |

### Static Key

```dart
static final GlobalKey<AppDrawerState> globalKey = GlobalKey<AppDrawerState>();
```

### How It Opens

Opened as an `endDrawer` (right-side) via:
```dart
MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
```

### Drawer Container

| Property | Value |
|----------|-------|
| Width | 65% of screen width (`size.width * 0.65`) |
| Background | Transparent (gradient applied internally) |
| Position | Right-side (`endDrawer`), above bottom nav bar |
| Bottom margin | `MediaQuery.of(context).padding.bottom + 70` |

### Overall Layout

```
┌──────────────────────────┐
│  [Avatar] Name       [X] │  ← Header
│          email@mail.com  │
├──────────────────────────┤  ← White 0.5px border
│  ✏️  New Chat         >  │
│  🖼  Downloads        >  │
│  🔔  Notification  3  >  │  ← Unread badge (StreamBuilder)
│  📄  My Posts         >  │
│  🔗  Networking Prof. >  │
│  📁  Library          >  │
│  💬  Chat History     ⌄  │  ← Expandable
│    ┌────────────────┐    │
│    │ 📌 Chat 1  ··· │    │  ← Pinned chats first
│    │    Chat 2   ··· │    │
│    │    Chat 3   ··· │    │
│    │  Show more      │    │  ← If >10 chats
│    └────────────────┘    │
├──────────────────────────┤  ← White 0.5px border
│  [Avatar] Name     ⚙️   │  ← Bottom profile button
└──────────────────────────┘

When ⚙️ tapped:
┌──────────────────────────┐
│  👤  Profile          >  │
│  👑  Upgrade Plan     >  │
│  🎛  Personalization  >  │
│  ⚙  Settings         >  │
│  ❓  Help             >  │
│  🚪  Log out            │  ← Red text
└──────────────────────────┘
```

### Background Gradient

```
Gradient: RGBA(64, 64, 64, 1) (top) → RGBA(0, 0, 0, 1) (bottom)
```

### Right Border

| Property | Value |
|----------|-------|
| Color | White |
| Width | 0.5px |
| Side | Right only |

### Header (`_buildHeader`)

| Property | Value |
|----------|-------|
| Padding | fromLTRB(16, 50, 16, 12) |
| Background gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |

### Header — Avatar

| Property | Value |
|----------|-------|
| Size | 46 × 46 |
| Shape | Circle |
| Border | `Colors.white38`, width 2 |
| Image | `CachedNetworkImage` from `photoUrl` |
| Fallback | Purple circle (alpha 0.5) with white initial letter, Poppins 16px bold |

### Header — User Info

| Element | Style |
|---------|-------|
| Name | Poppins, 16px, w600, white, maxLines: 1, ellipsis |
| Email | Poppins, 12px, normal, white 60% opacity, maxLines: 1, ellipsis |
| Gap (name → email) | 2 |

### Header — Close Button

| Property | Value |
|----------|-------|
| Icon | `close_rounded`, size 20, white |
| Container bg | `Colors.white` alpha 0.1 |
| Border radius | 16 |
| Padding | 8 |
| Haptic | `lightImpact` |

### Feature Card (`_buildFeatureCard`)

| Property | Value |
|----------|-------|
| Margin | horizontal: 12, vertical: 2 |
| Padding | vertical: 5, horizontal: 12 |
| Background gradient | `Colors.white` alpha 0.25 (topLeft) → alpha 0.15 (bottomRight) |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |

### Feature Card — Icon Container

| Property | Value |
|----------|-------|
| Padding | 8 |
| Background | `Colors.white` alpha 0.15 |
| Shape | Circle |
| Icon size | 20, color: white |

### Feature Card — Label

| Property | Value |
|----------|-------|
| Font | Poppins, 15px, w500, white |
| Gap (icon → label) | 14 (SizedBox) |

### Feature Card — Chevron

| Property | Value |
|----------|-------|
| Icon | `chevron_right`, size 20 |
| Color | `Colors.white` alpha 0.3 |
| Position | Right (Spacer before) |

### Feature Card — Notification Badge

| Property | Value |
|----------|-------|
| Background | `Colors.red` |
| Border radius | 10 |
| Padding | horizontal: 7, vertical: 2 |
| Text | Poppins, 11px, w600, white |
| Max display | `99+` |
| Data source | StreamBuilder on `notifications` where `read == false` |

### Menu Items (Feature Cards)

| # | Label | Icon | Color | Target Screen |
|---|-------|------|-------|---------------|
| 1 | New Chat | `edit_outlined` | Blue | Callback (`onNewChat`) |
| 2 | Downloads | `image_outlined` | Purple | `DownloadsScreen` |
| 3 | Notification | `notifications_outlined` | Amber | `NotificationsScreen` |
| 4 | My Posts | `article_outlined` | TealAccent | `ApiMyPostsScreen` |
| 5 | Networking Profile | `hub_outlined` | `#016CFF` | `NetworkingProfilesPageScreen` |
| 6 | Library | `folder_outlined` | Orange | `LibraryScreen` |
| 7 | Chat History | `chat_bubble_outline` | Green | Expandable (inline) |

### Expandable Feature Card (`_buildExpandableFeatureCard`)

| Property | Value |
|----------|-------|
| Margin | horizontal: 12, vertical: 4 |
| Border (expanded) | Color with alpha 0.5 |
| Border (collapsed) | `Colors.white` alpha 0.3 |
| Chevron rotation | AnimatedRotation, 0.25 turns when expanded, 200ms duration |

### Chat History (Expanded Content)

| Property | Value |
|----------|-------|
| Container margin | left: 12, right: 12, top: 2, bottom: 4 |
| Background gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |
| Max items (collapsed) | 10 (+ "Show more" button) |
| Max items (total) | 20 |
| Data source | `chat_history` collection, filtered by `userId`, limit 50 |
| Sort | Pinned first, then by `createdAt` desc |
| Excludes | Archived chats, project chats |

### Chat Item (`_buildChatItem`)

| Property | Value |
|----------|-------|
| Margin | horizontal: 4 |
| Padding | left: 12, top: 4, bottom: 4, right: 2 |
| Unread bg | `Colors.white` alpha 0.05 |
| Border radius | 6 |
| Divider below | White alpha 0.12, height 0.5, horizontal margin 12 |

### Chat Item — Text

| Element | Style |
|---------|-------|
| Name (normal) | Poppins, 14px, normal, white 85% opacity |
| Name (unread) | Poppins, 14px, w600, white 85% opacity |
| Pin icon | `push_pin`, size 12, white 40% opacity |
| Unread dot | 6×6, blue circle, right margin 4 |

### Chat Item — 3-Dot Menu

| Property | Value |
|----------|-------|
| Icon | `more_horiz`, size 16, white 50% opacity |
| Button size | 28×28 |
| Menu bg | `#2D2D2D` |
| Menu border radius | 12 |
| Actions | Share, Pin/Unpin, Delete |

### Show More Button

| Property | Value |
|----------|-------|
| Icon | `expand_more_rounded`, size 18, white 50% opacity |
| Text | Poppins 12px, white 50% opacity |
| Margin | horizontal: 12, vertical: 4 |
| Padding | vertical: 10 |

### Bottom Profile Button (`_buildProfileButton`)

| Property | Value |
|----------|-------|
| Padding | fromLTRB(16, 10, 16, 12) |
| Background gradient | `#282828` (bottom) → `#404040` (top) |
| Top border | White, 0.5px |

### Bottom Profile Button — Avatar

| Property | Value |
|----------|-------|
| Size | 36 × 36 |
| Shape | Circle |
| Background | Purple alpha 0.3 |
| Border | `Colors.white38`, width 1 |
| Tap action | Opens `ProfileWithHistoryScreen` |

### Bottom Profile Button — Name

| Property | Value |
|----------|-------|
| Font | Poppins, 14px, w500, white |
| Max lines | 1, ellipsis |

### Bottom Profile Button — Settings Icon

| Property | Value |
|----------|-------|
| Icon | `settings_outlined`, size 22, white70 |
| Tap action | Toggles profile menu popup |

### Profile Menu Popup (`_buildProfileMenuCard`)

| Property | Value |
|----------|-------|
| Position | left: 12, right: 12, bottom: 80 |
| Background gradient | `RGBA(50,50,50,1)` (top) → `RGBA(25,25,25,1)` (bottom) |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |
| Shadow | `Colors.black` alpha 0.5, blur 20, offset (0, -5) |
| Overlay | Transparent full-screen GestureDetector to dismiss |

### Profile Menu Items

| # | Label | Icon | Destructive | Target |
|---|-------|------|-------------|--------|
| 1 | Profile | `person_outline_rounded` | No | `ProfileWithHistoryScreen` |
| 2 | Upgrade Plan | `workspace_premium_outlined` | No | `UpgradePlanScreen` |
| 3 | Personalization | `tune_rounded` | No | `PersonalizationScreen` |
| 4 | Settings | `settings_outlined` | No | `SettingsScreen` |
| 5 | Help | `help_outline_rounded` | No | `HelpCenterScreen` |
| 6 | Log out | `logout_rounded` | Yes | `FirebaseAuth.signOut()` → `OnboardingScreen` |

### Profile Menu Item (`_buildProfileMenuItem`)

| Property | Value |
|----------|-------|
| Padding | horizontal: 16, vertical: 14 |
| Icon size | 22 |
| Icon color (normal) | White |
| Icon color (destructive) | Red alpha 0.9 |
| Label font | Poppins, 15px, w500 |
| Label color (normal) | White |
| Label color (destructive) | Red alpha 0.9 |
| Arrow icon | `chevron_right`, size 18, white alpha 0.3 |
| Divider | White alpha 0.08, height 0.5, margin horizontal 16 |

### Navigation Pattern

All drawer menu items follow the same flow:
1. Close drawer (`Navigator.pop(context)`)
2. Push target screen (`Navigator.push(...)`)
3. On return, re-open drawer: `.then((_) { MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer(); })`

---

## 2. Downloads Screen

**File:** `lib/screens/profile/downloads_screen.dart`
**Class:** `DownloadsScreen` (StatefulWidget)
**Purpose:** Displays files downloaded from chat conversations (filtered by `plink_` prefix), organized into 4 tabs. Supports multi-select with long-press for bulk deletion.

### Constructor Parameters

None.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]            Downloads            [Select All]  │  ← Select All only in select mode
├────────────────────────────────────────────────────┤
│   Images  │  Videos  │  Audio  │  Docs              │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | `RGBA(64, 64, 64, 1)` solid |
| Bottom border | White, 1px |
| Blur | BackdropFilter sigmaX: 15, sigmaY: 15 |
| Preferred height | `kToolbarHeight + 52` |
| Title (normal) | "Downloads", Poppins 20px bold white, centered |
| Title (select mode) | "{N} selected", Poppins 18px w600 white |
| Leading (normal) | `arrow_back_ios`, white |
| Leading (select mode) | `close`, white |
| Toolbar height | `kToolbarHeight - 6` |

### Tab Bar Styling

| Property | Value |
|----------|-------|
| Indicator color | White |
| Indicator weight | 2.5 |
| Indicator size | `TabBarIndicatorSize.label` |
| Label color (selected) | White |
| Label style (selected) | Poppins, 14px, w600 |
| Label color (unselected) | White 50% opacity |
| Label style (unselected) | Poppins, 14px, normal |
| Divider color | Transparent |

### Tabs

| Tab | Description |
|-----|-------------|
| Images | `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.heic`, `.heif` |
| Videos | `.mp4`, `.mov`, `.avi`, `.mkv` |
| Audio | `.m4a`, `.aac`, `.mp3`, `.wav`, `.ogg`, `.wma`, `.flac` |
| Docs | `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.txt`, `.csv` |

### Body Background

```
Gradient: RGBA(64, 64, 64, 1) (top) → RGBA(0, 0, 0, 1) (bottom)
```

### Data Source

Local device filesystem scan:
- **Android:** `/storage/emulated/0/Pictures/Plink/`
- **iOS:** App documents directory
- Filter: Only files with `plink_` prefix
- Sort: By modification date (newest first)

### Grid Layout

| Property | Value |
|----------|-------|
| Images/Videos columns | 3 |
| Audio/Docs columns | 2 |
| Cross axis spacing | 6 |
| Main axis spacing | 6 |
| Aspect ratio (images/videos) | 1.0 (square) |
| Aspect ratio (audio/docs) | 2.2 (wide) |
| Padding | 12 all sides |
| Physics | `BouncingScrollPhysics` with `AlwaysScrollableScrollPhysics` |

### Grid Item Styling

| Property | Value |
|----------|-------|
| Border radius | 10 (normal), 8 (selected) |
| Border (normal) | `Colors.white` alpha 0.1, width 0.5 |
| Border (selected) | Blue, width 2 |

### Selection Overlay

| Property | Value |
|----------|-------|
| Position | top: 4, right: 4 |
| Size | 24 × 24 |
| Shape | Circle |
| Background (selected) | Blue |
| Background (unselected) | Black alpha 0.4 |
| Border | White alpha 0.6, width 1.5 |
| Check icon | `check`, size 16, white |

### Image Tile

| Property | Value |
|----------|-------|
| Fit | `BoxFit.cover` |
| Cache width | 300 |
| Error widget | `broken_image_outlined`, size 28, white54, bg white alpha 0.05 |

### Video Tile

| Property | Value |
|----------|-------|
| Background | White alpha 0.05 |
| Camera icon | `videocam_rounded`, size 32, white54 |
| Play button | Circle, black alpha 0.5, `play_arrow_rounded` size 24 white |

### Audio Tile

| Property | Value |
|----------|-------|
| Background | White alpha 0.05 |
| Padding | horizontal: 12, vertical: 8 |
| Icon container | Circle, white alpha 0.1, `audiotrack_rounded` size 20 white70 |
| Filename | Poppins 12px w500 white70, maxLines 1 ellipsis |
| Date | Poppins 12px white60 |
| Play icon | `play_circle_filled_rounded`, size 28, white alpha 0.4 |

### Doc Tile

| Property | Value |
|----------|-------|
| Background | White alpha 0.05 |
| Padding | horizontal: 12, vertical: 8 |
| PDF icon | `picture_as_pdf_rounded`, redAccent, bg redAccent alpha 0.15 |
| Other icon | `description_rounded`, blueAccent, bg blueAccent alpha 0.15 |
| Filename | Poppins 12px w500 white70, maxLines 1 ellipsis |
| Info line | "EXT  •  dd/mm/yyyy", Poppins 12px white60 |

### Multi-Select Bottom Bar

| Property | Value |
|----------|-------|
| Background | `#1a1a2e` alpha 0.95 |
| Top border | White alpha 0.1 |
| Padding | horizontal: 16, vertical: 12 |
| Count text | Poppins 14px white70 |
| Delete button bg | Red alpha 0.8 |
| Delete button radius | 10 |

### Delete Confirmation Dialog

| Property | Value |
|----------|-------|
| Background | `#1a1a2e` |
| Border radius | 16 |
| Title font | Poppins, white |
| Cancel color | White |
| Delete color | Red |

### Full Screen Image Viewer

| Property | Value |
|----------|-------|
| Background | Black |
| AppBar | Transparent, elevation 0 |
| Close icon | `close`, white |
| Title | Filename, Poppins 14px white, ellipsis |
| Viewer | `InteractiveViewer`, minScale 0.5, maxScale 4.0 |

### Empty States

| Tab | Icon | Title | Subtitle |
|-----|------|-------|----------|
| Images | `image_outlined` | "No images yet" | "Images you save from\nchats will appear here" |
| Videos | `videocam_outlined` | "No videos yet" | "Videos you save from\nchats will appear here" |
| Audio | `audiotrack_outlined` | "No audio yet" | "Audio you save from\nchats will appear here" |
| Docs | `description_outlined` | "No documents yet" | "Documents & PDFs you save\nfrom chats will appear here" |

**Empty state styling:**
- Circle bg: `Colors.white` alpha 0.1
- Icon: size 48, white alpha 0.6
- Title: Poppins 18px w600 white70
- Subtitle: Poppins 14px white40, textAlign center

---

## 3. Notifications Screen

**File:** `lib/screens/home/notifications_screen.dart`
**Class:** `NotificationsScreen` (StatefulWidget)
**Purpose:** Displays real-time notifications from Firestore `notifications` collection, filtered by current user. Shows sender name (cached), time ago, body text, and screen label badges.

### Constructor Parameters

None.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]           Notifications                        │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Toolbar height | 56 |
| Background | Transparent |
| FlexibleSpace gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |
| Title | "Notifications", Poppins 17px bold white, centered |
| Leading | `arrow_back_ios_new_rounded`, size 20, white, left padding 12 |

### Body Background

```
Gradient: RGBA(64, 64, 64, 1) (top) → RGBA(0, 0, 0, 1) (bottom)
```

### Data Source

- StreamBuilder on `notifications` collection
- Filter: `userId == currentUser.uid`
- Limit: 50
- Client-side sort by `createdAt` desc (avoids composite index)
- Deduplicate by `doc.id`

### Notification Item

| Property | Value |
|----------|-------|
| Margin | bottom: 8 |
| Padding | horizontal: 12, vertical: 10 |
| Background (unread) | `Colors.white` alpha 0.12 |
| Background (read) | `Colors.white` alpha 0.05 |
| Border | White24, width 0.5 |
| Border radius | 14 |

### Notification Icon Container

| Property | Value |
|----------|-------|
| Padding | 8 |
| Background | Type-color alpha 0.15 |
| Border radius | 10 |
| Icon size | 18, white |

### Notification Type Colors & Icons

| Type | Icon | Color |
|------|------|-------|
| `connection_request` | `person_add_rounded` | Blue |
| `connection_accepted` | `people_rounded` | Green |
| `message` | `chat_bubble_rounded` | `#016CFF` |
| `post_match` | `auto_awesome_rounded` | Purple |
| `like` | `favorite_rounded` | Red |
| Default | `notifications_rounded` | `#007AFF` |

### Screen Label Badges

| Type | Label |
|------|-------|
| `connection_request` / `connection_accepted` | "Networking" |
| `message` | "Messages" |
| `post_match` / `like` | "Nearby" |
| Default | "General" |

**Badge styling:**
- Padding: horizontal 6, vertical 2
- Background: type-color alpha 0.15
- Border: type-color alpha 0.3, width 0.5
- Border radius: 4
- Text: Poppins 12px w600 white

### Notification Typography

| Element | Style |
|---------|-------|
| Sender name (unread) | Poppins, 14px, w600, white |
| Sender name (read) | Poppins, 14px, w500, white |
| Time | Poppins, 13px, white 75% opacity (timeago format) |
| Body | Poppins, 13px, white 75% opacity, maxLines 2 ellipsis |

### Sender Name Cache

- Map `_nameCache` stores `senderId → name`
- Fetched from `users` collection on first access
- Fallback: "Someone"

### Empty State

| Property | Value |
|----------|-------|
| Icon | `notifications_off_outlined`, size 72, white 30% opacity |
| Title | "No notifications yet", Poppins 18px w600 white50 |
| Subtitle | "Your notifications will appear here", Poppins 14px white35 |

---

## 4. Library Screen

**File:** `lib/screens/profile/library_screen.dart`
**Class:** `LibraryScreen` (StatefulWidget)
**Purpose:** Displays user's projects from `projects` Firestore collection. Allows loading chats and creating new chats within projects.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `onLoadChat` | `Function(String chatId)?` | No | `null` | Callback to load specific chat |
| `onNewChatInProject` | `Function(String projectId)?` | No | `null` | Callback to create new chat in project |

### Data Source

- `projects` collection, filter by `userId`, limit 50
- Deduplicate by `doc.id`
- Sort: newest first (by `createdAt`)

---

## 5. Profile Screen

**File:** `lib/screens/home/profile_with_history_screen.dart`
**Class:** `ProfileWithHistoryScreen` (ConsumerStatefulWidget)
**Purpose:** Displays user profile with photo, name, email, location, active status toggle, edit profile, account type, invite friends, and settings access. Uses real-time Firestore listener for profile updates.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]              Profile                           │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | `RGBA(64, 64, 64, 1)` |
| Blur | BackdropFilter sigmaX: 15, sigmaY: 15 |
| Bottom border | White, 1px |
| Title | "Profile", Poppins w600 white, centered |
| Leading | `arrow_back_ios`, white |

### Body Background

```
Gradient: RGBA(64, 64, 64, 1) (top) → RGBA(0, 0, 0, 1) (bottom)
```

### Profile Header Card

```
┌──────────────────────────────────┐
│                                  │
│         (Profile Photo)          │  ← UserAvatar, radius 60
│                                  │
│         User Name                │  ← Poppins 28px bold white
│    email@example.com             │  ← Poppins 14px white70
│    📍 City, Area Pincode         │  ← Poppins 16px white70
│                                  │
└──────────────────────────────────┘
```

### Profile Header Card Styling

| Property | Value |
|----------|-------|
| Margin | fromLTRB(16, 0, 16, 16) |
| Background gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3 |
| Border radius | 16 |
| Blur | BackdropFilter sigmaX: 10, sigmaY: 10 |
| Padding (inner) | 20 all |

### Profile Header Typography

| Element | Family | Size | Weight | Color | Align |
|---------|--------|------|--------|-------|-------|
| Name | Poppins | 28 | bold | white | center |
| Email | Poppins | 14 | normal | white 70% opacity | center |
| Location icon | `location_on_rounded` | 20 | — | white 70% opacity | — |
| Location text | Poppins | 16 | normal | white 70% opacity | center |

### Active Status Card

| Property | Value |
|----------|-------|
| Margin | fromLTRB(16, 0, 16, 8) |
| Background gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3 |
| Border radius | 12 |
| Padding | horizontal: 12, vertical: 8 |

### Active Status — Icon Container

| Property | Value (active) | Value (inactive) |
|----------|---------------|-----------------|
| Size | 40 × 40 | 40 × 40 |
| Background | `AppColors.iosGreen` alpha 0.2 | White alpha 0.15 |
| Border radius | 10 | 10 |

### Active Status — Toggle

- Updates `showOnlineStatus` and `isOnline` in Firestore
- Shows glassmorphism snackbar with visibility feedback

### Action Cards

| Card | Icon | Navigation |
|------|------|-----------|
| Edit Profile | `edit_outlined` | `ProfileEditScreen` |
| Account Type | `calendar_view_week_rounded` | Account type dialog (Personal/Business) |
| Invite Friends | `person_add_alt_1_rounded` | Share.share() with app link |
| Settings | `settings_outlined` | `SettingsScreen` |

### Action Card Styling

| Property | Value |
|----------|-------|
| Margin | fromLTRB(16, 0, 16, 8) |
| Background gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3 |
| Border radius | 12 |
| Icon container | 40×40, white alpha 0.15, border radius 10 |
| Icon size | 20, white |
| Title | Poppins 15px w600 white |
| Chevron | `chevron_right`, white alpha 0.3 |

### Account Type Dialog

| Property | Value |
|----------|-------|
| Background | `#2A2A2A` |
| Border | White24, 0.5px |
| Border radius | 16 |
| Title | "Account Type", Poppins w600 white |
| Options | Personal, Business |
| Selected border | `#007AFF`, 1.5px |
| Check icon | `check_circle`, `#007AFF` |

### Data Lifecycle

- Real-time `StreamSubscription` on `users/{uid}` document
- Optimization: Only calls `setState` when meaningful data changes (city, location, interests)
- Background location update on init (silent, non-blocking)

---

## 6. Upgrade Plan Screen

**File:** `lib/screens/profile/upgrade_plan_screen.dart`
**Class:** `UpgradePlanScreen` (StatefulWidget)
**Purpose:** Displays subscription plans in 2 tabs (Personal/Business). No actual payment integration — tapping Continue shows a snackbar with the selected plan.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]         Upgrade your plan                      │
├────────────────────────────────────────────────────┤
│          Personal    │    Business                   │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Transparent |
| FlexibleSpace gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |
| Title | "Upgrade your plan", Poppins 20px bold white, centered |
| Leading | `arrow_back_ios`, white |

### Tab Bar Styling

| Property | Value |
|----------|-------|
| Indicator size | `TabBarIndicatorSize.tab` |
| Indicator color | White |
| Indicator weight | 2 |
| Divider | Transparent |
| Label color (selected) | White |
| Label style (selected) | Poppins, 15px, w600 |
| Label color (unselected) | White 60% opacity |
| Label style (unselected) | Poppins, 15px, normal |

### Body Background

`AppBackground` with `showParticles: false`

### Personal Plans

| Plan | Price | Period | Badge |
|------|-------|--------|-------|
| Free | ₹0 | INR / month | — |
| Go | ₹399 | INR / month (incl. GST) | — |
| Plus | ₹1,999 | INR / month (incl. GST) | POPULAR |
| Pro | ₹19,900 | INR / month (incl. GST) | — |

### Business Plans

| Plan | Price | Period | Badge |
|------|-------|--------|-------|
| Free | ₹0 | INR / month | — |
| Business | ₹2,599 | INR / month (excl. GST) | POPULAR |

### Plan Card Styling

| Property | Value (normal) | Value (selected) |
|----------|---------------|-----------------|
| Background gradient | `Colors.white` 0.25 → 0.15 | `#6366f1` 0.25 → 0.15 |
| Border color | `Colors.white` alpha 0.3 | `#6366f1` alpha 0.5 |
| Border width | 1 | 1 |
| Border radius | 16 | 16 |
| Padding | 20 all | 20 all |

### Plan Card Typography

| Element | Family | Size | Weight | Color |
|---------|--------|------|--------|-------|
| Button text | Poppins | 15 | w500 | white 90% opacity |
| Currency (₹) | Poppins | 16 | normal | white70 |
| Price | Poppins | 36 | bold | white |
| Period | Poppins | 12 | normal | white 50% opacity |
| Description | Poppins | 14 | normal | white 70% opacity |
| Feature icon | — | 18 | — | white 50% opacity |
| Feature text | Poppins | 14 | normal | white 70% opacity |
| Footer text | Poppins | 11 | normal | white 40% opacity |

### Popular Badge

| Property | Value |
|----------|-------|
| Background | `RGBA(99,213,241)` alpha 0.2 |
| Border radius | 12 |
| Padding | horizontal: 12, vertical: 4 |
| Text | "POPULAR", Poppins 10px bold, `RGBA(193,193,218)` |

### Continue Button

| Property | Value (active) | Value (inactive) |
|----------|---------------|-----------------|
| Background | `#007AFF` | White alpha 0.1 |
| Text color | White | White 40% opacity |
| Text | "Continue", Poppins 16px w600 |
| Width | Full |
| Padding | vertical: 16 |
| Border radius | 16 |
| Margin | 16 all |

---

## 7. Personalization Screen

**File:** `lib/screens/profile/personalization_screen.dart`
**Class:** `PersonalizationScreen` (StatefulWidget)
**Purpose:** Data control, security, and account management. 3 tabs with toggle settings, destructive actions (delete chat history, clear memory, deactivate/delete account), and navigation to sub-screens.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]         Personalization                        │
├────────────────────────────────────────────────────┤
│   Data Control  │  Security  │  Account             │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Transparent |
| FlexibleSpace gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |
| Title | "Personalization", Poppins 20px bold white, centered |

### Tab Bar Styling

Same as Upgrade Plan Screen (Poppins 15px, white indicator, weight 2).

### Body Background

`AppBackground` with `showParticles: false`, `overlayOpacity: 0.7`

### Data Control Tab

**Data Management Section:**
| Item | Icon | Action | Destructive |
|------|------|--------|-------------|
| Export your data | `download_outlined` | Coming Soon dialog | No |
| Delete chat history | `delete_outline` | Deletes all `chat_history` for user | Yes |
| Clear memory | `memory_outlined` | Clears app cache directory | No |

**Privacy Section:**
| Toggle | Icon | Default | Firestore Key |
|--------|------|---------|---------------|
| Improve AI for everyone | `visibility_outlined` | true | `improveAI` |
| Save chat history | `history_outlined` | true | `saveChatHistory` |
| Third-party integrations | `link_outlined` | false | `thirdPartyIntegrations` |

### Security Tab

| Item | Icon | Action | Destructive |
|------|------|--------|-------------|
| Change password | `lock_outline` | `ChangePasswordScreen` | No |
| Active sessions | `devices_outlined` | Coming Soon dialog | No |
| Log out all devices | `logout` | `AuthService.logoutFromOtherDevices()` | Yes |
| Login history | `history_outlined` | Coming Soon dialog | No |

### Account Tab

| Item | Icon | Action | Destructive |
|------|------|--------|-------------|
| Edit profile | `person_outline` | `ProfileEditScreen` | No |
| Deactivate account | `pause_circle_outline` | Sets `accountStatus: deactivated`, signs out | Yes |
| Delete account | `delete_forever_outlined` | Double confirmation (typed "DELETE"), deletes user/posts/chat/auth | Yes |

### Setting Item Card Styling

| Property | Value |
|----------|-------|
| Margin | bottom: 8 |
| Padding | horizontal: 12, vertical: 14 |
| Background gradient | `Colors.white` 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |

### Setting Item — Icon Container

| Property | Value (normal) | Value (destructive) |
|----------|---------------|-------------------|
| Padding | 10 | 10 |
| Background | White alpha 0.15 | Red alpha 0.2 |
| Border radius | 10 | 10 |
| Icon color | White | Red |
| Icon size | 20 | 20 |

### Setting Item — Typography

| Element | Style (normal) | Style (destructive) |
|---------|---------------|-------------------|
| Title | Poppins 15px w500 white90 | Poppins 15px w500 red |
| Subtitle | Poppins 14px white70 | Poppins 14px white70 |
| Chevron | `chevron_right`, size 20, white50 | same |

### Toggle Item — Switch

| Property | Value |
|----------|-------|
| Active thumb | `#6366f1` |
| Active track | `#6366f1` alpha 0.5 |
| Inactive thumb | Grey |
| Inactive track | Grey alpha 0.3 |

### Section Header

| Property | Value |
|----------|-------|
| Font | Poppins, 18px, bold, white |

### Confirmation Dialogs

| Property | Value |
|----------|-------|
| Background | `#1C1C1E` |
| Border | `Colors.white` alpha 0.3 |
| Border radius | 20 |
| Title font | Poppins, white |
| Content font | Poppins, white70 |
| Cancel color | White70 |
| Destructive color | Red |
| Special input border | Red (for DELETE confirmation) |

### Loading Overlay

| Property | Value |
|----------|-------|
| Background | Black alpha 0.5 |
| Indicator | `CircularProgressIndicator`, color `#6366f1` |

---

## 8. Settings Screen

**File:** `lib/screens/profile/settings_screen.dart`
**Class:** `SettingsScreen` (ConsumerStatefulWidget, Riverpod)
**Purpose:** Comprehensive settings with sections for Account, Notifications, App Settings, Coming Soon features, and Support. Uses Riverpod for state management.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]             Settings                           │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Transparent |
| FlexibleSpace gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |
| Title | "Settings", Poppins 24px bold white, centered |
| Leading | `arrow_back_ios`, white |

### Body Background

`AppBackground` with `showParticles: false`, `overlayOpacity: 0.7`

### Content Padding

```dart
EdgeInsets.only(top: kToolbarHeight + 40, left: 16, right: 16, bottom: 16)
```

### Account Section

| Icon | Color | Header |
|------|-------|--------|
| `CupertinoIcons.person_circle_fill` | `AppColors.iosBlue` | "Account" |

| Item | Type | Description |
|------|------|-------------|
| Discoverable on Live Connect | Switch | Toggle `discoveryModeEnabled` |
| Privacy | Navigation | → `PersonalizationScreen` |
| Security | Navigation | → Security options sheet |
| Blocked Users | Navigation | → Blocked users screen |

### Notifications Section

| Icon | Color | Header |
|------|-------|--------|
| `CupertinoIcons.bell_fill` | `AppColors.iosOrange` | "Notifications" |

| Item | Firestore Key | Default |
|------|---------------|---------|
| Message Notifications | `messageNotifications` | true |
| Match Notifications | `matchNotifications` | true |
| Connection Requests | `connectionRequestNotifications` | true |
| Promotional | `promotionalNotifications` | false |

### App Settings Section

| Icon | Color | Header |
|------|-------|--------|
| `CupertinoIcons.gear_solid` | `AppColors.iosGreen` | "App Settings" |

| Item | Navigation Target |
|------|------------------|
| Location | `LocationSettingsScreen` |
| Storage & Data | Storage options dialog |
| Clear Cache | Clear cache dialog |
| Performance Debug | `PerformanceDebugScreen` |

### Coming Soon Section

| Icon | Color | Header |
|------|-------|--------|
| `CupertinoIcons.sparkles` | `AppColors.iosPink` | "Coming Soon" |

| Feature | Icon | Description |
|---------|------|-------------|
| Premium | `workspace_premium` | Unlock exclusive features |
| Events | `event` | Discover local events |
| Groups | `groups` | Join interest-based groups |
| Stories | `auto_stories` | Share your moments |

### Support Section

| Icon | Color | Header |
|------|-------|--------|
| `CupertinoIcons.question_circle_fill` | `AppColors.iosTeal` | "Support" |

| Item | Navigation Target |
|------|------------------|
| Safety Tips | `SafetyTipsScreen` |
| About | About dialog (version 1.0.0) |
| Terms of Service | `TermsOfServiceScreen` |
| Privacy Policy | `PrivacyPolicyScreen` |
| Send Feedback | Feedback dialog |
| Report a Problem | Report problem dialog |

### Section Header Styling

| Property | Value |
|----------|-------|
| Icon container | 32×32, color alpha 0.2, border radius 8 |
| Icon size | 18 |
| Title | Poppins, 20px, bold, white |
| Gap (icon → title) | 12 |

### Individual Item Card Styling

| Property | Value |
|----------|-------|
| Margin | bottom: 8 |
| Background gradient | `Colors.white` 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |
| Icon container | padding 10, white alpha 0.15, border radius 10 |
| Icon size | 20, white |
| Title | Poppins 15px w500 white90 |
| Subtitle | Poppins 14px white70 |
| Trailing | `CupertinoIcons.chevron_forward`, white50 |

### Switch Item Card Styling

Same card styling as Individual Item, but with `SwitchListTile` instead of `ListTile`.

### Coming Soon Badge

Gradient badge with "COMING SOON" text, shimmer-like appearance.

---

## 9. Help Center Screen

**File:** `lib/screens/profile/help_center_screen.dart`
**Class:** `HelpCenterScreen` (StatefulWidget)
**Purpose:** Static FAQ screen with 6 expandable categories. No API calls — all content is hardcoded.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]           Help Center                          │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Transparent |
| FlexibleSpace gradient | `#282828` (top) → `#404040` (bottom) |
| Bottom border | White, 0.5px |
| Title | "Help Center", Poppins bold white, centered |
| Leading | `arrow_back_ios`, white |

### Body Background

`AppBackground` with `showParticles: false`

### Content Padding

```dart
EdgeInsets.only(top: kToolbarHeight + 44, left: 16, right: 16, bottom: 16)
```

### FAQ Categories

| # | Category | Icon | Color |
|---|----------|------|-------|
| 1 | Getting Started | `rocket_launch` | Blue |
| 2 | Account & Profile | `person_outline` | Purple |
| 3 | Connections & Messaging | `chat_bubble_outline` | Green |
| 4 | Live Connect | `people_outline` | Orange |
| 5 | Privacy & Safety | `shield_outlined` | Red |
| 6 | Troubleshooting | `build_outlined` | Teal |

### Category Header

| Property | Value |
|----------|-------|
| Icon container | padding 10, white alpha 0.15, border radius 10 |
| Icon size | 20, white |
| Title | Poppins, 18px, bold, white |
| Gap (icon → title) | 12 |
| Padding | top: 4, bottom: 6 |

### FAQ Item (Expandable)

| Property | Value |
|----------|-------|
| Margin | bottom: 6 |
| Background gradient | `Colors.white` 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |

### FAQ Item — Question

| Property | Value |
|----------|-------|
| Padding | 16 all |
| Text | Poppins, 15px, w500, white 90% opacity |
| Chevron (collapsed) | `keyboard_arrow_down`, white 50% opacity |
| Chevron (expanded) | `keyboard_arrow_up`, white 50% opacity |

### FAQ Item — Answer (shown on expand)

| Property | Value |
|----------|-------|
| Padding | fromLTRB(16, 0, 16, 16) |
| Text | Poppins, 14px, normal, white 70% opacity, height 1.5 |

### FAQ Content (3 per category)

**Getting Started:**
1. What is Single Tap?
2. How do I create a post?
3. How does matching work?

**Account & Profile:**
1. How do I edit my profile?
2. How do I switch to a Business account?
3. How do I delete my account?

**Connections & Messaging:**
1. How do I connect with someone?
2. Can I make voice calls?
3. How do I block someone?

**Live Connect:**
1. What is Live Connect?
2. How do I appear on Live Connect?
3. Why can't I see anyone nearby?

**Privacy & Safety:**
1. Is my location shared with others?
2. How do I report inappropriate behavior?
3. Are my messages encrypted?

**Troubleshooting:**
1. The app is running slowly
2. I'm not receiving notifications
3. Voice calls aren't connecting

---

## 10. New Chat (Drawer Feature)

**File:** `lib/widgets/common widgets/app_drawer.dart`
**Class:** `AppDrawer` (handled within drawer widget)
**Purpose:** First feature card in the drawer. Saves the current home-screen AI conversation to Firestore, refreshes the chat history list, then closes the drawer so the user lands on a fresh chat.

### Trigger

Feature card in drawer with blue icon (`Icons.edit_outlined`):
```dart
_buildFeatureCard(
  icon: Icons.edit_outlined,
  label: 'New Chat',
  color: Colors.blue,
  onTap: () async {
    HapticFeedback.mediumImpact();
    await widget.onNewChat?.call();
    await _loadRecentChats();
    if (context.mounted) Navigator.pop(context);
  },
)
```

### Visual Styling

| Property | Value |
|----------|-------|
| Icon | `Icons.edit_outlined` |
| Icon Color | `Colors.blue` |
| Card Margin | horizontal 12, vertical 2 |
| Card Padding | vertical 5, horizontal 12 |
| Card Gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border Radius | 16 |
| Label Font | Poppins, 14px, w500, white 90% opacity |

### Behavior Flow

1. User taps "New Chat" card
2. `HapticFeedback.mediumImpact()` fires
3. `widget.onNewChat?.call()` is awaited — this saves the current conversation in the home screen to `chat_history` collection
4. `_loadRecentChats()` refreshes the chat history list in the drawer
5. Drawer closes via `Navigator.pop(context)`
6. User is back on the home screen with a fresh empty chat

### Layout Diagram

```
┌─────────────────────────────────────┐
│  🔵  ✏️  New Chat                    │
│       (blue icon, glassmorphism)    │
└─────────────────────────────────────┘
```

---

## 11. My Posts Screen

**File:** `lib/screens/home/api_my_posts_screen.dart`
**Class:** `ApiMyPostsScreen` (StatefulWidget)
**Lines:** ~1527
**Purpose:** Displays the current user's post listings in a tabbed interface with 3 tabs: My Posts (active), Saved, and Deleted. Each tab shows posts in a 2-column grid with floating card animations. Supports soft-delete, permanent delete, restore, unsave, and auto-delete of 30-day-old deleted posts.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard widget key |

### State Variables

| Variable | Type | Description |
|----------|------|-------------|
| `_tabController` | `TabController` | 3 tabs: My Posts, Saved, Deleted |
| `_currentUserName` | `String` | Logged-in user's display name |
| `_currentUserPhoto` | `String?` | Logged-in user's photo URL |
| `_isAutoDeleting` | `bool` | Prevents duplicate auto-delete operations |

### Layout Diagram

```
┌──────────────────────────────────────────┐
│  ←  My Post Listings                     │
│  ─────────────────────────────────────── │
│  [ My Posts ] [ Saved ] [ Deleted ]      │
│  ─────────────────────────────────────── │
│                                          │
│  ┌──────────┐  ┌──────────┐             │
│  │  Image   │  │  Image   │             │
│  │          │  │          │             │
│  │ ┌──────┐ │  │ ┌──────┐ │             │
│  │ │Title │ │  │ │Title │ │             │
│  │ │Brand │ │  │ │Brand │ │             │
│  │ │₹Price│ │  │ │₹Price│ │             │
│  │ └──────┘ │  │ └──────┘ │             │
│  └──────────┘  └──────────┘             │
│                                          │
│  ┌──────────┐  ┌──────────┐             │
│  │  Image   │  │  Image   │             │
│  │          │  │          │             │
│  │ ┌──────┐ │  │ ┌──────┐ │             │
│  │ │Title │ │  │ │Title │ │             │
│  │ │Brand │ │  │ │Brand │ │             │
│  │ │₹Price│ │  │ │₹Price│ │             │
│  │ └──────┘ │  │ └──────┘ │             │
│  └──────────┘  └──────────┘             │
└──────────────────────────────────────────┘
```

### AppBar Styling

| Property | Value |
|----------|-------|
| Title | "My Post Listings", Poppins 18px w700 white |
| Back Icon | `arrow_back_ios_new_rounded`, size 18, white |
| Background | Transparent |
| FlexibleSpace Gradient | `Colors.black` alpha 0.4 → 0.2 → transparent |
| TabBar Indicator | White, weight 1, tab-size indicator |
| TabBar Label | Poppins 13px w600 white |
| TabBar Unselected | Poppins 13px normal, white 60% opacity |
| Tab Names | "My Posts", "Saved", "Deleted" |
| Divider below tabs | White, height 0.5 |

### Body Styling

| Property | Value |
|----------|-------|
| Background Gradient | `#404040` → `#000000` |
| Grid Columns | 2 |
| Grid Padding | fromLTRB(15, 12, 15, 90) |
| Cross-axis Spacing | 12 |
| Main-axis Spacing | 12 |
| Child Aspect Ratio | 0.85 |
| Scroll Physics | BouncingScrollPhysics |

### Floating Card Animation

Each post card is wrapped in `_FloatingCard` — an animated widget that:
- Uses `SingleTickerProviderStateMixin`
- Duration: `1600 + (index % 6) * 220` ms per card (staggered)
- Oscillates vertically between -6.0 and +6.0 px
- Curve: `Curves.easeInOut`, repeats in reverse

### Post Card Styling

| Property | Value |
|----------|-------|
| Border Radius | 20 (outer), 18.5 (ClipRRect inner) |
| Border | `Colors.white` alpha 0.25, width 1.5 |
| Box Shadow | black alpha 0.4, blur 8, offset (0, 4) |
| Bottom Gradient | transparent → black alpha 0.1 → 0.80 (stops 0.35, 0.6, 1.0) |
| Bottom Info Bar | Glassmorphism — blur(12, 12), black alpha 0.55, radius 14, border white alpha 0.15 |
| Title Font | Poppins, 13px, w700, white |
| Sub-category Font | Poppins, 11px, normal, white 85% opacity |
| Price Font | Poppins, 13px, w700, color `#00D67D` (green) |
| Price Format | `₹` prefix, comma-separated |

### Top-Right Action Buttons

| Tab | Icon | Action |
|-----|------|--------|
| My Posts | `delete_outline_rounded` | Soft delete (moves to Deleted tab) |
| Saved | `bookmark_rounded` | Unsave (removes from saved_posts) |
| Deleted | `restore_rounded` + `delete_forever_rounded` | Restore or permanently delete |

Button styling: `#016CFF` alpha 0.85 background, white icon (15px), circle shape with blur(8, 8), white alpha 0.4 border.

### Badges

- **Remaining Days** (Deleted tab): Shows "X days left" in red badge when ≤7 days, dark bg otherwise. Timer icon + text, Poppins 10px w600.
- **Donation Badge**: Orange alpha 0.9 background, "Donation" text, Poppins 10px w700.

### Dialogs

**Soft Delete Dialog:**
- Gradient: `#404040` → `#0F0F0F`
- Icon: `delete_outline_rounded` in red alpha 0.15 circle
- Title: "Delete Post?" Poppins 17px bold
- Body: Explains 30-day retention
- Buttons: Cancel (glass) + Delete (AppColors.error)

**Restore Dialog:**
- Same style, green accent (`AppColors.success`)
- Title: "Restore Post?"

**Permanent Delete Dialog:**
- Same style, red accent
- Title: "Delete Permanently?"
- Warning: "This action cannot be undone"

### Firestore Queries

| Tab | Collection | Query |
|-----|------------|-------|
| My Posts | `posts` | `where('userId', ==)` + `orderBy('createdAt', desc)` + `limit(50)` |
| Saved | `users/{uid}/saved_posts` | `orderBy('savedAt', desc)` + `limit(50)` |
| Deleted | `posts` | `where('userId', ==)` + `orderBy('createdAt', desc)` + `limit(100)` |

- My Posts tab: Client-side filters `isActive != false`
- Deleted tab: Client-side filters `isActive == false`, auto-deletes posts older than 30 days
- All tabs: Client-side deduplication via `Set<String>` on doc IDs

### Navigation

Tapping a post card navigates via custom `_ExpandRoute` (slide-in from left):
```dart
Navigator.push(context, _ExpandRoute(
  builder: (_) => ApiListingDetailScreen(
    postId: postId,
    post: post,
    isDeleted: cardType == _CardType.deleted,
    showCallButton: false,
  ),
));
```

Transition: 500ms forward, 400ms reverse, `easeOutQuart` / `easeInQuart` curves, fade from 0.5.

### Empty State

- Icon in glass circle (icon color white54, size 64)
- Title: `AppTextStyles.titleLarge`, white
- Subtitle: `AppTextStyles.bodyMedium`, white60

---

## 12. Chat History (Inline Feature)

**File:** `lib/widgets/common widgets/app_drawer.dart`
**Class:** `AppDrawer` (handled within drawer widget)
**Purpose:** Expandable section inside the drawer that shows recent AI chat conversations from the `chat_history` Firestore collection. Users can tap to load a chat, pin/unpin chats, share, or delete them.

### Trigger

Expandable feature card in drawer with green icon (`Icons.chat_bubble_outline`):
```dart
_buildExpandableFeatureCard(
  icon: Icons.chat_bubble_outline,
  label: 'Chat History',
  color: Colors.green,
  isExpanded: _showChatHistory,
  onTap: () {
    HapticFeedback.lightImpact();
    setState(() => _showChatHistory = !_showChatHistory);
  },
)
```

### Visual Styling — Expandable Card

| Property | Value |
|----------|-------|
| Icon | `Icons.chat_bubble_outline` |
| Icon Color | `Colors.green` |
| Card Margin | horizontal 12, vertical 2 |
| Card Padding | vertical 5, horizontal 12 |
| Card Gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border Radius | 16 |
| Label Font | Poppins, 14px, w500, white 90% opacity |
| Expand Indicator | `keyboard_arrow_down` / `keyboard_arrow_up`, white 50% opacity |

### Chat List Container Styling

| Property | Value |
|----------|-------|
| Margin | left 12, right 12, top 2, bottom 4 |
| Gradient | `Colors.white` alpha 0.25 → 0.15 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border Radius | 16 |
| Empty Text | "No chats yet", Poppins 14px, white 50% opacity |

### Chat Item Styling

| Property | Value |
|----------|-------|
| Margin | horizontal 4 |
| Padding | left 12, top 4, bottom 4, right 2 |
| Background (unread) | `Colors.white` alpha 0.05 |
| Background (read) | Transparent |
| Border Radius | 6 |
| Chat Name Font | Poppins, 14px, white 85% opacity |
| Chat Name (unread) | FontWeight.w600 |
| Chat Name (read) | FontWeight.normal |
| Unread Dot | Blue, 6px circle, margin-right 4 |
| Pin Icon | `Icons.push_pin`, white alpha 0.4, size 12 |
| Divider | White alpha 0.12, height 0.5, margin horizontal 12 |

### Data Loading

Loads from `chat_history` collection:
```dart
_firestore
  .collection('chat_history')
  .where('userId', isEqualTo: user.uid)
  .limit(50)
  .get();
```

- Filters out archived chats (`isArchived == true`)
- Filters out project chats (`projectId != null`, shown in Library instead)
- Deduplicates by document ID
- Sorts: pinned chats first, then by `createdAt` (newest first)
- Limits display to first 20 chats
- Shows first 10 initially; "Show more" button reveals all 20

### Chat Item Context Menu

3-dot menu (`Icons.more_horiz`) as `PopupMenuButton`:

| Action | Icon | Description |
|--------|------|-------------|
| Share | `share_outlined` | Exports chat messages as text via `share_plus` |
| Pin/Unpin | `push_pin_outlined` / `push_pin` | Toggles `isPinned` field in Firestore |
| Delete | `delete_outline` | Shows confirmation, then deletes from `chat_history` |

Menu styling: `#2D2D2D` background, rounded corners (radius 12), items 44px height, Poppins 14px. Delete text is red.

### Show More Button

When there are >10 chats, shows at index 10:
- Text: "Show all X chats" or "Show less"
- Font: Poppins 13px w500, white 50% opacity
- Background: transparent

### Layout Diagram

```
┌──────────────────────────────────────┐
│  🟢 💬  Chat History        ▾       │ ← Expandable card
├──────────────────────────────────────┤
│  ┌──────────────────────────────────┐│
│  │ 📌 Pinned Chat Name    •••      ││ ← Pinned first
│  │ ──────────────────────────────── ││
│  │ Chat Name              •••      ││
│  │ ──────────────────────────────── ││
│  │ Chat Name         🔵   •••      ││ ← Unread dot
│  │ ──────────────────────────────── ││
│  │ ...                              ││
│  │ ──────────────────────────────── ││
│  │    Show all 15 chats             ││ ← Show more
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

---

## 13. Edit Profile Screen

**File:** `lib/screens/profile/profile_edit_screen.dart`
**Class:** `ProfileEditScreen` (StatefulWidget)
**Lines:** ~1044
**Purpose:** Full profile editing form accessible from the Profile screen ("Edit Profile" button). Allows users to update their name, phone number (with country code picker), bio, location (with auto-detect), gender, date of birth, occupation, and profile photo (camera or gallery).

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard widget key |

### State Variables

| Variable | Type | Description |
|----------|------|-------------|
| `_formKey` | `GlobalKey<FormState>` | Form validation key |
| `_nameController` | `TextEditingController` | User's display name |
| `_phoneController` | `TextEditingController` | Phone number (without country code) |
| `_locationController` | `TextEditingController` | City / location text |
| `_bioController` | `TextEditingController` | About me text (max 300 chars) |
| `_currentPhotoUrl` | `String?` | Current profile photo URL |
| `_selectedImage` | `File?` | Locally picked image (camera/gallery) |
| `_selectedGender` | `String?` | Selected gender option |
| `_selectedOccupation` | `String?` | Selected occupation |
| `_selectedDateOfBirth` | `DateTime?` | Picked date of birth |
| `_selectedCountryCode` | `String` | Default `'+91'` (India) |
| `_isLoading` | `bool` | Initial profile load state |
| `_isUpdating` | `bool` | Save/upload in progress |
| `_isUpdatingLocation` | `bool` | Location detect in progress |

### Services Used

| Service | Usage |
|---------|-------|
| `AuthService` | Get current user |
| `UserManager` | Load cached profile, update profile cache |
| `FirebaseFirestore` | Read/write to `users` collection |
| `FirebaseStorage` | Upload profile images to `profile_images/{uid}.jpg` |
| `ImagePicker` | Pick from gallery or take photo (quality 95, max 1920px) |
| `IpLocationService` | Auto-detect location from IP |

### Layout Diagram

```
┌──────────────────────────────────────────┐
│  ←  Edit Profile                         │
│  ─────────────────────────────────────── │
│                                          │
│     ┌────────────┐                       │
│     │            │                       │
│     │   Avatar   │  📷                   │
│     │  (120x120) │                       │
│     └────────────┘                       │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │ 👤  Name                         │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ ✉️  Email (read-only)            │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ 📞  +91 ▾ │ Phone Number         │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ ℹ️  About Me (max 300)           │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ 📍  Location              🎯     │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ 👤  Gender                 ▾     │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ 📅  Date of Birth                │    │
│  └──────────────────────────────────┘    │
│  ┌──────────────────────────────────┐    │
│  │ 💼  Occupation             ▾     │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │         Update Profile            │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘
```

### AppBar Styling

| Property | Value |
|----------|-------|
| Title | "Edit Profile", 20px bold white |
| Toolbar Height | 56 |
| Back Icon | `Icons.arrow_back_ios`, size 22, white |
| Background | Transparent |
| FlexibleSpace | Gradient `#282828` → `#404040`, bottom border white 0.5px |

### Body Styling

| Property | Value |
|----------|-------|
| Background Gradient | `#404040` → `#000000` |
| ScrollView Padding | 20 all |
| Spacing between fields | 16 (SizedBox) |

### Profile Image Section

| Property | Value |
|----------|-------|
| Container Width | Full width |
| Container Padding | vertical 24 |
| Container Border Radius | 16 |
| Container Border | `Colors.white` alpha 0.3, width 1 |
| Container Background | `Colors.white` alpha 0.15 |
| Avatar Size | 120 x 120, circle |
| Avatar Border | `Colors.white` alpha 0.3, width 2 |
| Camera Button | `AppColors.iosBlue` circle, camera_alt icon (20px white) |
| Camera Button Position | Bottom-right of avatar |

### Image Picker Options

Uses `SharedFormWidgets.showImagePickerDialog`:
- Pick from Gallery (quality 95, max 1920x1920)
- Take Photo (quality 95, max 1920x1920)
- Remove Photo (if existing photo)

### Input Field Styling (Glassmorphism)

All fields use `SharedFormWidgets.glassInputDecoration`:

| Property | Value |
|----------|-------|
| Fill Color | `Colors.white` alpha 0.15 |
| Border Radius | 16 |
| Enabled Border | `Colors.white` alpha 0.3, width 1 |
| Focused Border | `Colors.white` alpha 0.5, width 1.5 |
| Label Style | `Colors.grey[400]`, 14px |
| Floating Label | white70, 14px |
| Text Style | White, 16px |
| Hint Style | White alpha 0.35, 15px |
| Prefix Icon Color | `Colors.grey[400]`, size 22 |

### Form Fields

| Field | Type | Prefix Icon | Validation | Extra |
|-------|------|-------------|------------|-------|
| Name | TextFormField | `person_rounded` | Required | — |
| Email | TextFormField | `email_rounded` | — | Read-only, disabled, dimmed (50% opacity) |
| Phone | Custom Row | `phone_rounded` | — | Country code picker + digits only, max 15 |
| About Me | TextFormField | `info_outline_rounded` | — | Multiline, max 300 chars |
| Location | TextFormField | `location_on_rounded` | — | Auto-detect button (`my_location` icon) |
| Gender | GestureDetector | `person_outline_rounded` | — | Custom dropdown sheet |
| Date of Birth | GestureDetector | `calendar_today_rounded` | — | DatePicker dialog, dark theme |
| Occupation | GestureDetector | `work_outline_rounded` | — | Custom dropdown sheet |

### Country Code Picker

- 30 countries pre-loaded (India, USA, UK, Australia, UAE, etc.)
- Shows as bottom sheet (`CountryCodePickerSheet`)
- Default: `+91` (India)
- Divider between code and phone input: white alpha 0.2, 1px wide, 28px tall

### Date Picker Dialog

| Property | Value |
|----------|-------|
| Theme | Dark |
| Background | `#1a1a2e` |
| Primary Color | `AppColors.iosBlue` |
| Shape | Rounded, radius 16, white alpha 0.3 border |
| Cancel Button | White text, white alpha 0.3 border, radius 12 |
| Confirm Button | White text, `AppColors.iosBlue` background, radius 12 |
| Initial Date | Saved DOB or year 2000 |
| Date Range | 1950 – now |

### Update Button

| Property | Value |
|----------|-------|
| Width | Full width |
| Padding | vertical 16 |
| Background | `AppColors.iosBlue` |
| Border Radius | 16 |
| Text | "Update Profile", white 18px bold |
| Loading State | `CircularProgressIndicator` (strokeWidth 2, white, 20x20) |

### Save Flow

1. Validates form via `_formKey.currentState!.validate()`
2. Uploads new photo to Firebase Storage if `_selectedImage != null`
3. Updates Firebase Auth profile (displayName, photoURL)
4. Writes to Firestore `users/{uid}` with merge (name, email, photoUrl, phone, location, city, bio, occupation, gender, dateOfBirth, age, lastSeen, isOnline)
5. Updates `UserManager` cache
6. Shows success snackbar
7. Calls `Navigator.pop(context, true)` — returns `true` to signal profile was updated

---

## Screen Navigation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        APP DRAWER                            │
│                                                              │
│  Feature Cards:                                              │
│  ├── New Chat ───────→ (callback, stays on Home)             │
│  ├── Downloads ──────→ DownloadsScreen                       │
│  │                      └── FullScreenImageViewer            │
│  │                      └── VideoPlayerScreen                │
│  ├── Notification ───→ NotificationsScreen                   │
│  ├── My Posts ───────→ ApiMyPostsScreen                      │
│  ├── Networking ─────→ NetworkingProfilesPageScreen           │
│  ├── Library ────────→ LibraryScreen                         │
│  └── Chat History ───→ (expandable inline list)              │
│                                                              │
│  Profile Menu (⚙️):                                          │
│  ├── Profile ────────→ ProfileWithHistoryScreen               │
│  │                      ├── ProfileEditScreen                │
│  │                      └── SettingsScreen                   │
│  ├── Upgrade Plan ───→ UpgradePlanScreen                     │
│  ├── Personalization → PersonalizationScreen                 │
│  │                      ├── ChangePasswordScreen             │
│  │                      └── ProfileEditScreen                │
│  ├── Settings ───────→ SettingsScreen                        │
│  │                      ├── PersonalizationScreen            │
│  │                      ├── LocationSettingsScreen            │
│  │                      ├── PerformanceDebugScreen            │
│  │                      ├── TermsOfServiceScreen             │
│  │                      ├── PrivacyPolicyScreen              │
│  │                      └── SafetyTipsScreen                 │
│  ├── Help ───────────→ HelpCenterScreen                      │
│  └── Log out ────────→ OnboardingScreen (clears stack)       │
└─────────────────────────────────────────────────────────────┘
```

---

## Shared Design System

### Consistent Background Gradients

| Location | Start | End |
|----------|-------|-----|
| AppBar flexibleSpace | `#282828` (RGBA 40,40,40) | `#404040` (RGBA 64,64,64) |
| Body background | `#404040` (RGBA 64,64,64) | `#000000` (RGBA 0,0,0) |
| Drawer background | `#404040` (RGBA 64,64,64) | `#000000` (RGBA 0,0,0) |
| Profile Menu popup | `#323232` (RGBA 50,50,50) | `#191919` (RGBA 25,25,25) |

### Font Family

**Poppins** — used exclusively across all screens. No other font family is used.

### Glassmorphism Card Pattern

All screens use consistent glass-card styling:
- `LinearGradient` with `Colors.white` alpha 0.25 (topLeft) → 0.15 (bottomRight)
- Border: `Colors.white` alpha 0.3, width 1
- Border radius: 16
- Optional `BackdropFilter` with `ImageFilter.blur` (sigma 10–15)

### Icon Container Pattern

Reused across drawer, settings, personalization, help:
- Padding: 8–10
- Background: `Colors.white` alpha 0.15
- Shape: Circle (drawer) or rounded rect (settings/personalization, radius 10)
- Icon: size 20, white

### Accent Colors

| Name | Hex | Usage |
|------|-----|-------|
| Primary Blue | `#016CFF` | Message notifications, Networking Profile |
| iOS Blue | `#007AFF` | Continue button, notification default, bookmarks |
| Indigo | `#6366f1` | Toggle switches, plan selection, loading indicator |
| Material Blue | `#2196F3` | Domain badges |
| Error Red | `Colors.red` | Destructive actions, logout, delete |
| Success Green | `Colors.green` | Snackbar success, online status |

### Navigation Back Pattern

All screens from drawer follow this pattern:
```dart
onPressed: () {
  HapticFeedback.lightImpact();
  Navigator.pop(context);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
  });
}
```

### Haptic Feedback

- `lightImpact` — Standard taps, navigation, toggles
- `mediumImpact` — New chat, delete actions, long-press select

### Dependencies

| Package | Usage |
|---------|-------|
| `firebase_auth` | User authentication, sign out |
| `cloud_firestore` | All data (notifications, chat_history, projects, users) |
| `cached_network_image` | Avatar images in drawer and profile |
| `flutter_riverpod` | State management (Settings, Profile screens) |
| `share_plus` | Chat sharing, invite friends |
| `timeago` | Notification time formatting |
| `path_provider` | iOS downloads directory, cache clearing |
| `permission_handler` | Storage permission for downloads |

---

## File Structure

```
lib/widgets/common widgets/
└── app_drawer.dart                     ← Drawer widget (main menu + profile popup)

lib/screens/profile/
├── downloads_screen.dart               ← Screen 2: Downloaded chat media
├── library_screen.dart                 ← Screen 4: Projects / Library
├── upgrade_plan_screen.dart            ← Screen 6: Subscription plans
├── personalization_screen.dart         ← Screen 7: Data/Security/Account
├── settings_screen.dart                ← Screen 8: App settings
├── help_center_screen.dart             ← Screen 9: FAQ
├── profile_edit_screen.dart            ← Screen 13: Edit Profile form
├── terms_of_service_screen.dart        ← Sub-screen: Terms of Service
├── privacy_policy_screen.dart          ← Sub-screen: Privacy Policy
├── safety_tips_screen.dart             ← Sub-screen: Safety Tips
└── saved_posts_screen.dart             ← Sub-screen: Saved Posts

lib/screens/home/
├── notifications_screen.dart           ← Screen 3: Notifications
├── profile_with_history_screen.dart    ← Screen 5: User Profile
├── api_my_posts_screen.dart            ← Screen 11: My Posts (3 tabs)
└── main_navigation_screen.dart         ← Scaffold that hosts the drawer

lib/screens/login/
├── onboarding_screen.dart              ← Logout destination
├── change_password_screen.dart         ← From Personalization > Security
└── choose_account_type_screen.dart     ← From Settings > Account

lib/screens/location/
└── location_settings_screen.dart       ← From Settings > Location

lib/screens/networking/
└── networking_profiles_page_screen.dart ← From drawer > Networking Profile

lib/screens/
└── performance_debug_screen.dart       ← From Settings > Performance Debug
```
