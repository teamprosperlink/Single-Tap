# Nearby Module — Complete Screen Documentation

**App:** Supper
**Module:** Nearby / Marketplace
**Total Screens:** 5 (1 main feed + 1 my-posts manager + 1 create + 1 edit + 1 detail)
**Last Updated:** 10 Mar 2026

---

## Table of Contents

1. [Nearby Screen (Main Feed)](#1-nearby-screen-main-feed)
2. [My Posts Screen](#2-my-posts-screen)
3. [Create Post Screen](#3-create-post-screen)
4. [Edit Post Screen](#4-edit-post-screen)
5. [Post Detail Screen](#5-post-detail-screen)
6. [Screen Navigation Flow](#screen-navigation-flow)
7. [Firestore Collections Used](#firestore-collections-used)
8. [Shared UI Patterns](#shared-ui-patterns)
9. [Key Business Rules](#key-business-rules)

---

## 1. Nearby Screen (Main Feed)

**File:** `lib/screens/near by/near_by_screen.dart`
**Class:** `NearByScreen` (StatefulWidget)
**Lines:** ~1762
**Purpose:** The primary marketplace feed. Displays posts from other users within a 10 km radius, organized by category tabs. Provides search (text + voice), save/bookmark, own-post management (edit/delete), and navigation to post details, My Posts, and Create Post.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `onBack` | `VoidCallback?` | No | Callback when user taps back (defined but not wired to any UI element) |

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│                     Nearby              [📋 feed]   │
├────────────────────────────────────────────────────┤
│  Services  │  Jobs  │  Products  │  Donation       │
└────────────────────────────────────────────────────┘
```

- **Title:** "Nearby" (centered, white, Poppins bold 20px)
- **Right action:** My Posts icon (`Icons.dynamic_feed`, 18px) in glass container → navigates to `MyPostsScreen`
- **Bottom:** 4-tab `TabBar` — Services, Jobs, Products, Donation (text-only, no icons rendered despite icons being defined)
- **Background:** Gradient fade (black 40% → black 20% → transparent) + white bottom border (0.5px)
- **`automaticallyImplyLeading: false`** — no back button
- **`extendBodyBehindAppBar: true`**
- **Tab Properties:** `isScrollable: false`, `tabAlignment: TabAlignment.fill`, `indicatorColor: Colors.white`, `indicatorWeight: 1`

### Category Tabs (TabController)

| Tab | Name | Icon (defined, not rendered in tab) | Matching Strategy |
|-----|------|------|-------------------|
| 0 | Services | `Icons.computer_rounded` | Keyword scoring (26 terms) |
| 1 | Jobs | `Icons.work_rounded` | Keyword scoring (22 terms) |
| 2 | Products | `Icons.shopping_bag_rounded` | Keyword scoring (33 terms) + default fallback |
| 3 | Donation | `Icons.volunteer_activism_rounded` | `isDonation == true` flag |

**Category Matching Algorithm (`_matchesCategory`):**

Multi-tier strategy with scoring:

1. **Structured `postType` field (highest priority):** If the post has a `postType` string field, direct equality check wins immediately.
2. **`isDonation` flag shortcut:** If `data['isDonation'] == true`, belongs exclusively to Donation tab.
3. **Keyword scoring fallback:** Gathers text from `category`, `categories`, `intentAnalysis.domain`, title, description, hashtags, keywords, originalPrompt, and `intentAnalysis.primary_intent/search_keywords`.

**Scoring algorithm (`_categoryScore`):**
- Category field exact match: **+50 points**
- Category field word-boundary match: **+40 points**
- Title/description/prompt word-boundary match: **+10 per hit**, capped at **2 hits (max +20)**
- Highest score wins. If all scores are 0 → defaults to **Products**

**Keyword sets (static constants):**

| Category | Count | Example Terms |
|----------|-------|---------------|
| Services | 26 | service, repair, cleaning, plumber, electrician, tutor, salon, driver, freelance, consultant, mechanic, carpenter, painter, photography, graphic design, web development, ac repair, pest control |
| Jobs | 22 | job, hiring, vacancy, career, recruit, internship, full time, part time, fresher, experienced, salary, interview, placement |
| Products | 33 | product, electronics, fashion, furniture, vehicles, mobile, laptop, shoes, clothes, car, bike, grocery, gadget, sell, buy, shop, marketplace |
| Donation | 5 | donation, donate, charity, giveaway, ngo |

**Word-boundary matching:** Uses regex `(?:^|\s|[,;/|])keyword(?:$|\s|[,;/|])` to prevent substring false positives.

**Behavior:** Tabs are mutually exclusive. Donation posts are isolated — hidden from all non-Donation tabs. Tab changes trigger `HapticFeedback.lightImpact()`.

### Search Bar

```
┌──────────────────────────────────────────┐
│ 🔍 Search posts...              [🎤]    │
└──────────────────────────────────────────┘
```

- Uses `GlassSearchField` widget (glassmorphism style)
- **Text search (`_matchesSearch`):** Filters by title, description, originalPrompt, userName, hashtags (joined), keywords (joined) — substring match, case-insensitive
- **Voice search:** Speech-to-text via `speech_to_text` package
  - Requires microphone permission (via `permission_handler`)
  - 5-second silence timer auto-stops if no words recognized
  - Locale: `en_IN` (Indian English)
  - Listen duration: up to 30 seconds
  - Pause detection: 3 seconds
  - Partial results shown in real-time
  - Auto-stops on final result with non-empty words
  - `HapticFeedback.mediumImpact()` on start

### Data Loading & Filtering

**Real-time stream (`_subscribeToFeedPosts`):**
```
posts
  .where('isActive', isEqualTo: true)
  .orderBy('createdAt', descending: true)
  .limit(100)
  .snapshots()
```

- **Page size:** 100 documents (large for better 10km coverage)
- Safety timeout: 8 seconds — forces `_isLoading = false` regardless
- Only shows loading spinner if `_posts` is empty (cached data = instant display)

**Pagination (`_loadMorePosts`):**
```
posts
  .where('isActive', isEqualTo: true)
  .orderBy('createdAt', descending: true)
  .startAfterDocument(_lastDocument)
  .limit(100)
```

- Triggered 500px before scroll bottom
- Deduplicates via `existingIds` + `_paginatedIds` sets

**Client-side filtering pipeline (`_getFilteredPosts`):**

| Step | Filter | Description |
|------|--------|-------------|
| 1 | Duplicate doc ID removal | `seenIds` set |
| 2 | Dummy post removal | `isDummyPost == true` |
| 3 | Invalid user removal | null, empty, or `dummy_` prefixed userId |
| 4 | Empty content removal | No title AND no originalPrompt |
| 5 | No-image removal | Posts without `images` list or `imageUrl` field. Does NOT fall back to user profile photos |
| 6 | Content-based deduplication | Three content keys: `userId_normalizedTitle`, `userId_description`, `userId_prompt` |
| 7 | Own-post exclusion | Current user's posts hidden (view in My Posts) |
| 8 | Inactive post exclusion | `isActive == false` |
| 9 | Donation isolation | Non-Donation tabs hide `isDonation == true` posts |
| 10 | Category matching | `_matchesCategory()` scoring algorithm |
| 11 | Search query matching | `_matchesSearch()` substring check |
| 12 | **10 km radius filter** | Posts beyond 10 km hidden. Posts without coordinates also hidden when user location is available |

**Post-filter sort:** When user location is available, results are sorted by **distance ascending** (nearest first).

**Caching:** Results cached in `_cachedFilteredPostsByCategory` with key `"category_searchQuery"`. Invalidated when posts stream updates, search query changes, or user location changes.

### Static Data Persistence

Uses `static` fields on the widget class to persist data across widget rebuilds:

| Static Variable | Type | Purpose |
|----------------|------|---------|
| `_cachedPosts` | `List<DocumentSnapshot>` | Posts survive tab switches |
| `_cachedSavedPostIds` | `Set<String>` | Saved IDs survive rebuilds |
| `_cachedLat` / `_cachedLng` | `double?` | Location persists |
| `_hasEverLoaded` | `bool` | Skip loading spinner on revisit |
| `_globalUserCache` | `Map<String, Map<String, dynamic>>` | User info cache shared across instances |

### Location (3-Tier Resolution)

| Priority | Source | Details |
|----------|--------|---------|
| 1 | Static cache | If `_cachedLat`/`_cachedLng` already set, uses immediately |
| 2 | Firestore GPS | `users/{uid}` document (cache-first with 3s timeout, fallback to server) |
| 3 | IP-based location | `IpLocationService.detectLocation()` with 10s timeout — cascades: GPS low accuracy → GPS medium accuracy → ip-api.com → ipinfo.io → ipwho.is (each with 5s timeout, 2-minute cache) |
| 4 | Fallback | Shows posts without distance filtering |

**Distance:** Haversine formula (Earth radius 6371 km). Displayed as "X m" (< 1 km) or "X.X km".

**Lifecycle:** `WidgetsBindingObserver` refreshes location and saved posts when app resumes from background.

### Post Card Layout

```
┌──────────────────────┐
│ [🏷 SubCategory]  [🔖]│  ← Sub-category badge (top-left), Bookmark OR Edit/Delete (top-right)
│                      │
│  (Cover Image)       │  ← Full cover, CachedNetworkImage
│                      │
│ ┌──────────────────┐ │
│ │ Post Title       │ │  ← Glassmorphism bottom bar (BackdropFilter blur: 12)
│ │ Sub Category     │ │  ← If available (Poppins 12px, white 85% alpha)
│ │ ₹800             │ │  ← Price in green (#00D67D)
│ │ 📍 1.2 km        │ │  ← Distance with location pin icon
│ └──────────────────┘ │
└──────────────────────┘
```

- **Card height:** 200px
- **Layout:** 2-column masonry grid (`SliverMasonryGrid.count`, 10px spacing)
- **Animation:** Floating card animation (vertical bounce -6px to +6px, staggered per index)
- **Border:** white 25% alpha, 1.5px, 20px radius, black shadow (0.4 alpha, 8px blur)

**Top-left badges:**
- **Sub-category badge:** Glassmorphic chip (`BackdropFilter` blur: 10) with color-coded background based on `postType`:
  - Services: blue (#3B82F6)
  - Jobs: indigo (#6366F1)
  - Products: orange (#F97316)
  - Donation: pink (#EC4899)
- **Donation badge (fallback):** Orange 90% alpha container if `isDonation == true` and no sub-category

**Top-right buttons:**
- **Own posts:** Edit button (`Icons.edit_outlined`) + Delete button (`Icons.delete_outline_rounded`, redAccent)
- **Other users' posts:** Bookmark toggle button (blue `AppColors.iosBlue` at 85% alpha)

**Card tap:** Opens `NearByPostDetailScreen` via custom `_ExpandRoute` transition (slide from left, 2s duration)

### Floating Action Button

- **Type:** `FloatingActionButton.extended` with text label
- **Position:** Bottom-right (75px from bottom, 20px from right)
- **Label:** "Create Post" (white 14px semi-bold)
- **Color:** `AppColors.iosBlue`
- **Height:** 36px (compact, `materialTapTargetSize: shrinkWrap`)
- **Action:** `HapticFeedback.lightImpact()` → Opens `CreatePostScreen`
- On return: re-subscribes to feed posts

### Private Helper Classes

**`_FloatingCard`** — Animated wrapper with vertical float animation
- Vertical float: -6px to +6px
- Duration: 1600–2700ms (staggered per card index: `1600 + (index % 6) * 220`)
- Phase stagger: `(index * 0.17) % 1.0`
- Curve: `easeInOut`, repeats with reverse

**`_ExpandRoute<T>`** — Custom page route (slide-from-left transition)
- Forward duration: 2000ms, reverse: 1600ms
- Slide: `Offset(-1.0, 0.0)` → `Offset.zero` (left to right)
- Fade: 0.5 → 1.0, first 40% of animation only
- Forward curve: `easeOutQuart`, reverse: `easeInQuart`

### State Variables

| Variable | Type | Description |
|----------|------|-------------|
| `_tabController` | `late TabController` | 4-tab controller |
| `_scrollControllers` | `List<ScrollController>` | One per tab (avoids shared-controller conflicts) |
| `_posts` | `List<DocumentSnapshot>` | Raw posts from Firestore stream |
| `_isLoading` | `bool` | Initial load indicator |
| `_isLoadingMore` | `bool` | Pagination load indicator |
| `_hasMore` | `bool` | Whether more pages exist |
| `_lastDocument` | `DocumentSnapshot?` | Pagination cursor |
| `_pageSize` | `int` | 100 docs per page |
| `_savedPostIds` | `Set<String>` | IDs of bookmarked posts |
| `_myLat / _myLng` | `double?` | Current user GPS coordinates |
| `_isListening` | `bool` | Voice search active |
| `_selectedCategory` | `String` | Current tab name (default: 'Services') |
| `_cachedFilteredPostsByCategory` | `Map<String, List<DocumentSnapshot>>` | Per-category+search filtered post cache |
| `_searchController` | `TextEditingController` | Search text controller |
| `_speech` | `stt.SpeechToText` | Speech recognition instance |
| `_speechEnabled` | `bool` | Whether speech initialized |
| `_silenceTimer` | `Timer?` | 5-second voice search timeout |

### Soft Delete from Feed

Own posts can be deleted directly from the feed card. The delete button shows a glassmorphic confirmation dialog, then:
- Sets `isActive: false` and `deletedAt: serverTimestamp()`
- Shows "Post moved to Delete tab" snackbar

### Firebase Schema

**Read — `posts` collection (stream + pagination):**
```javascript
posts/{postId} {
  userId: string,
  title: string,
  description: string,
  postType: string,           // "Products", "Services", "Jobs", "Donation"
  subCategory: string,
  images: string[],           // Firebase Storage URLs
  price: number,
  currency: string,           // "INR", "USD", "EUR", "GBP"
  keywords: string[],
  location: string,
  latitude: number,
  longitude: number,
  isActive: true,             // only active posts fetched
  createdAt: timestamp,
  expiresAt: timestamp
}
```
- **Query:** `where('isActive', true).orderBy('createdAt', desc).limit(100).snapshots()`
- **Pagination:** `.startAfterDocument(lastDoc).limit(100)`

**Read — `users/{uid}/saved_posts` (bookmark check):**
```javascript
users/{uid}/saved_posts/{postId} {
  postId: string,
  savedAt: timestamp
}
```
- **Query:** `.limit(500).get()` — loads all saved post IDs into `_savedPostIds` Set

**Update — Soft delete own posts:**
```javascript
posts/{postId}.update({
  isActive: false,
  deletedAt: serverTimestamp()
})
```

---

## 2. My Posts Screen

**File:** `lib/screens/near by/near_by_posts _screen.dart`
**Class:** `MyPostsScreen` (StatefulWidget)
**Lines:** ~1545
**Purpose:** Manages the current user's own posts. Provides three tabs: My Posts (active), Saved (bookmarked), and Deleted (soft-deleted with 30-day auto-delete). Posts without images are hidden from all tabs.

### Constructor Parameters

None (standalone screen, loads data from Firebase using current user UID).

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│  ←           My Posts                              │
├────────────────────────────────────────────────────┤
│      My Posts    │    Saved    │    Deleted          │
└────────────────────────────────────────────────────┘
```

- **Title:** "My Posts" (centered, white, Poppins bold 20px)
- **Leading:** Back arrow button (`Icons.arrow_back_ios_new_rounded`)
- **Bottom:** 3 fixed tabs — My Posts, Saved, Deleted
- **Background:** Same gradient fade as NearByScreen

### User Data Loading

On `initState()`, fetches `users/{uid}` document:
- `_currentUserName` from `data['name']` or `data['displayName']` or `'You'`
- `_currentUserPhoto` from `data['photoUrl']` or `data['photoURL']`
- Overlaid on cards in My Posts and Deleted tabs

### Image Requirement

Helper method `_hasImage()` checks both `imageUrl` (single string) and `images` (List). Posts failing this check are **hidden from all three tabs**.

### Tab 1: My Posts

**Firestore query:**
```
posts
  .where('userId', == currentUserId)
  .where('isActive', == true)
  .orderBy('createdAt', descending: true)
  .limit(50)
  .snapshots()
```

**Post-processing:** Deduplicates by doc ID, filters out posts without images, overlays current user name/photo.

**Card actions (top-right):**
- Edit icon (`Icons.edit_outlined`) → Opens `EditPostScreen`
- Delete icon (`Icons.delete_outline_rounded`) → Shows soft-delete confirmation dialog

### Tab 2: Saved

**Firestore query:**
```
users/{uid}/saved_posts
  .orderBy('savedAt', descending: true)
  .limit(50)
  .snapshots()
```

**Post-processing:** Deduplicates by doc ID, extracts `postData` map from saved document, filters out posts without images.

**Card actions (top-right):**
- Bookmark icon (`Icons.bookmark_rounded`) → Unsaves post directly (no confirmation dialog)

**Note:** Saved posts store a **denormalized full copy** of the post data in the `postData` field, not just a reference. This means saved posts can become stale if the original post is updated.

### Tab 3: Deleted

**Firestore query:**
```
posts
  .where('userId', == currentUserId)
  .where('isActive', == false)
  .orderBy('createdAt', descending: true)
  .limit(100)
  .snapshots()
```

**Auto-delete:** Posts with `deletedAt` older than 30 days are:
1. Detected during StreamBuilder processing
2. Added to `postsToAutoDelete` list and excluded from display
3. Batch-deleted via `_autoDeleteOldPosts()` using `WriteBatch`
4. Guard flag `_isAutoDeleting` prevents concurrent batch operations
5. Deferred to `addPostFrameCallback` to avoid setState-during-build

**Important:** Auto-delete is **client-side only** — runs only when the user opens the Deleted tab. No Cloud Function cleanup exists.

**Top-left badge:** Shows remaining days (e.g., "15 days left"). Badge turns red (`AppColors.error`) when ≤ 7 days.

**Card actions (top-right):**
- Restore icon (`Icons.restore_rounded`) → Shows restore confirmation dialog
- Delete forever icon (`Icons.delete_forever_rounded`) → Shows permanent delete confirmation dialog

### Post Card Layout (shared across tabs)

```
┌──────────────────────┐
│ [⏱ 15 days left] [✏️🗑]│  ← Badge (deleted tab) + action buttons
│                      │
│  (Cover Image)       │
│                      │
│ ┌──────────────────┐ │
│ │ Post Title       │ │  ← Glassmorphism bottom bar (BackdropFilter blur: 12)
│ │ Sub Category     │ │  ← If available (Poppins 12px, white 85%)
│ │ INR 800          │ │  ← Price prefixed with "INR" (green #00D67D)
│ └──────────────────┘ │
└──────────────────────┘
```

- **Card height:** 240px
- **Layout:** 2-column masonry grid (`SliverMasonryGrid.count`, 10px spacing)
- **Animation:** Same `_FloatingCard` floating animation as NearByScreen
- **Tap:** Opens `NearByPostDetailScreen` via `_ExpandRoute` (slide from left)
  - Passes `isDeleted: true` for deleted-tab cards
  - Passes `tabCategory` from `_getTabCategory()` helper
- **Bottom padding:** 80px for bottom navigation bar clearance

### Category Detection Helper (`_getTabCategory`)

| Priority | Check | Returns |
|----------|-------|---------|
| 1 | `isDonation == true` | `'Donation'` |
| 2 | category/text contains `job`, `work`, `hiring` | `'Jobs'` |
| 3 | category/text contains `service`, `repair`, `cleaning` | `'Services'` |
| 4 | Default | `'Products'` |

Sources: `post['category']`, `post['intentAnalysis']['domain']`, title, description.

### Confirmation Dialogs

All dialogs share a consistent dark glassmorphic style:
- Gradient background: `RGB(64,64,64)` to `RGB(15,15,15)`
- White border (0.15 alpha), 20px border radius
- Close (×) button top-right
- Icon in colored circle
- Cancel + Action buttons

| Dialog | Icon | Icon Color | Action Button Color | Action Text |
|--------|------|-----------|---------------------|-------------|
| Soft Delete | `delete_outline_rounded` | `AppColors.error` | `AppColors.error` | "Delete" |
| Restore | `restore_rounded` | `AppColors.success` | `AppColors.success` | "Restore" |
| Permanent Delete | `delete_forever_rounded` | `AppColors.error` | `AppColors.error` | "Delete Forever" |

### CRUD Operations

| Operation | Firestore Action | Fields Modified |
|-----------|-----------------|-----------------|
| Soft Delete | `posts/{id}.update()` | `isActive: false`, `deletedAt: serverTimestamp()` |
| Restore | `posts/{id}.update()` | `isActive: true`, `deletedAt: FieldValue.delete()` |
| Permanent Delete | `posts/{id}.delete()` | Document removed entirely |
| Unsave | `users/{uid}/saved_posts/{id}.delete()` | Document removed (no confirmation) |
| Auto-Delete | `WriteBatch` of `.delete()` | Documents removed in batch |

### Price Formatting

`_formatPrice()`: Whole numbers formatted with comma grouping (e.g., `"1,500"`). Decimals formatted to 2 places. Displayed as `"INR $formatted"`.

### Action Button Style (`_topRightButton`)

All action buttons: `ClipOval` with `BackdropFilter` blur (8), blue background (`#016CFF` at 85%), white border (40% alpha), icon 15px white, `HapticFeedback.lightImpact()`.

### Firebase Schema

**Read — Active posts (My Posts tab):**
```javascript
posts/{postId} → where('userId', == currentUid)
                  .where('isActive', true)
                  .orderBy('createdAt', desc)
                  .limit(50)
```

**Read — Deleted posts (Deleted tab):**
```javascript
posts/{postId} → where('userId', == currentUid)
                  .where('isActive', false)
                  .orderBy('createdAt', desc)
                  .limit(100)
```

**Read — Saved posts (Saved tab):**
```javascript
users/{uid}/saved_posts/{postId} {
  postId: string,
  postData: Map,              // full post data copy (denormalized)
  savedAt: timestamp
}
→ .orderBy('savedAt', desc).limit(50)
```

**Update — Soft Delete:**
```javascript
posts/{postId}.update({
  isActive: false,
  deletedAt: serverTimestamp()
})
```

**Update — Restore:**
```javascript
posts/{postId}.update({
  isActive: true,
  deletedAt: FieldValue.delete()
})
```

**Delete — Permanent Delete:**
```javascript
posts/{postId}.delete()
```

**Delete — Auto-Delete (30-day expired):**
```javascript
WriteBatch → posts/{postId}.delete()  // batch of expired docs
```

---

## 3. Create Post Screen

**File:** `lib/screens/near by/create_post_screen.dart`
**Class:** `CreatePostScreen` (StatefulWidget)
**Lines:** ~2258
**Purpose:** Full-featured form to create a new marketplace post with images, structured post type/sub-category selection, location (GPS + IP-based auto-detect), price, keywords, speech-to-text, and donation toggle.

### Constructor Parameters

None (standalone screen).

### Form Fields

| # | Field | Controller | Required | MaxLength | Speech-to-Text | Description |
|---|-------|-----------|----------|-----------|----------------|-------------|
| 1 | Title | `_titleController` | Yes | 30 | Yes | Post title |
| 2 | Description | `_descriptionController` | Yes | 250 (multiline) | Yes | Detailed description |
| 3 | Post Type | `_selectedPostType` | Yes | — | No | Dialog picker: Services, Jobs, Products, Donation |
| 4 | Sub Category | `_selectedSubCategory` | No | — | No | Dialog picker: type-specific options |
| 5 | Highlights | `_keywordController` | No | — (max 5 chips) | No | Keyword chips |
| 6 | Location | `_locationController` | Yes (at submit) | — | No | Auto-detect + manual search with autocomplete |
| 7 | Offer | `_offerController` | No | — | No | Special offer text |
| 8 | Donation Toggle | `_isDonation` | No | — | No | Switch (hides price when enabled) |
| 9 | Currency | `_selectedCurrency` | No | — | No | Dropdown: INR, USD, EUR, GBP, AED, SAR |
| 10 | Price | `_priceController` | No | — | No | Numeric (hidden when donation) |
| 11 | Allow Calls | `_allowCalls` | No | — | No | Switch (default: true) |

### Form Validation

**Button-enabled check (`_isFormValid`):**
```
title.isNotEmpty && description.isNotEmpty && selectedPostType != null && images.isNotEmpty
```

**Submit-time validation (`_createPost`):**
1. Title not empty
2. Description not empty
3. Post type selected
4. At least one image
5. User authenticated
6. Images uploaded successfully
7. **Location coordinates resolved** (hard block — no post without GPS)

### Post Type & Sub-Category System

Replaces the old free-text category chip input with a **structured two-level dialog picker**.

**Post Type Dialog (`_showPostTypeDialog`):**
- 2-column grid, 4 options
- Each option: colored icon in circle + label text
- Selected item: solid color gradient fill
- Unselected: glass-morphism fill

| Post Type | Icon | Color Gradient |
|-----------|------|---------------|
| Services | `Icons.build_rounded` | Blue (#3B82F6 → #60A5FA) |
| Jobs | `Icons.work_rounded` | Indigo (#6366F1 → #818CF8) |
| Products | `Icons.shopping_bag_rounded` | Orange (#F97316 → #FB923C) |
| Donation | `Icons.volunteer_activism_rounded` | Pink (#EC4899 → #F472B6) |

**Sub-Category Dialog (`_showSubCategoryDialog`):**
- 3-column grid
- Title: `"{PostType} -- Sub Category"`
- Options per type:

| Post Type | Sub-Categories (count) |
|-----------|----------------------|
| Services (15) | Repair, Cleaning, Tutoring, Delivery, Salon & Beauty, Photography, Web Development, Consulting, Plumbing, Electrical, Painting, Catering, Mechanic, Carpentry, Others |
| Jobs (7) | Full Time, Part Time, Internship, Freelance, Contract, Remote, Others |
| Products (11) | Electronics, Fashion, Furniture, Vehicles, Mobile & Phones, Laptops, Books, Grocery, Appliances, Accessories, Others |
| Donation (8) | Clothes, Food, Books, Electronics, Furniture, Toys, Medical, Others |

Each sub-category has a unique Material icon mapping (27 icon definitions).

**Behavior:** Selecting a post type resets sub-category to null. Selecting "Donation" also sets `_isDonation = true`.

### Image Handling

- **Maximum:** 3 images
- **Sources:** Camera or Gallery (via `image_picker`)
- **Quality:** 1080×1080 max, 85% JPEG quality
- **Upload path:** `posts/{userId}/post_{timestamp}/image_{index}.jpg` in Firebase Storage
- **Display:** Horizontal scrollable thumbnails (100×100px, 12px radius) with remove (×) button
- **Counter:** Shows `{count}/3` (turns red at max)
- **Camera/Gallery buttons:** Glass-morphic styling, hidden when at 3 images

### Location Features

**Auto-Detection (`_autoDetectLocation`):**

| Priority | Source | Details |
|----------|--------|---------|
| 1 | `IpLocationService.detectLocation()` | Cascades: GPS low accuracy → GPS medium accuracy → ip-api.com → ipinfo.io → ipwho.is |
| 2 | Firestore user profile | `users/{uid}` → latitude/longitude. **Skips stale data:** rejects "Mountain View" city (emulator default) and near-zero coordinates |
| 3 | Manual entry | Error snackbar prompts user to enter manually |

**Manual Search with Autocomplete:**
- Debounced at 400ms
- Minimum 2 characters
- Uses `GeocodingService.searchLocation(query, userLat, userLng)` with proximity bias
- Dropdown suggestions (max height 220px) show area, city, state
- Selecting a suggestion updates coordinates and text

**"Detect" Button:** Blue text with `Icons.my_location_rounded`, shows spinner while detecting.

**At Submission Time:** If coordinates still null, retries fresh GPS + Firestore lookup. **Blocks post creation** if all attempts fail.

### Speech-to-Text

- **Fields supported:** Title and Description only
- **Engine:** `speech_to_text` package
- **Locale:** `en_IN` (Indian English)
- **Listen:** 30 seconds max, 3-second pause detection
- **Partial results:** Shown in real-time (replaces text, not appends)
- **Visual when listening:** Red recording dot, 10 animated wave bars, red border on field container, recognized text or "Listening...", stop button
- **Toggle:** Tapping mic on same field stops; tapping on different field switches target

### Keywords / Highlights

- **Max:** 5 keywords
- **Display:** Blue-tinted chip pills (`#016CFF` at 18% alpha, 40% alpha border)
- **Add:** Glass text field + blue "+" button. Checks for empty and duplicates
- **Remove:** "X" icon on each chip with haptic feedback
- **Input hidden** when 5 keywords reached
- **Counter:** `{count}/5` next to label

### Donation Toggle

- Orange icon (`Icons.volunteer_activism_rounded`) when ON, grey when OFF
- Switch `activeThumbColor`: `Colors.orange`
- When toggled ON: clears price field, hides price section
- **Note:** `isDonation` in Firestore is derived from `_selectedPostType == 'Donation'`, not the toggle state directly

### Currency Selector

| Code | Symbol | Name |
|------|--------|------|
| INR | ₹ | Indian Rupee (default) |
| USD | $ | US Dollar |
| EUR | € | Euro |
| GBP | £ | British Pound |
| AED | د.إ | UAE Dirham |
| SAR | ﷼ | Saudi Riyal |

Dropdown with dark background (`#2D2D3A`), 16px border radius, max height 300px.

### Allow Calls Toggle

- Green icon (`Icons.call_rounded`, `AppColors.vibrantGreen`) when ON, grey when OFF
- Default: `true`
- When enabled: other users see call icon and can voice-call the creator

### Post Data Structure (written to Firestore)

```javascript
posts/{postId} = {
  title: string,
  description: string,
  originalPrompt: string,           // Same as title
  userId: string,
  userName: string,                 // Resolved: name → displayName → phone → 'User'
  userPhoto: string,                // Resolved: photoUrl → photoURL → profileImageUrl → ''
  isActive: true,
  createdAt: Timestamp,             // DateTime.now()
  updatedAt: Timestamp,             // DateTime.now()
  expiresAt: Timestamp,             // now + 30 days
  allowCalls: boolean,
  isDonation: boolean,              // _selectedPostType == 'Donation'
  currency: string,                 // 'INR', 'USD', etc.
  postType: string,                 // 'Services', 'Jobs', 'Products', 'Donation'
  subCategory: string,              // Selected sub-category or ''
  category: string,                 // subCategory ?? postType ?? 'Products'
  categories: string[],             // [postType, subCategory] (non-null only)
  keywords: string[],
  location: string,                 // City name
  offer: string,
  hashtags: [],                     // Always empty (placeholder)
  latitude: number,                 // GPS (guaranteed non-null)
  longitude: number,
  imageUrl: string,                 // First image URL
  images: string[],                 // All image URLs
  hasImage: true,                   // Only present when images exist
  price: number                     // Optional (only if parsed successfully)
}
```

**Important Notes:**
- This screen writes **directly to Firestore** — does NOT use `UnifiedPostService` or generate AI embeddings
- No `embedding` field is created
- No `intentAnalysis` field is generated
- `originalPrompt` is set to the title, not the full natural language input

### UI Theme

- **Background:** Dark gradient (`RGB(64,64,64)` → `RGB(0,0,0)`)
- **Header:** Darker gradient (`RGB(40,40,40)` → `RGB(64,64,64)`) with bottom white border
- **Input fields:** Glass-style with gradient (white 25% → 15% alpha), white border (30% alpha)
- **Primary accent:** `#016CFF` (keywords chips, add button, detect location, create button)
- **Create button:** Enabled: `#016CFF` with blue box shadow. Disabled: white 12% alpha
- **Fonts:** All Poppins throughout

### Firebase Schema

**Write — Create new post:**
```javascript
posts/{newPostId} = {
  userId: string,
  title: string,
  description: string,
  postType: string,           // "Products", "Services", "Jobs", "Donation"
  subCategory: string,
  images: string[],           // uploaded to Firebase Storage
  price: number,              // optional, absent if empty
  currency: string,           // "INR" default
  keywords: string[],         // max 5
  location: string,
  latitude: number,           // required — GPS coordinates
  longitude: number,
  allowCalls: bool,
  isActive: true,
  createdAt: serverTimestamp(),
  expiresAt: Timestamp(now + 30 days),
  originalPrompt: string,     // set to title
  hashtags: []
}
```

**Firebase Storage — Image upload:**
```javascript
posts/{userId}/post_{timestamp}/{filename}
→ uploadBytes() → getDownloadURL()
→ stored as string[] in post document 'images' field
```

---

## 4. Edit Post Screen

**File:** `lib/screens/near by/edit_post_screen.dart`
**Class:** `EditPostScreen` (StatefulWidget)
**Lines:** ~2340
**Purpose:** Pre-populated form to edit an existing post. Mirrors Create Post Screen functionality but loads existing data, handles image replacement, and supports backward compatibility for posts without the `postType` field.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `postId` | `String` | Yes | Firestore document ID of the post to edit |
| `postData` | `Map<String, dynamic>` | Yes | Current post data (pre-populates form, NOT re-fetched from Firestore) |

### Pre-population (in `_loadPostData`)

| Form Element | Source Key | Notes |
|-------------|------------|-------|
| `_titleController.text` | `postData['title']` | Default: `''` |
| `_descriptionController.text` | `postData['description']` | Default: `''` |
| `_priceController.text` | `postData['price']?.toString()` | Converted to string |
| `_locationController.text` | `postData['location']` | Default: `''` |
| `_offerController.text` | `postData['offer']` | Default: `''` |
| `_allowCalls` | `postData['allowCalls']` | Default: `true` |
| `_isDonation` | `postData['isDonation']` | Default: `false` |
| `_selectedCurrency` | `postData['currency']` | Default: `'INR'` |
| `_selectedPostType` | `postData['postType']` | Direct assignment |
| `_selectedSubCategory` | `postData['subCategory']` | Cleared to null if empty |
| `_detectedLat/_detectedLng` | `postData['latitude']/['longitude']` | Cast via `(num?)?.toDouble()` |
| `_keywords` | `postData['keywords']` | List<dynamic> → List<String>, skips empty/duplicates |
| `_existingImageUrls` | `postData['imageUrl']` + `postData['images']` | Merged, deduplicated |

**Backward Compatibility for Post Type:**
If `_selectedPostType` is null (older posts without the `postType` field), the code attempts to infer it from `post['categories']` (list) or `post['category']` (string) by checking against known post type names.

### Image Handling Differences from Create

- **Two separate lists:** `_existingImageUrls` (remote URLs) + `_selectedImages` (new local files)
- **Combined limit:** 3 total (`existing + new`)
- **Display:** Horizontal `ListView` showing existing images via `CachedNetworkImage` followed by new images via `Image.file`
- **Each image has an "X" remove button**
- **Upload:** Only new images are uploaded. Final array: `[...existingUrls, ...newUrls]`
- **Deletion handling:** If all images removed, uses `FieldValue.delete()` to remove both `imageUrl` and `images` fields from Firestore

### Form Validation

**Button-enabled check (`_isFormValid`):**
```
title.isNotEmpty && description.isNotEmpty && selectedPostType != null && (selectedImages.isNotEmpty || existingImageUrls.isNotEmpty)
```

**Note:** Location is NOT part of `_isFormValid` but IS enforced at submission time, which can lead to a confusing UX where the button appears active but the submit fails.

### Update Logic (Firestore Write)

**Method:** `_firestore.collection('posts').doc(postId).update(postData)`

**Updated fields:**
```javascript
{
  title, description,
  originalPrompt: title,                // Overwrites original AI prompt
  updatedAt: serverTimestamp(),
  expiresAt: now + 30 days,             // Resets expiry on every edit
  allowCalls, currency,
  isDonation: _selectedPostType == 'Donation',
  postType: _selectedPostType,
  subCategory: _selectedSubCategory ?? '',
  category: subCategory ?? postType ?? '',
  categories: [postType, subCategory],  // non-null only
  keywords, hashtags: [],               // Hashtags always reset to empty
  location, offer,
  latitude, longitude,                  // Guaranteed non-null
  imageUrl: firstUrl or FieldValue.delete(),
  images: allUrls or FieldValue.delete(),
  price: parsed or FieldValue.delete()  // Removed if empty
}
```

**Fields NOT updated (preserved from original):**
- `userId` — not touched
- `embedding` — **NOT regenerated** (matching quality may degrade for edited posts)
- `intentAnalysis` — not updated
- `createdAt` — not touched
- `isActive` — not touched
- `userName` / `userPhoto` — not updated

### All Other Features

Same as Create Post Screen:
- Speech-to-text per field (Title, Description only)
- Location auto-detect via `IpLocationService` + Firestore fallback + Mountain View filter
- Location search with autocomplete (400ms debounce, `GeocodingService`)
- Post Type & Sub-Category dialog pickers (identical data maps)
- Donation toggle, currency selector, allow calls toggle
- Keywords/Highlights (max 5 chips)
- Same glassmorphism UI theme
- Location hard-required at submission time

### Key Differences from Create

| Aspect | Create | Edit |
|--------|--------|------|
| Data source | Fresh (empty form) | Pre-populated from `postData` |
| Images | Only new local files | Existing URLs + new local files |
| Firestore op | `.add()` (new doc) | `.update()` (existing doc) |
| Empty price | Field absent | `FieldValue.delete()` |
| Empty images | Field absent | `FieldValue.delete()` |
| `originalPrompt` | Set to title | **Overwritten** with current title |
| `expiresAt` | 30 days from creation | **Reset** to 30 days from edit |
| `hashtags` | Empty array | **Reset** to empty array |
| PostType fallback | None (must select) | Backward compat inference from categories |
| Returns | `Navigator.pop(context, true)` | `Navigator.pop(context, true)` |

### Firebase Schema

**Update — Edit existing post:**
```javascript
posts/{postId}.update({
  title: string,
  description: string,
  postType: string,
  subCategory: string,
  images: string[],           // mix of existing URLs + new uploads
  price: number | FieldValue.delete(),
  currency: string,
  keywords: string[],
  location: string,
  latitude: number,
  longitude: number,
  allowCalls: bool,
  isActive: true,
  expiresAt: Timestamp(now + 30 days),   // reset on edit
  originalPrompt: string,                // overwritten with current title
  hashtags: []                           // reset to empty
})
```

**Firebase Storage — Image upload (same as Create):**
```javascript
posts/{userId}/post_{timestamp}/{filename}
→ existing URLs kept, new files uploaded
→ old images NOT deleted from Storage
```

---

## 5. Post Detail Screen

**File:** `lib/screens/near by/near_by_post_detail_screen.dart`
**Class:** `NearByPostDetailScreen` (StatefulWidget)
**Lines:** ~1501
**Purpose:** Full-detail view of a single post. Shows images (with zoom viewer), title, price/offer chips, category, description, keywords, and provides Chat + Voice Call actions. Adapts section headings and info chips based on the tab category. Supports restore/delete for soft-deleted posts.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `postId` | `String` | Yes | — | Firestore document ID |
| `post` | `Map<String, dynamic>` | Yes | — | Full post data map |
| `distanceText` | `String` | No | `''` | Pre-calculated distance (e.g., "1.2 km") |
| `isDeleted` | `bool` | No | `false` | If true, shows restore/delete buttons instead of chat/call |
| `tabCategory` | `String` | No | `'Products'` | Source tab category (Services, Jobs, Products, Donation) |

### Screen Layout

```
┌────────────────────────────────────────────────────┐
│  ←  [Avatar] Username  [📞]             [🔖]      │  ← Chat-style AppBar
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │         Image Grid (1–3 images)              │  │  ← Tap to open viewer
│  │   [gradient overlays: 6 edges/corners]       │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Post Title (22px bold)                            │
│                                                    │
│  [₹800] [Best Price] [📍 1.2 km]                  │  ← Info chips row
│                                                    │
│  Category                                          │  ← Section heading
│  ┌────────────┐ ┌────────────┐                     │
│  │ 📦 Electronics │ 📦 Gadgets │                   │  ← Category chips
│  └────────────┘ └────────────┘                     │
│                                                    │
│  Description                                       │  ← Section heading
│  ┌──────────────────────────────────────────────┐  │
│  │ Glass card with description text             │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Highlights                                        │  ← Section heading
│  ┌──────────────────────────────────────────────┐  │
│  │ [✓ keyword1] [✓ keyword2] [✓ keyword3]      │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
├────────────────────────────────────────────────────┤
│  [     💬 Chat     ]  [     📞 Call     ]          │  ← Bottom action bar (frosted glass)
└────────────────────────────────────────────────────┘
```

### Tab-Specific Section Headings

| Tab Category | Category Heading | Description Heading | Highlights Heading |
|-------------|-----------------|--------------------|--------------------|
| Services | Service Type | Service Details | Features |
| Jobs | Job Category | Job Description | Requirements |
| Donation | Donation Type | About Donation | Details |
| Products | Category | Description | Highlights |

### Tab-Specific Info Chips

| Tab | Chip 1 | Chip 2 | Chip 3 |
|-----|--------|--------|--------|
| **Services** | Price (currency + amount, blue) | "Available" (green check) | Distance |
| **Jobs** | Salary (currency + amount, blue) | Job Type (orange, from post data) | Distance |
| **Products** | Price (currency + amount, blue) or "Free" if donation | Offer text or "Best Price" (green) | Distance |
| **Donation** | "Free" (pink) | "Donation" (green) | Distance |

**Distance chip logic:**
- Own post → Shows location name (e.g., "Nagpur") with location pin icon
- Other user's post → Shows distance (e.g., "2.3 km") with `near_me` icon

**Currency mapping:**
- `USD` → `$` / `attach_money` icon
- `EUR` → `EUR` / `euro` icon
- `GBP` → `GBP` / `currency_pound` icon
- Default (INR) → `₹` / `currency_rupee` icon

### Image Grid Layout

| Number of Images | Layout |
|-----------------|--------|
| 1 | Single full-width image (16px corners) |
| 2 | Two side-by-side equal images (6px gap) |
| 3 | One large left (flex: 3, 60%) + two stacked right (flex: 2, 40%) |

**Grid height:** 280px with 6 gradient overlays (cinematic effect):
1. Left edge: 60px, black 70% → transparent
2. Right edge: 60px, black 70% → transparent
3. Top edge: 80px, black 75% → transparent
4. Bottom edge: 40px, black 35% → transparent
5. Top-left corner: 90×90px radial gradient
6. Top-right corner: 90×90px radial gradient

**Each image:** `CachedNetworkImage` with `fit: BoxFit.cover`, white border (25% alpha, 1.2px), rounded corners (12px).

**Category icon mapping for error/placeholder:**
- food → `restaurant`
- electronic/tech → `devices`
- house/property → `home`
- job/work → `work`
- sport → `sports`
- fashion/cloth → `checkroom`
- furniture → `weekend`
- transport/vehicle → `directions_car`
- default → `grid_view`

### Image Viewer

- Full-screen dialog (`Dialog.fullscreen`, `barrierColor: Colors.black87`)
- `PageView.builder` with `InteractiveViewer` (pinch-to-zoom) per page
- Image counter: `"2 / 3"` (Poppins white70 14px), only shown for multiple images
- Close button: circular black54 container with white border, top-right

### AppBar (Chat-style)

```
[← Back]  [Avatar] Username [📞]              [🔖 Save]
```

- **Back button:** iOS-style back arrow, returns `_isSaved` state
- **Center:** CircleAvatar (radius 15, white 70% border) + Username (Poppins 17px w600)
- **Call badge:** Green-tinted circle with phone icon — shown on OWN posts when `allowCalls` is enabled (indicator only)
- **Right:** Bookmark toggle (hidden for deleted posts) — filled when saved, outline when not

### Save/Bookmark Feature

- **Check on init:** Reads `users/{uid}/saved_posts/{postId}`
- **Save:** Creates document with `postId`, full `postData` copy, `savedAt: serverTimestamp()`
- **Unsave:** Deletes the document
- **Haptic:** `lightImpact()` on toggle
- **Returns `_isSaved`** to parent screen via `Navigator.pop` and `PopScope` for state sync

### Distance Computation

When `distanceText` is not provided:
1. Gets post coordinates from `post['latitude']` / `post['longitude']`
2. Gets user location:
   - **Primary:** Firestore `users/{uid}` document
   - **Fallback:** GPS via `Geolocator.getLastKnownPosition()` (checks permission first)
3. Haversine formula (Earth radius 6371 km)
4. Format: "X m" (< 1 km) or "X.X km" (≥ 1 km)

### Bottom Action Bar

**For other users' posts (`isDeleted == false`, not own post):**

| Button | Style | Width | Action |
|--------|-------|-------|--------|
| Chat | Blue gradient (`_accent` → `_accent` at 80%) | Expanded (full or half) | `_openChat()` |
| Call | Green gradient (#035C28 → #00E676) | Expanded (half) | `_makeVoiceCall()` |

- **Frosted glass bar:** `BackdropFilter` blur 20, black 50% bg, white 8% top border
- Chat always shown; Call only when `post['allowCalls'] != false`
- When calls disabled: Chat expands to full width
- **`_isActionLoading` guard** prevents double-tap (no visual indicator)

**For own posts:** No bottom bar shown (`SizedBox.shrink()`).

**For deleted posts (`isDeleted == true`):**

| Button | Style | Action |
|--------|-------|--------|
| Restore | Green gradient (#035C28 → #00E676) | `_restorePost()` → sets `isActive: true`, removes `deletedAt` |
| Delete Forever | Red gradient (shade700 → shade400) | `_permanentlyDeletePost()` → deletes document |

Both buttons: `HapticFeedback.mediumImpact()`, pop screen with `true` on success.
**Note:** No confirmation dialog — direct action from the bottom bar.

### Voice Call Flow

1. Guard: `_isActionLoading` prevents double-tap
2. Self-call check → "You cannot call yourself"
3. Fetch caller data from `users/{currentUserId}`
4. Fetch receiver data from `users/{receiverId}`
5. Create call document in `calls` collection:
   ```javascript
   {
     callerId, receiverId,
     callerName, callerPhoto,
     receiverName, receiverPhoto,
     participants: [callerId, receiverId],
     status: 'calling',
     type: 'audio',
     source: 'NearBy',
     timestamp: serverTimestamp(),
     createdAt: serverTimestamp()
   }
   ```
6. Send push notification: "Incoming Call - {name} is calling you"
7. Navigate to `VoiceCallScreen` with `isOutgoing: true`

### Chat Flow

1. Guard: `_isActionLoading` prevents double-tap
2. Self-chat check → "This is your own post"
3. Fetch receiver data from `users/{receiverId}`
4. Build `UserProfile` object
5. Navigate to `EnhancedChatScreen` with `source: 'NearBy'`

### Firebase Schema

**Read/Write — Save/Unsave bookmark:**
```javascript
// Check if saved
users/{uid}/saved_posts/{postId}.get()

// Save post
users/{uid}/saved_posts/{postId}.set({
  postId: string,
  postData: Map,              // full post data copy (denormalized)
  savedAt: serverTimestamp()
})

// Unsave post
users/{uid}/saved_posts/{postId}.delete()
```

**Read — User profile for call/chat:**
```javascript
users/{userId} {
  uid: string,
  name: string,
  email: string,
  photoUrl: string,
  bio: string,
  location: string,
  latitude: number,
  longitude: number
}
```

**Write — Create voice call:**
```javascript
calls/{newCallId} = {
  callerId: string,
  receiverId: string,
  callerName: string,
  callerPhoto: string,
  receiverName: string,
  receiverPhoto: string,
  participants: [callerId, receiverId],
  status: 'calling',
  type: 'audio',
  source: 'NearBy',
  timestamp: serverTimestamp(),
  createdAt: serverTimestamp()
}
```

**Update — Restore deleted post:**
```javascript
posts/{postId}.update({
  isActive: true,
  deletedAt: FieldValue.delete()
})
```

**Delete — Permanent delete:**
```javascript
posts/{postId}.delete()
```

---

## Screen Navigation Flow

```
MainNavigationScreen (Tab: Nearby)
│
└── NearByScreen (Feed with 4 category tabs)
    │
    ├── [📋 My Posts icon] → MyPostsScreen
    │   ├── My Posts tab → Post cards
    │   │   ├── [Edit] → EditPostScreen → (returns true on success)
    │   │   └── [Delete] → Soft delete confirmation dialog
    │   ├── Saved tab → Saved post cards
    │   │   └── [Bookmark] → Direct unsave (no dialog)
    │   └── Deleted tab → Deleted post cards (with auto-delete check)
    │       ├── [Restore] → Restore confirmation dialog
    │       └── [Delete Forever] → Permanent delete confirmation dialog
    │
    ├── [FAB "Create Post"] → CreatePostScreen
    │   └── (On success) → Returns to NearByScreen, re-subscribes to feed
    │
    ├── [Own Post Edit] → EditPostScreen (from feed card)
    │
    ├── [Own Post Delete] → Soft delete dialog (from feed card)
    │
    └── [Post Card Tap] → NearByPostDetailScreen (via _ExpandRoute slide-from-left)
        ├── [Chat] → EnhancedChatScreen (source: 'NearBy')
        ├── [Call] → VoiceCallScreen (isOutgoing: true)
        ├── [Bookmark] → Toggle save/unsave
        ├── [Image Tap] → Full-screen image viewer (PageView + InteractiveViewer)
        ├── [Restore] → Direct restore (deleted posts, no dialog)
        └── [Delete Forever] → Direct permanent delete (deleted posts, no dialog)
```

---

## Firestore Collections Used

| Collection | Screen(s) | Operation | Query Details |
|-----------|----------|-----------|---------------|
| `posts` | NearByScreen | Read (stream) | `where('isActive', true).orderBy('createdAt', desc).limit(100).snapshots()` |
| `posts` | NearByScreen | Read (pagination) | `where('isActive', true).orderBy('createdAt', desc).startAfterDocument().limit(100)` |
| `posts` | MyPostsScreen | Read (stream) | `where('userId', ==).where('isActive', true).orderBy('createdAt', desc).limit(50)` |
| `posts` | MyPostsScreen | Read (stream) | `where('userId', ==).where('isActive', false).orderBy('createdAt', desc).limit(100)` |
| `posts` | CreatePostScreen | Write | `.add(postData)` |
| `posts` | EditPostScreen | Update | `.doc(postId).update(postData)` |
| `posts` | NearByScreen, MyPostsScreen | Update | Soft delete: `{isActive: false, deletedAt: serverTimestamp()}` |
| `posts` | MyPostsScreen, DetailScreen | Update | Restore: `{isActive: true, deletedAt: FieldValue.delete()}` |
| `posts` | MyPostsScreen, DetailScreen | Delete | Permanent delete / auto-delete batch |
| `users/{uid}/saved_posts` | NearByScreen | Read | `.limit(500).get()` |
| `users/{uid}/saved_posts` | MyPostsScreen | Read (stream) | `.orderBy('savedAt', desc).limit(50)` |
| `users/{uid}/saved_posts` | DetailScreen | Read/Write/Delete | Check, save (with full postData copy), unsave |
| `users` | All screens | Read | Fetch user profile data (name, photo, location) |
| `calls` | DetailScreen | Write | Create call signaling documents |
| Firebase Storage | Create/Edit | Write | Upload images to `posts/{userId}/post_{timestamp}/` |

---

## Shared UI Patterns

### Glassmorphism Cards

Used across all screens for info cards, confirmation dialogs, bottom bars:
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
    ),
  ),
)
```

### Floating Card Animation

Shared `_FloatingCard` widget in NearByScreen and MyPostsScreen:
- Vertical float: -6px to +6px
- Duration: 1600–2700ms (staggered: `1600 + (index % 6) * 220`)
- Phase stagger: `(index * 0.17) % 1.0`
- Curve: `easeInOut`, repeats with reverse

### Page Transition (`_ExpandRoute`)

Custom slide-from-left transition used in NearByScreen and MyPostsScreen:
- Forward: 2000ms, reverse: 1600ms
- Slide from `Offset(-1.0, 0.0)` + fade from 0.5 → 1.0
- Curves: `easeOutQuart` (forward), `easeInQuart` (reverse)

### Background Gradient

All screens use the same dark gradient:
```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
)
```

### Typography

- Font family: `Poppins` throughout
- Screen titles: 20px bold white
- Card titles: 13px w700 white
- Body: 14px white/grey
- Prices: 13px `#00D67D` (green) bold
- Badges: 10px white bold/extra-bold
- Sub-category: 12px white 85% alpha

### Haptic Feedback

- `lightImpact()`: Tab switches, bookmark toggles, keyword add/remove, button taps
- `mediumImpact()`: Voice search start, restore/delete actions in detail screen

### Action Button Style

Shared across NearByScreen and MyPostsScreen:
- `ClipOval` with `BackdropFilter` blur (8)
- Background: `#016CFF` at 85% alpha
- White border at 40% alpha
- Icon: 15px white
- `HitTestBehavior.opaque` for reliable hit testing

### Post Type Colors

Used in sub-category badges on cards and in dialog pickers:

| Post Type | Badge Color | Gradient |
|-----------|------------|----------|
| Services | Blue (#3B82F6) | #3B82F6 → #60A5FA |
| Jobs | Indigo (#6366F1) | #6366F1 → #818CF8 |
| Products | Orange (#F97316) | #F97316 → #FB923C |
| Donation | Pink (#EC4899) | #EC4899 → #F472B6 |

---

## Key Business Rules

1. **10 km radius:** Only posts within 10 km of the user appear in the feed (changed from earlier 5 km)
2. **One post per user:** Feed shows only the latest post per user + content-based deduplication
3. **Images required:** Posts without images are hidden from the feed AND all My Posts tabs
4. **30-day auto-delete:** Soft-deleted posts are permanently removed after 30 days (client-side, on Deleted tab visit)
5. **30-day expiry:** New/edited posts get `expiresAt` set to 30 days from creation/edit
6. **No self-interaction:** Users cannot chat with or call themselves
7. **Donation isolation:** Donation posts only appear in the Donation tab, never in other tabs
8. **Call permission:** Users can toggle `allowCalls` per post to control voice call availability
9. **Privacy:** Location shows city name only, not exact GPS coordinates
10. **Max 3 images:** Create and Edit screens limit to 3 images per post
11. **Location hard-required:** Posts cannot be created/updated without GPS coordinates
12. **Structured categories:** Post type (4 options) + sub-category (type-specific options) via dialog pickers — no free-text categories
13. **Max 5 keywords:** Highlights/keywords capped at 5 per post
14. **No AI embedding on create/edit:** Direct Firestore write without `UnifiedPostService` — posts lack `embedding` and `intentAnalysis` fields
15. **Mountain View filter:** Emulator default location and near-zero coordinates are rejected during location detection
16. **Static data persistence:** Feed data cached in static fields — survives widget rebuilds, no loading spinner on revisit
17. **Saved posts are denormalized:** Full post data copy stored in `saved_posts` subcollection (can become stale)
18. **Own posts in feed:** Users can edit/delete their own posts directly from the feed via top-right action buttons
