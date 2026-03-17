# Nearby Module — Complete Screen Documentation

**App:** Single Tap
**Module:** Nearby / Marketplace
**Total Screens:** 3 (1 main feed + 1 saved posts + 1 post detail)
**Last Updated:** 16 Mar 2026

---

## Table of Contents

1. [NearBy Screen (Main Feed)](#1-nearby-screen-main-feed)
2. [Saved Nearby Screen](#2-saved-nearby-screen)
3. [NearBy Post Detail Screen](#3-nearby-post-detail-screen)

---

## 1. NearBy Screen (Main Feed)

**File:** `lib/screens/near by/near_by_screen.dart`
**Class:** `NearByScreen` (StatefulWidget)
**Purpose:** The primary marketplace feed. Displays posts from other users fetched via the `/nearby/feed` API, organized by category tabs (Products, Services). Provides search (text + voice), save/bookmark posts, and navigation to post detail screen.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `onBack` | `VoidCallback?` | No | `null` | Callback when user taps back |
| `isVisible` | `bool` | No | `false` | Controls lazy-loading — API is only called when `true` |

### Static Cache

```dart
static Map<String, List<Map<String, dynamic>>> _cachedPostsByTab = {};
static double? _cachedLat;
static double? _cachedLng;
static bool _hasEverLoaded = false;
```

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│                     Nearby              [🔖 saved]  │
├────────────────────────────────────────────────────┤
│          Products    │    Services                   │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Gradient `#282828` → `#404040` (top to bottom) |
| Bottom border | White, 0.5px |
| Title text | Poppins, 20px, bold, white |
| Title alignment | Center |
| Elevation | 0, transparent shadow |
| Toolbar height | Default (56) |

### AppBar Action Button (Saved Posts)

| Property | Value |
|----------|-------|
| Icon | `bookmark_border_rounded`, size 20 |
| Container bg | `Colors.white` alpha 0.1 |
| Container border | `Colors.white` alpha 0.2 |
| Border radius | 10 |
| Right padding | 12 |
| Tap | Navigates to `SavedNearbyScreen` |

### Tab Bar Styling

| Property | Value |
|----------|-------|
| Indicator color | White |
| Indicator weight | 1 |
| Label color (selected) | White |
| Label style (selected) | Poppins, 13px, w600 |
| Label color (unselected) | White 60% opacity |
| Label style (unselected) | Poppins, 13px, normal |
| Divider color | Transparent |
| Bottom border | White 20% opacity, 1px |
| Label padding | Horizontal 4 |
| Haptic | `lightImpact` on tab switch |

### Category Tabs

| Tab Name | Description |
|----------|-------------|
| Products | Default tab — product listings (buy/sell) |
| Services | Service listings (seek/provide) |

### Search Bar

- Widget: `GlassSearchField` custom widget, border radius 16
- Text search: Filters posts by title, description, originalPrompt, userName, hashtags, keywords (case-insensitive)
- Voice search: `speech_to_text` package, locale `en_IN`, max 30s, pause-for 3s, 5s silence auto-stop

### Body Background

```
Gradient: #404040 (top) → #000000 (bottom)
```

### Data Loading Pipeline

```
isVisible=true → _loadMyLocationThenFetchFeed()
                    ├── _loadMyLocation()
                    │     ├── 1. Static cache (instant)
                    │     └── 2. IpLocationService.detectLocation() (10s timeout)
                    └── _fetchNearbyFeed()
                          ├── POST /nearby/feed {user_id, lat, lng, radius_km:50, limit:50}
                          ├── Parse response with NearbyModel.fromJson()
                          ├── Convert to flat cards via toFlatCards()
                          ├── Enrich cards with Firestore user locations (parallel batch)
                          ├── Categorize into Products/Services tabs
                          ├── Deduplicate by listing_id + user+item combos
                          ├── Filter out current user's own posts
                          └── Sort by distance (nearest first)
```

### Post Card Layout (`_buildPostCard`)

```
┌──────────────────────────┐
│  [Domain Badge]  [🔖]    │  ← Top: domain tag (blue) + bookmark button
│                          │
│     (Cover Image or      │  ← Center: CachedNetworkImage or gradient placeholder
│      Gradient Placeholder)│
│                          │
│ ┌──────────────────────┐ │  ← Bottom: glassmorphism info bar
│ │ Title (1 line)       │ │
│ │ Brand    [Selling]   │ │  ← Brand + feed category badge
│ │ ₹Price              │ │  ← Green price text
│ │ 📍 Location • 3.2 km│ │  ← Location + distance
│ └──────────────────────┘ │
└──────────────────────────┘
```

### Post Card Dimensions

| Property | Value |
|----------|-------|
| Card height | 200px (fixed) |
| Card border radius (outer) | 16 |
| Card ClipRRect radius (inner) | 15 |
| Card margin | left: 4, right: 4, bottom: 6 |
| Card border | `Colors.white` alpha 0.15 |
| Card shadow | `Colors.black` alpha 0.4, blur 8, offset (0, 3) |

### Post Card Typography

| Element | Family | Size | Weight | Color |
|---------|--------|------|--------|-------|
| Title | Poppins | 13 | w700 | white |
| Brand | Poppins | 10.5 | default | `Colors.grey[400]` (#BDBDBD) |
| Price | Poppins | 11 | w700 | `Colors.green[400]` (#66BB6A) |
| Distance | Poppins | 10.5 | default | `Colors.grey[400]` (#BDBDBD) |

### Domain Badge

| Property | Value |
|----------|-------|
| Position | top: 8, left: 8 |
| Background | `#2196F3` alpha 0.85 |
| Border | `Colors.white` alpha 0.25, width 0.5 |
| Border radius | 8 |
| Padding | horizontal: 7, vertical: 3 |
| Text | Poppins, 10px, w600, white |
| Blur | `BackdropFilter` sigmaX: 10, sigmaY: 10 |

### Bookmark Button (Card)

| Property | Value |
|----------|-------|
| Position | top: 8, right: 8 |
| Background | `#007AFF` |
| Border | `Colors.white` alpha 0.25 |
| Shape | Circle |
| Icon (saved) | `bookmark_rounded`, size 16, white |
| Icon (unsaved) | `bookmark_border_rounded`, size 16, white70 |

### Info Bar (Card Bottom)

| Property | Value |
|----------|-------|
| Position | left: 4, right: 4, bottom: 4 |
| Background | `Colors.black` alpha 0.55 |
| Border | `Colors.white` alpha 0.15, width 0.5 |
| Border radius | 14 |
| Padding | fromLTRB(10, 8, 10, 10) |
| Blur | `BackdropFilter` sigmaX: 12, sigmaY: 12 |

### Feed Category Badge

| Category | Label | Background Color |
|----------|-------|-----------------|
| sell | "Selling" | `#4CAF50` alpha 0.85 (Green) |
| buy | "Buying" | `#FF9800` alpha 0.85 (Orange) |
| Other | Title Case | `Colors.white` alpha 0.2 |

**Badge styling:** Poppins 9px w600 white, border radius 6, padding horizontal: 6 vertical: 2

### Distance Display

| Property | Value |
|----------|-------|
| Icon | `near_me`, size 11, `Colors.grey[500]` |
| Text | Poppins 10.5px, `Colors.grey[400]` |
| Gap (icon-text) | 3 |
| Format | `< 1 km` → meters, `>= 1 km` → km (e.g., "3.2 km") |

### Bottom Gradient Overlay

| Stop | Color | Position |
|------|-------|----------|
| 1 | Transparent | 0.35 |
| 2 | `Colors.black` alpha 0.1 | 0.6 |
| 3 | `Colors.black` alpha 0.80 | 1.0 |

### Masonry Grid

| Property | Value |
|----------|-------|
| Widget | `SliverMasonryGrid.count` |
| Columns | 2 |
| Main axis spacing | 10 |
| Cross axis spacing | 10 |
| Padding | fromLTRB(12, 8, 12, 80) |
| Physics | `BouncingScrollPhysics` |

### Gradient Placeholders (No-Image Cards)

| Domain/Type | Icon | Gradient Colors |
|-------------|------|----------------|
| phone/smartphone | `smartphone_rounded` | `#1a1a2e` → `#16213e` |
| gpu/computer/laptop | `memory_rounded` | `#0f0c29` → `#302b63` |
| gas/petroleum/fuel | `local_fire_department_rounded` | `#1a1a0e` → `#2d2d1a` |
| technology/electronics | `devices_rounded` | `#0d1b2a` → `#1b2838` |
| fashion/clothing | `checkroom_rounded` | `#2d1b2e` → `#1a1028` |
| food/restaurant | `restaurant_rounded` | `#2e1a0d` → `#1a1208` |
| vehicle/auto | `directions_car_rounded` | `#1a1a2e` → `#0d1b2a` |
| home/furniture | `home_rounded` | `#1a2e1a` → `#0d2a1b` |
| energy/utilities | `bolt_rounded` | `#2e2a0d` → `#1a1808` |
| service | `build_rounded` | `#0d2a2e` → `#081a1a` |
| Default | `inventory_2_rounded` | `#1a1a2e` → `#121220` |

**Icon size:** 64, color: `Colors.white` alpha 0.12

### Floating Card Animation

| Property | Value |
|----------|-------|
| Vertical range | ±6.0 pixels |
| Duration | 1600ms + (index % 6) × 220ms |
| Phase offset | (index × 0.17) % 1.0 |
| Curve | `Curves.easeInOut` |
| Repeat | Reverse |

### Slide Transition (`_ExpandRoute`)

| Property | Value |
|----------|-------|
| Open duration | 500ms |
| Close duration | 400ms |
| Open curve | `Curves.easeOutQuart` |
| Close curve | `Curves.easeInQuart` |
| Slide | from `Offset(-1.0, 0.0)` (left) |
| Fade | 0.5 → 1.0, first 40% of animation |

### Empty State

| Variant | Icon | Title | Subtitle |
|---------|------|-------|----------|
| No posts | `article_outlined` (64px, white54) | "No Posts Found" | "Try a different search or category" |
| API error | `cloud_off_rounded` (64px, white54) | "Could Not Load Posts" | Error message + "Tap to Retry" button |

**Empty state styling:**
- Circle bg: `Colors.white` alpha 0.2, border: `Colors.white` alpha 0.3, padding: 24
- Title: `AppTextStyles.titleLarge` (18px, bold, white), letterSpacing: -0.5
- Subtitle: `AppTextStyles.bodyMedium` (15px, w400, white60), letterSpacing: -0.5
- Retry button: `Colors.white` alpha 0.15 bg, `Colors.white24` border, radius 20, padding horizontal: 24, vertical: 10

### Pull-to-Refresh

| Property | Value |
|----------|-------|
| Indicator color | White |
| Background | `Colors.white24` |
| Trigger | Full `_loadMyLocationThenFetchFeed()` pipeline |

---

## 2. Saved Nearby Screen

**File:** `lib/screens/near by/saved_nearby_screen.dart`
**Class:** `SavedNearbyScreen` (StatefulWidget)
**Purpose:** Displays all posts the user has bookmarked/saved from the NearBy feed. Allows unsaving and navigating to post details.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  [←]        Nearby Saved Posts                      │
└────────────────────────────────────────────────────┘
```

### AppBar Styling

| Element | Style |
|---------|-------|
| Background | Gradient `#282828` → `#404040` (top to bottom) |
| Bottom border | White, 0.5px |
| Leading icon | `arrow_back_ios_new_rounded`, size 18, white |
| Title | "Nearby Saved Posts", Poppins 17px w700, white, centered |
| Elevation | 0 |

### Body Background

```
Gradient: #404040 (top) → #000000 (bottom)
```

### Data Source

Real-time `StreamBuilder` on Firestore: `users/{uid}/saved_posts` ordered by `savedAt` descending.

### Post Card Dimensions

| Property | Value |
|----------|-------|
| Card height | 200px (fixed) |
| Card border radius (outer) | 16 |
| Card ClipRRect radius (inner) | 15 |
| Card margin | left: 4, right: 4, bottom: 6 |
| Card border | `Colors.white` alpha 0.15 |
| Card shadow | `Colors.black` alpha 0.4 |

### Post Card Typography

| Element | Family | Size | Weight | Color |
|---------|--------|------|--------|-------|
| Title | Poppins | 12.5 | w700 | white, height: 1.2 |
| Brand | Poppins | 10 | default | `Colors.grey[400]`, height: 1.2 |
| Price | Poppins | 10.5 | w700 | `Colors.green[400]`, height: 1.2 |
| Distance | Poppins | 9.5 | default | `Colors.grey[500]`, height: 1.2 |

### Domain Badge (Saved)

| Property | Value |
|----------|-------|
| Position | top: 8, left: 8 |
| Background | `#2196F3` alpha 0.85 |
| Border | `Colors.white` alpha 0.25, width 0.5 |
| Border radius | 8 |
| Padding | horizontal: 7, vertical: 3 |
| Text | Poppins, 9px, w600, white |

### Unsave Button

| Property | Value |
|----------|-------|
| Position | top: 8, right: 8 |
| Background | `#007AFF` |
| Border | `Colors.white` alpha 0.25 |
| Shape | Circle |
| Icon | `bookmark_rounded`, size 16, white |

### Info Bar (Saved Card)

| Property | Value |
|----------|-------|
| Position | left: 4, right: 4, bottom: 4 |
| Background | `Colors.black` alpha 0.55 |
| Border | `Colors.white` alpha 0.15, width 0.5 |
| Border radius | 14 |
| Padding | fromLTRB(8, 6, 8, 7) |

### Feed Category Badge (Saved)

**Badge styling:** Poppins 8.5px w600 white, border radius 5, padding horizontal: 5 vertical: 1.5

### Masonry Grid (Saved)

| Property | Value |
|----------|-------|
| Widget | `MasonryGridView.builder` |
| Columns | 2 |
| Main axis spacing | 10 |
| Cross axis spacing | 10 |
| Padding | left: 12, right: 12, top: 12, bottom: 24 |

### Gradient Placeholders (Saved)

| Domain | Icon | Gradient Colors |
|--------|------|----------------|
| technology & electronics | `devices_rounded` | `#1a237e` → `#283593` |
| fashion & accessories | `checkroom_rounded` | `#880e4f` → `#ad1457` |
| home & living | `home_rounded` | `#1b5e20` → `#2e7d32` |
| automotive | `directions_car_rounded` | `#bf360c` → `#d84315` |
| Default | `shopping_bag_rounded` | `#1a1a2e` → `#2d2d44` |

**Icon size:** 48, color: `Colors.white` alpha 0.2

### Empty State (Saved)

| Property | Value |
|----------|-------|
| Icon | `bookmark_outline`, size 64, `Colors.white38` |
| Circle bg | `Colors.white` alpha 0.1, border: `Colors.white` alpha 0.3 |
| Title | Poppins 18px w600 white70 |
| Subtitle | Poppins 13px white38, textAlign center |

---

## 3. NearBy Post Detail Screen

**File:** `lib/screens/near by/near_by_post_detail_screen.dart`
**Class:** `NearByPostDetailScreen` (StatefulWidget)
**Purpose:** Displays the full detail view of a nearby post, including images, title, brand, price, description, product details, highlights, keywords, and bottom action bar (chat/call or restore/delete).

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `postId` | `String` | required | Post document ID |
| `post` | `Map<String, dynamic>` | required | Full post data map |
| `distanceText` | `String` | `''` | Pre-formatted distance text |
| `isDeleted` | `bool` | `false` | Whether post is in deleted state |
| `showCallButton` | `bool` | `true` | Show call action in bottom bar |
| `tabCategory` | `String` | `'Products'` | Source tab category |

### Accent Color

```dart
static const _accent = Color(0xFF016CFF);
```

### Body Background

```
Gradient: RGBA(64, 64, 64, 1) (top) → RGBA(0, 0, 0, 1) (bottom)
```

### Custom AppBar

| Element | Style |
|---------|-------|
| Background | Transparent |
| Bottom border | White, 1.0px |
| Back icon | `arrow_back_ios_rounded`, size 20, white |
| Avatar | 34×34 circle, border: `Colors.white` alpha 0.7, width 1.5 |
| Avatar fallback | White24 circle bg, Poppins 14px bold white |
| Owner name | Poppins, 15px, w600, white |
| Save button | 36×36, bg `Colors.white` alpha 0.1, border `Colors.white` alpha 0.2, radius 10 |
| Save icon active | `bookmark_rounded`, size 20, white |
| Save icon inactive | `bookmark_border_rounded`, size 20, white70 |

### Image Grid

| Property | Value |
|----------|-------|
| Grid height | 280px |
| Gap between images | 6px |
| Image border radius | 12 |
| Container border radius | 16 |
| Container border | `Colors.white` alpha 0.25, width 1.2 |
| Container shadow | `Colors.black` alpha 0.5, blur 14, offset (0, 5) |
| Padding | fromLTRB(14, 14, 14, 8) |

**Image layout patterns:**
- 1 image: full-width
- 2 images: row of two equal-width
- 3+ images: left (flex: 3) + right column (flex: 2) with two stacked

### Vignette Overlay Gradients

| Edge | Colors | Size |
|------|--------|------|
| Left | `Colors.black` alpha 0.7 → transparent | 60px wide |
| Right | `Colors.black` alpha 0.7 → transparent | 60px wide |
| Top | `Colors.black` alpha 0.75 → transparent | 80px tall |
| Bottom | `Colors.black` alpha 0.35 → transparent | 40px tall |
| Corners (TL/TR) | RadialGradient `black75, black30, transparent` stops `[0.0, 0.4, 1.0]` | 90×90 |

### Content Typography

| Element | Family | Size | Weight | Color |
|---------|--------|------|--------|-------|
| Title | Poppins | 20 | w700 | white, height: 1.25 |
| Brand | Poppins | 14 | w500 | `Colors.grey[400]` |
| Section headers | Poppins | 16 | w700 | white |
| Description | Poppins | 14 | default | `Colors.grey[400]`, height: 1.6 |
| Product detail label | Poppins | 12 | w500 | `Colors.grey[500]` |
| Product detail value | Poppins | 12 | w600 | white |
| Price (normal) | Poppins | 18 | w700 | white |
| Price (donation) | Poppins | 18 | w700 | `Colors.pinkAccent` |

### Price Chip

| Variant | Background | Border | Text Color |
|---------|-----------|--------|------------|
| Normal | `_accent` alpha 0.12 | `_accent` alpha 0.25 | white |
| Donation ("Free") | `Colors.pinkAccent` alpha 0.12 | `Colors.pinkAccent` alpha 0.25 | `Colors.pinkAccent` |

**Chip styling:** border radius 12, padding horizontal: 14 vertical: 8

### Info Chips (Category-Based)

| Category | Icon | Icon Color |
|----------|------|------------|
| Buy | `shopping_cart_outlined` | `Colors.orangeAccent` |
| Sell | `sell_rounded` | `Colors.greenAccent` |
| Seek | `search_rounded` | `Colors.cyanAccent` |
| Provide | `volunteer_activism_rounded` | `Colors.purpleAccent` |
| Mutual | `handshake_rounded` | `Colors.amberAccent` |
| Item type | `devices_rounded` | `Colors.lightBlueAccent` |
| Condition | `new_releases_rounded` | `Colors.tealAccent` |
| Default | `label_outlined` | `Colors.grey` |

**Chip styling:** bg `iconColor` alpha 0.12, border `iconColor` alpha 0.25, radius 12, padding horizontal: 12 vertical: 8, text Poppins 13px w600

### Feature/Keyword Chip

| Property | Value |
|----------|-------|
| Background | `_accent` alpha 0.22 |
| Border | `_accent` alpha 0.4 |
| Border radius | 20 |
| Padding | horizontal: 12, vertical: 7 |
| Icon | `check_circle_rounded`, size 13, white |
| Text | Poppins 12px w600 white |

### Glass Card (Product Details Section)

| Property | Value |
|----------|-------|
| Background | `Colors.white` alpha 0.06 |
| Border | `Colors.white` alpha 0.3, width 1 |
| Border radius | 16 |
| Blur | `BackdropFilter` sigmaX: 10, sigmaY: 10 |

### Bottom Action Bar

| Property | Value |
|----------|-------|
| Background | `Colors.black` alpha 0.5 |
| Top border | `Colors.white` alpha 0.08 |
| Backdrop blur | sigmaX: 20, sigmaY: 20 |
| Padding | left: 20, right: 20, top: 14, bottom: safeArea + 14 |

### Bottom Bar Buttons

| Button | Background | Border | Icon | Text Color |
|--------|-----------|--------|------|------------|
| Chat | Gradient `[_accent, _accent alpha 0.8]` | — | `chat_bubble_outline_rounded` 18 | white |
| Call | `#4CAF50` alpha 0.15 | `#4CAF50` alpha 0.4 | `call_rounded` 18 | `#4CAF50` |
| Restore | `_accent` gradient | — | `restore_rounded` 18 | white |
| Delete | `Colors.red` alpha 0.15 | `Colors.red` alpha 0.3 | `delete_forever_rounded` 18 | `Colors.redAccent` |

**Button styling:** border radius 14, padding vertical: 15, text Poppins 15px w700

### Content Spacing

| Gap | Value |
|-----|-------|
| Title → Brand | 4 |
| Brand → Price | 12 |
| Price → Chips | 12 |
| Chips → Description | 22 |
| Section header → Content | 10 |
| Section → Section | 16 |
| Bottom spacer | 110 |

---

## Screen Navigation Flow

```
┌─────────────────┐
│  NearBy Screen   │──[Bookmark icon]──→ SavedNearbyScreen
│  (Main Feed)     │                         │
│                  │                         │
│  [Tap card] ─────┼──→ NearByPostDetailScreen
│                  │         ↑               │
└─────────────────┘         │    [Tap card] ─┘
                            │
              NearByPostDetailScreen
              (shared destination from both screens)
```

### Navigation Methods

| From | To | Trigger | Route Type |
|------|----|---------|------------|
| NearByScreen | SavedNearbyScreen | AppBar bookmark icon | `MaterialPageRoute` |
| NearByScreen | NearByPostDetailScreen | Tap post card | `_ExpandRoute` (slide-from-left) |
| SavedNearbyScreen | NearByPostDetailScreen | Tap saved card | `MaterialPageRoute` |
| SavedNearbyScreen | NearByScreen | Back arrow | `Navigator.pop()` |

---

## Shared Design System

### Consistent Background Gradients

| Location | Start | End |
|----------|-------|-----|
| AppBar flexibleSpace | `#282828` (RGBA 40,40,40) | `#404040` (RGBA 64,64,64) |
| Body background | `#404040` (RGBA 64,64,64) | `#000000` (RGBA 0,0,0) |

### Font Family

**Poppins** — used exclusively across all 3 screens. No other font family is used.

### Accent Colors

| Name | Hex | Usage |
|------|-----|-------|
| Primary Blue | `#016CFF` | Action buttons, keywords, feature chips |
| iOS Blue | `#007AFF` | Bookmark button, mandatory asterisks |
| Material Blue | `#2196F3` | Domain badges |
| Vibrant Green | `#00D67D` | Price text, call toggle |
| Error Red | `#EF4444` | Delete actions, expiring badges |
| Success Green | `#10B981` | Restore actions |

### Glassmorphism Pattern

All screens use consistent glass-card styling:
- `BackdropFilter` with `ImageFilter.blur` (sigma 8–20)
- Semi-transparent background: `Colors.white` alpha 0.06–0.55
- Thin white border: `Colors.white` alpha 0.15–0.3
- Dark card shadow: `Colors.black` alpha 0.4–0.5

### Floating Card Animation (Shared)

Used in NearByScreen and SavedNearbyScreen:
- Vertical oscillation: `Tween(-6.0, 6.0)` with `easeInOut`
- Duration: `1600 + (animationIndex % 6) * 220` ms
- Phase offset: `animationIndex * 0.17`
- Repeats in reverse

### Dependencies

| Package | Usage |
|---------|-------|
| `firebase_auth` | User authentication, ID tokens for API |
| `cloud_firestore` | Posts, saved posts, user profiles, API mappings |
| `cached_network_image` | Post image caching and display |
| `speech_to_text` | Voice search functionality |
| `flutter_staggered_grid_view` | Masonry grid layout for cards |
| `permission_handler` | Microphone permission |
| `http` | API calls to `/nearby/feed` |
| `uuid` | Firebase UID → UUID v5 conversion |
| `geolocator` | Device GPS position |

---

## File Structure

```
lib/screens/near by/
├── near_by_screen.dart              ← Screen 1: Main NearBy feed
├── saved_nearby_screen.dart         ← Screen 2: Saved/bookmarked posts
└── near_by_post_detail_screen.dart  ← Screen 3: Full post detail view

lib/models/
└── nearby_model.dart                ← NearbyModel, NearbyListing, NearbyUserLocation

lib/services/
├── product_api_service.dart         ← API service (Home screen; NearBy has direct call)
└── ip_location_service.dart         ← IP-based location detection
```
