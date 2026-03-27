    Simplify business screens and add support/docs infrastructure
    
    - Add business support screen and coming soon widgets
    - Remove unused specialized business tabs (automotive, fitness, real estate, etc.)
    - Add business rules documentation and Maestro test config
    - Update dependencies and plugin registrants
    
    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

diff --git a/.claude/business.md b/.claude/business.md
new file mode 100644
index 0000000..389926a
--- /dev/null
+++ b/.claude/business.md
@@ -0,0 +1,826 @@
+# Business Discovery, Booking & Analytics — End-to-End Feature Spec
+
+## What This Document Is
+
+A complete feature specification for the Supper app's business-to-consumer flow — from discovery to booking to reviews to analytics. Use this as the single source of truth when implementing or extending business features.
+
+---
+
+## 1. Business Discovery via Home Search
+
+### Goal
+When a user types a natural-language query (e.g., "water bottle near me", "haircut under 500", "yoga classes this weekend"), businesses with matching products or services appear as results in the home/discovery screen — alongside regular user posts.
+
+### How It Works (Current Architecture)
+
+```
+User types: "water bottle near me"
+       ↓
+UnifiedPostService.createPost()
+       ↓
+Gemini AI analyzes intent:
+  - action_type: "seeking"
+  - domain: "marketplace"
+  - complementary_intents: ["selling water bottles", "retail store"]
+  - keywords: ["water", "bottle", "near"]
+       ↓
+Generates 768-dim embedding
+       ↓
+UnifiedMatchingService compares against ALL posts (including business sync posts)
+       ↓
+Business "ShopName" has catalog item "Steel Water Bottle ₹299"
+  → Their synthetic offering post matches with score ≥ 0.60
+       ↓
+Result surfaces in discovery feed
+```
+
+### What Needs to Work
+
+| Requirement | Detail |
+|-------------|--------|
+| **Search results show businesses** | When a user's seeking intent matches a business's catalog/services, that business card appears in results |
+| **Business card in results** | Shows: business name, soft label, cover image, rating stars, distance (if location available), top matching item(s) with price |
+| **Tap business card** | Opens business profile with full catalog, hours, reviews, "Book" / "Message" / "Connect" actions |
+| **Real-time sync** | When a business adds/removes catalog items, their discovery post updates automatically (via `syncBusinessPost`) |
+| **Location-aware** | Businesses closer to the user get a location bonus in matching score |
+
+### Key Files
+
+- `lib/services/unified_post_service.dart` — intent analysis + business post sync
+- `lib/services/unified_matching_service.dart` — scoring algorithm
+- `lib/screens/home/` — discovery/home screen
+- `lib/screens/near_by/near_by_screen.dart` — nearby tab with Businesses filter
+
+---
+
+## 2. Business Profile (Public View)
+
+### What a Customer Sees
+
+```
+┌─────────────────────────────────────┐
+│  [Cover Image]                      │
+│  ShopName              ★ 4.5 (128)  │
+│  "Retail Store"        ● Open Now   │
+│  📍 1.2 km away                     │
+├─────────────────────────────────────┤
+│  [Message]  [Book Service]  [Call]  │
+├─────────────────────────────────────┤
+│  About                              │
+│  "Quality household items..."       │
+│                                     │
+│  Catalog (12 items)                 │
+│  ┌──────┐ ┌──────┐ ┌──────┐       │
+│  │ Item │ │ Item │ │ Item │       │
+│  │ ₹299 │ │ ₹499 │ │ ₹150 │       │
+│  └──────┘ └──────┘ └──────┘       │
+│                                     │
+│  Hours                              │
+│  Mon-Fri: 9:00 AM - 5:00 PM       │
+│  Sat: 10:00 AM - 4:00 PM          │
+│                                     │
+│  Reviews (128)                      │
+│  ★★★★★ "Great service..."          │
+│  ★★★★☆ "Good products but..."      │
+└─────────────────────────────────────┘
+```
+
+### Data Sources (Already Exist)
+
+- `BusinessProfile` in `lib/models/user_profile.dart` — name, description, softLabel, hours, rating, socialLinks
+- `CatalogItem` in `lib/models/catalog_item.dart` — products/services with price, image, availability
+- `ReviewModel` in `lib/models/review_model.dart` — ratings, text, owner response
+- `CatalogService` — fetch catalog, track views
+- `ReviewService` — fetch reviews, rating summary
+
+---
+
+## 3. Booking Flow (End-to-End)
+
+### Customer Journey
+
+```
+Step 1: Customer finds business via search or discovery
+Step 2: Taps a service/product in catalog
+Step 3: Sees service detail: name, price, duration, description
+Step 4: Taps "Book Now"
+Step 5: Selects date + time slot
+Step 6: Adds optional notes ("I need it for 2 people")
+Step 7: Confirms booking → status: PENDING
+Step 8: Business owner gets notification
+Step 9: Owner confirms → status: CONFIRMED (customer notified)
+Step 10: Service delivered → Owner marks COMPLETED
+Step 11: Customer gets prompt to leave a review
+```
+
+### Booking States
+
+```
+PENDING ──→ CONFIRMED ──→ COMPLETED
+   │             │
+   └──→ CANCELLED ←──┘
+```
+
+### Data Model (Already Exists)
+
+`BookingModel` in `lib/models/booking_model.dart`:
+- `customerId`, `customerName`, `customerPhone`
+- `businessOwnerId`, `businessName`
+- `serviceId`, `serviceName`, `servicePrice`
+- `bookingDate`, `bookingTime`, `duration`
+- `status` (pending / confirmed / completed / cancelled)
+- `notes`, `cancelReason`
+
+### Service (Already Exists)
+
+`BookingService` in `lib/services/booking_service.dart`:
+- `createBooking()` — creates + notifies owner
+- `updateBookingStatus()` — validates transitions + notifies both parties
+- `streamOwnerBookings()` — real-time list for business owner
+- `streamCustomerBookings()` — real-time list for customer
+- `getBookingsByDate()` — calendar view
+- `getPendingCount()` — badge count
+
+### What Needs UI
+
+| Screen | Purpose | Status |
+|--------|---------|--------|
+| **Booking creation form** | Date/time picker, notes, confirm | Needs building |
+| **Customer bookings list** | "My Bookings" — filter by status | Needs building |
+| **Owner bookings dashboard** | Incoming bookings, accept/reject | Needs building |
+| **Booking detail** | Full info + status actions | Needs building |
+
+### Firestore Structure
+
+```
+bookings/{bookingId}
+  - customerId, businessOwnerId
+  - serviceId, serviceName, servicePrice
+  - status, bookingDate, bookingTime, duration
+  - notes, cancelReason
+  - createdAt, updatedAt
+```
+
+---
+
+## 4. Reviews System (End-to-End)
+
+### Flow
+
+```
+Booking COMPLETED
+       ↓
+Customer gets "Leave a Review" prompt (notification or in-app)
+       ↓
+Customer rates 1-5 stars + optional category ratings
+  (Communication, Quality, Value)
+       ↓
+Writes review text + optional photos
+       ↓
+Review saved → rating summary auto-recalculated
+       ↓
+Business owner notified → can respond
+       ↓
+Response visible publicly under review
+```
+
+### Data Model (Already Exists)
+
+`ReviewModel` in `lib/models/review_model.dart`:
+- `rating` (1-5), `categoryRatings` (Communication, Quality, Value)
+- `reviewText`, `images`
+- `businessResponse`, `responseDate`
+- `isVerifiedPurchase` (linked to completed booking)
+
+### Service (Already Exists)
+
+`ReviewService` in `lib/services/review_service.dart`:
+- `submitReview()` — saves + recalculates summary
+- `addOwnerResponse()` — owner replies
+- `streamReviews()` — real-time list
+- `getRatingSummary()` — aggregate stats
+- `hasUserReviewed()` — prevent duplicates
+
+### What Needs UI
+
+| Screen | Purpose | Status |
+|--------|---------|--------|
+| **Review submission form** | Stars, text, photos, category ratings | Needs building |
+| **Reviews list on business profile** | Show all reviews with owner responses | Needs building |
+| **Owner review management** | See reviews, write responses | Needs building |
+| **Review prompt** | Post-booking completion nudge | Needs building |
+
+---
+
+## 5. Business Analytics Dashboard
+
+### What the Business Owner Sees
+
+```
+┌─────────────────────────────────────┐
+│  Business Dashboard                 │
+├─────────────────────────────────────┤
+│                                     │
+│  Profile Views      Catalog Views   │
+│     1,247              3,891        │
+│                                     │
+│  Total Bookings     Pending         │
+│       89               3            │
+│                                     │
+│  Average Rating     Total Reviews   │
+│    ★ 4.5               128          │
+│                                     │
+│  Enquiries                          │
+│       45                            │
+│                                     │
+├─────────────────────────────────────┤
+│  Recent Activity                    │
+│  • New booking from Rahul (2m ago)  │
+│  • Review from Priya ★★★★★ (1h)    │
+│  • Profile viewed by 5 people today │
+└─────────────────────────────────────┘
+```
+
+### Data Sources (Already Exist)
+
+| Metric | Source |
+|--------|--------|
+| `profileViews` | `BusinessProfile.profileViews` — incremented by `CatalogService.logProfileView()` |
+| `catalogViews` | `BusinessProfile.catalogViews` — incremented by `CatalogService.incrementBusinessStat()` |
+| `enquiryCount` | `BusinessProfile.enquiryCount` |
+| `averageRating` | `BusinessProfile.averageRating` — auto-updated by `ReviewService` |
+| `totalReviews` | `BusinessProfile.totalReviews` |
+| Profile view details | `users/{userId}/profileViews/` subcollection |
+| Booking counts | `BookingService.streamOwnerBookings()` |
+| Pending count | `BookingService.getPendingCount()` |
+
+### What Needs UI
+
+| Screen | Purpose | Status |
+|--------|---------|--------|
+| **Analytics overview** | Stats cards + recent activity | Needs building |
+| **Profile viewers list** | Who viewed your profile | Exists: `profile_views_screen.dart` |
+| **Booking calendar view** | Bookings by date | Needs building |
+
+---
+
+## 6. Profile Views Tracking
+
+### How It Works (Already Implemented)
+
+```
+Customer views business profile
+       ↓
+CatalogService.logProfileView(profileOwnerId, viewerId, viewerName, viewerPhotoUrl)
+       ↓
+Creates document in users/{ownerId}/profileViews/{viewId}
+       ↓
+Increments businessProfile.profileViews counter
+       ↓
+Owner sees view count on dashboard + viewer list
+```
+
+### Existing UI
+
+`ProfileViewsScreen` in `lib/screens/business/simple/profile_views_screen.dart`:
+- Total view count
+- List of viewers with name, photo, timestamp
+
+---
+
+## 7. Notification Triggers
+
+| Event | Who Gets Notified | Message |
+|-------|-------------------|---------|
+| New booking created | Business owner | "New booking from {customerName}" |
+| Booking confirmed | Customer | "{businessName} confirmed your booking" |
+| Booking cancelled | Other party | "Booking cancelled by {name}" |
+| Booking completed | Customer | "Your booking is complete. Leave a review!" |
+| New review | Business owner | "New {n}-star review from {name}" |
+| Owner response to review | Reviewer | "{businessName} responded to your review" |
+| Profile viewed | (Optional) | "{viewerName} viewed your profile" |
+| Connection request | Business owner | "New connection request from {name}" |
+
+---
+
+## 8. Full User Journey (End-to-End Example)
+
+```
+1. DISCOVERY
+   Rahul opens Supper → types "water bottle near me"
+   → AI understands: seeking, marketplace, keywords: water bottle
+   → Matches against business posts
+   → "AquaStore" appears (has "Steel Water Bottle ₹299" in catalog)
+   → Shows: business card with name, rating, distance, matching item
+
+2. BUSINESS PROFILE
+   Rahul taps AquaStore card
+   → Sees full business profile: catalog, hours, reviews
+   → Profile view logged for AquaStore owner
+   → Browses catalog, sees "Steel Water Bottle ₹299"
+
+3. BOOKING (for services) or MESSAGING (for products)
+   Option A — Service: Rahul taps "Book" on a service item
+   → Picks date/time → adds notes → confirms
+   → Booking created (PENDING) → AquaStore owner notified
+
+   Option B — Product: Rahul taps "Message"
+   → Conversation created with business chat metadata
+   → Discusses product availability, delivery, etc.
+
+4. BUSINESS OWNER SIDE
+   AquaStore owner opens app → sees notification badge
+   → Goes to Bookings dashboard → sees Rahul's booking
+   → Taps "Confirm" → Rahul gets notified
+   → Later marks "Completed" → Rahul prompted to review
+
+5. REVIEW
+   Rahul gets "Leave a Review" prompt
+   → Rates 5 stars, writes "Great quality bottle!"
+   → Review saved → AquaStore rating recalculated
+   → Owner sees review → writes response: "Thank you Rahul!"
+
+6. ANALYTICS
+   AquaStore owner checks dashboard:
+   → Profile views: 1,247 (+15 today)
+   → Catalog views: 3,891
+   → Bookings this month: 23
+   → Average rating: 4.5 (128 reviews)
+   → Recent: "Rahul left a 5-star review"
+```
+
+---
+
+## 9. Implementation Status
+
+### Backend (Models + Services) — COMPLETE
+
+| Component | Model | Service | Notes |
+|-----------|-------|---------|-------|
+| Business Profile | ✅ `BusinessProfile` | ✅ `AccountTypeService` | Complete — enableBusinessMode, updateBusinessProfile, feature gating |
+| Catalog | ✅ `CatalogItem` | ✅ `CatalogService` | Complete — CRUD, image upload, stats, auto syncBusinessPost |
+| Bookings | ✅ `BookingModel` | ✅ `BookingService` | Complete — create, stream, status transitions, notifications |
+| Reviews | ✅ `ReviewModel` + `RatingSummary` | ✅ `ReviewService` | Complete — submit, stream, owner response, auto-recalculate |
+| Profile Views | ✅ (subcollection) | ✅ `CatalogService.logProfileView` | Complete — logs view, increments counter, skips self |
+| Matching | ✅ Post model | ✅ `UnifiedMatchingService` | Complete — 5-factor scoring, business posts included |
+| Notifications | ✅ | ✅ `NotificationService` | Integrated in booking/review services |
+| Conversations | ✅ `ConversationModel` | ✅ `ConnectionService` | Business chat metadata (isBusinessChat, businessId, businessName) |
+
+### Frontend (Screens + UI) — What Exists vs What's Missing
+
+| Screen | File | Status | What's Built |
+|--------|------|--------|-------------|
+| Business hub (owner) | `business_hub_screen.dart` | ✅ Exists | Quick actions grid (Catalog, Bookings, Reviews, Views), catalog grid, profile completeness bar |
+| Catalog management | `catalog_management_screen.dart` | ✅ Exists | Search, grid/list toggle, animated FAB, type filter, pagination |
+| Catalog item detail | `catalog_item_detail.dart` | ✅ Exists | DraggableScrollableSheet modal, image, price, "Request Booking" + "Contact" buttons |
+| Booking form | `booking_request_screen.dart` | ✅ Exists | Name, phone, date picker, time picker, notes — calls BookingService.createBooking() |
+| Owner bookings | `bookings_screen.dart` | ✅ Exists | 3 tabs (Pending/Confirmed/History), booking cards with actions, StreamBuilder |
+| Reviews list | `reviews_screen.dart` | ✅ Exists | Rating summary header + distribution bars, review cards, CustomScrollView |
+| Write review | `write_review_screen.dart` | ✅ Exists | Star rating, review text, submit — calls ReviewService.submitReview() |
+| Profile views | `profile_views_screen.dart` | ✅ Exists | Total count, viewer list with avatar/name/timestamp |
+| **Business card in home search** | `home_screen.dart` | ❌ Missing | Results don't differentiate business posts — no business card UI |
+| **Public business profile** | N/A | ❌ Missing | No customer-facing profile screen (only owner hub) |
+| **Customer bookings list** | N/A | ❌ Missing | No "My Bookings" for customers |
+| **Analytics dashboard** | `business_hub_screen.dart` | ❌ Missing | Hub has quick actions but no stats/metrics section |
+| **Review response UI** | `reviews_screen.dart` | ⚠️ Partial | Cards exist but owner response writing may need work |
+
+---
+
+## 10. Firestore Collections Summary
+
+```
+users/{userId}
+  ├── accountType: "personal" | "business"
+  ├── businessProfile: { businessName, softLabel, hours, rating, ... }
+  ├── verification: { status, verifiedAt }
+  ├── ratingSummary: { averageRating, totalReviews, distribution }
+  │
+  ├── catalog/{itemId}        — Products & services
+  └── profileViews/{viewId}   — Who viewed this profile
+
+posts/{postId}                — All posts (user + business sync)
+  ├── userId, title, description
+  ├── embedding[768], keywords
+  ├── intentAnalysis: { action_type, domain, ... }
+  └── metadata: { isBusinessPost: true }
+
+bookings/{bookingId}          — All bookings
+  ├── customerId ↔ businessOwnerId
+  ├── serviceId, serviceName, servicePrice
+  ├── status, bookingDate, bookingTime
+  └── createdAt, updatedAt
+
+business_reviews/{reviewId}   — All reviews
+  ├── reviewerId ↔ businessId
+  ├── rating, categoryRatings, reviewText
+  └── isVerifiedPurchase
+
+conversations/{conversationId}
+  ├── participantIds, isBusinessChat
+  ├── businessId, businessName
+  └── messages/{messageId}
+
+connection_requests/{requestId}
+notifications/{notificationId}
+```
+
+---
+
+## 11. Key Constraints
+
+1. **No hardcoded categories** — AI determines intent dynamically
+2. **Catalog sync is automatic** — `syncBusinessPost()` called after every catalog change
+3. **Max 100 catalog items** per business
+4. **Bookings are immutable** — only status/notes/cancelReason can change
+5. **Reviews prevent duplicates** — one review per customer per business
+6. **Rating auto-recalculates** — no manual intervention needed
+7. **Profile views skip self-views** — owner viewing own profile doesn't count
+8. **Business hours are timezone-aware** — `isCurrentlyOpen` uses device time
+9. **Always use `limit()` on Firestore queries** — never unbounded reads
+10. **Use `FirebaseProvider`** — never create new Firebase instances
+
+---
+
+## 12. Detailed Implementation Plan (Phase-by-Phase)
+
+### PHASE 1: Business Discovery in Home Search
+
+**Goal:** When user searches "water bottle near me", business results appear with matching catalog items.
+
+**File to modify:** `lib/screens/home/home_screen.dart`
+
+**What happens now:**
+- User types query → `UnifiedIntentService` processes → matches returned as `MatchResult` list
+- Results displayed as generic profile cards — no distinction between personal and business posts
+- Business sync posts (`metadata.isBusinessPost == true`) exist but render identically to personal results
+
+**What to add:**
+1. In the result rendering section, check `matchResult.postData['metadata']['isBusinessPost'] == true`
+2. If business post: render a **BusinessResultCard** widget instead of generic card
+3. BusinessResultCard layout:
+   ```
+   ┌──────────────────────────────────────┐
+   │ [Cover Image / placeholder gradient] │
+   │ ● Open Now                           │
+   ├──────────────────────────────────────┤
+   │ 🏪 Business Name        ★ 4.5 (128) │
+   │ Retail Store  •  1.2 km away         │
+   ├──────────────────────────────────────┤
+   │ Matching items:                      │
+   │ ┌─────────┐ ┌─────────┐             │
+   │ │ 📦 Item │ │ 📦 Item │             │
+   │ │ ₹299    │ │ ₹499    │             │
+   │ └─────────┘ └─────────┘             │
+   ├──────────────────────────────────────┤
+   │     [View Business]  [Message]       │
+   └──────────────────────────────────────┘
+   ```
+4. Data to fetch: use `matchResult.userId` to get `UserProfile` (has businessProfile embedded)
+5. Fetch matching catalog items: `CatalogService().getAvailableItems(userId, limit: 3)`
+6. On tap → navigate to `PublicBusinessProfileScreen(userId: matchResult.userId)`
+
+**Card colors:** dark: `Color(0xFF1C1C1E)`, light: `Colors.white`, border radius: 12
+**Open badge:** Green `#22C55E` for open, Red for closed
+**Rating stars:** Amber `#F59E0B`
+
+**DO NOT change:** Any service logic, matching algorithm, or post creation flow.
+
+---
+
+### PHASE 2: Public Business Profile Screen
+
+**Goal:** Customer-facing profile showing catalog, hours, reviews, and action buttons.
+
+**New file:** `lib/screens/business/simple/public_business_profile_screen.dart`
+
+**Data loading on init:**
+```dart
+// All from existing services — NO new service methods needed
+final userProfile = await FirebaseFirestore.instance.collection('users').doc(userId).get();
+final catalogItems = await CatalogService().getAvailableItems(userId, limit: 50);
+final ratingSummary = await ReviewService().getRatingSummary(userId);
+// Log the profile view (skips self)
+CatalogService().logProfileView(userId, currentUserId, currentUserName, currentUserPhoto);
+```
+
+**Screen layout (CustomScrollView with Slivers):**
+```
+SliverAppBar (expandedHeight: 200)
+  └── Cover image (CachedNetworkImage) with gradient overlay
+  └── Business name + soft label overlay
+  └── Open/Closed badge (from BusinessHours.isCurrentlyOpen)
+  └── Rating: ★ {averageRating} ({totalReviews} reviews)
+
+SliverToBoxAdapter — Action Row
+  └── [Message] [Book Service] [Call]
+  └── Message → ConnectionService or direct conversation creation
+  └── Call → url_launcher tel:{contactPhone}
+
+SliverToBoxAdapter — About Section
+  └── description text, address, business hours
+
+SliverToBoxAdapter — "Catalog ({count} items)" header
+SliverGrid — Catalog items (2-column grid using CatalogCardWidget)
+  └── Each item taps → CatalogItemDetail.show() (existing modal)
+
+SliverToBoxAdapter — "Reviews ({count})" header
+SliverList — Top 3 reviews + "See All Reviews →" link
+  └── StreamBuilder using ReviewService().streamReviews(userId)
+
+SliverToBoxAdapter — Business Hours section
+  └── 7-day schedule from businessProfile.hours
+  └── Highlight today's hours, show "Open Now" / "Closed"
+```
+
+**Existing patterns to follow:**
+- Card style: match `business_hub_screen.dart` (dark: `0xFF1C1C1E`, radius: 12)
+- Typography: `AppTextStyles` (Poppins, standard hierarchy)
+- Image: `CachedNetworkImage` with placeholder
+- Snackbar: `SnackBarHelper.showSuccess/Error`
+- Dark/light: `Theme.of(context).brightness == Brightness.dark`
+
+---
+
+### PHASE 3: Booking Creation Flow
+
+**Existing file:** `lib/screens/business/simple/booking_request_screen.dart` — ALREADY BUILT
+
+**What it has:**
+- Customer name (pre-filled from auth)
+- Phone number (optional)
+- Date picker (min: tomorrow, max: 90 days)
+- Time picker
+- Notes textarea
+- Validation + loading state
+- Calls `BookingService().createBooking(booking)`
+- Success/error snackbar
+
+**What may need enhancement:**
+1. Pre-populate service details (name, price, duration) from the tapped `CatalogItem`
+2. Show service summary at top of form (image, name, price, duration)
+3. After successful booking → navigate to customer bookings list (Phase 4)
+4. Verify it passes all required `BookingModel` fields correctly
+
+**Entry point:** From `CatalogItemDetail` → "Request Booking" button (already wired)
+
+---
+
+### PHASE 4: Customer Bookings List ("My Bookings")
+
+**New file:** `lib/screens/business/simple/customer_bookings_screen.dart`
+
+**Data:** `BookingService().streamCustomerBookings(currentUserId)` — returns Stream<List<BookingModel>>
+
+**Layout (match existing bookings_screen.dart pattern):**
+```
+TabBar: [Upcoming] [Completed] [Cancelled]
+
+Upcoming tab (pending + confirmed):
+  StreamBuilder → filter status == pending || confirmed
+  Each card:
+    ┌────────────────────────────────────┐
+    │ Business Name          [Status]    │
+    │ Service: Haircut                   │
+    │ 📅 March 15, 2026  🕐 2:00 PM    │
+    │ ₹500                              │
+    │                    [Cancel Booking]│
+    └────────────────────────────────────┘
+
+Completed tab:
+  Each card + [Leave Review] button (if !hasUserReviewed)
+  Check: ReviewService().hasUserReviewed(businessOwnerId, currentUserId)
+
+Cancelled tab:
+  Simple list with cancel reason if available
+```
+
+**Status badge colors:**
+- Pending: Amber `#F59E0B`
+- Confirmed: Blue `#3B82F6`
+- Completed: Green `#22C55E`
+- Cancelled: Red `#EF4444`
+
+**Navigation access:**
+- Add "My Bookings" option in user profile screen or via a menu item
+- Also accessible after booking creation (Phase 3 success flow)
+
+---
+
+### PHASE 5: Owner Bookings Dashboard
+
+**Existing file:** `lib/screens/business/simple/bookings_screen.dart` — ALREADY BUILT
+
+**What it has:**
+- 3 tabs: Pending | Confirmed | History
+- StreamBuilder with `BookingService().streamOwnerBookings()`
+- Booking cards with customer avatar, name, phone, service, date/time
+- Status chips (color-coded)
+- Action buttons on cards
+
+**What may need enhancement:**
+1. Verify Pending tab has [Confirm] + [Decline] buttons calling `BookingService().updateBookingStatus()`
+2. Verify Confirmed tab has [Mark Complete] button
+3. Add pending count badge to "Bookings" quick action in `business_hub_screen.dart`
+   - Use `BookingService().getPendingCount(ownerId)` for badge count
+4. Verify notifications fire on status changes (already in BookingService)
+
+---
+
+### PHASE 6: Review Submission & Display
+
+**Existing files:**
+- `write_review_screen.dart` — Star rating + text + submit (BUILT)
+- `reviews_screen.dart` — Rating summary + review list (BUILT)
+
+**What may need enhancement:**
+
+1. **Write review screen:**
+   - Add optional category ratings (Communication, Quality, Value) — star rows
+   - Link to booking if applicable: `isVerifiedPurchase: true`, `serviceId`, `serviceName`
+   - Check `ReviewService().hasUserReviewed()` before showing — prevent duplicates
+   - Photo upload option (ReviewModel supports `images` list)
+
+2. **Reviews on public profile (Phase 2):**
+   - Show top 3 reviews inline on public business profile
+   - "See All" → navigate to full `ReviewsScreen`
+   - Show owner responses (`businessResponse`) below each review
+
+3. **Owner review management:**
+   - In `reviews_screen.dart`, add "Reply" button on each review card
+   - Reply form → calls `ReviewService().addOwnerResponse(reviewId, text)`
+   - Show existing response with edit capability
+
+---
+
+### PHASE 7: Business Analytics Dashboard
+
+**File to modify:** `lib/screens/business/simple/business_hub_screen.dart`
+
+**What exists now:**
+- Quick action grid (Catalog, Bookings, Reviews, Views icons)
+- Catalog grid below
+- Profile completeness bar
+- Business name/label/status header
+
+**What to add — Analytics section above quick actions:**
+```
+┌─────────────────────────────────────┐
+│  📊 Business Overview               │
+│                                     │
+│  ┌─────────┐ ┌─────────┐          │
+│  │  Views  │ │ Catalog │          │
+│  │  1,247  │ │  3,891  │          │
+│  └─────────┘ └─────────┘          │
+│  ┌─────────┐ ┌─────────┐          │
+│  │ Bookings│ │ Pending │          │
+│  │    89   │ │    3    │          │
+│  └─────────┘ └─────────┘          │
+│  ┌─────────┐ ┌─────────┐          │
+│  │ Rating  │ │ Reviews │          │
+│  │  ★ 4.5  │ │   128   │          │
+│  └─────────┘ └─────────┘          │
+└─────────────────────────────────────┘
+```
+
+**Data sources (all existing, no new methods):**
+- `businessProfile.profileViews` — profile view count
+- `businessProfile.catalogViews` — catalog view count
+- `businessProfile.averageRating` — star rating
+- `businessProfile.totalReviews` — review count
+- `BookingService().getPendingCount(userId)` — pending bookings
+- `BookingService().streamOwnerBookings(userId)` — total booking count
+
+**Stat card colors:**
+- Views: Purple `#8B5CF6`
+- Catalog: Blue `#3B82F6`
+- Bookings: Green `#22C55E`
+- Reviews: Amber `#F59E0B`
+- Pending: Red badge overlay
+
+**Badge counts on quick action icons:**
+- Bookings icon → show pending count as red badge
+- Reviews icon → optionally show new review count
+
+---
+
+## 13. Code Patterns Reference
+
+### Theme check (REQUIRED on every screen)
+```dart
+final isDark = Theme.of(context).brightness == Brightness.dark;
+final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
+final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
+final textColor = isDark ? Colors.white : Colors.black;
+final subtitleColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6);
+```
+
+### Card pattern
+```dart
+Container(
+  decoration: BoxDecoration(
+    color: cardColor,
+    borderRadius: BorderRadius.circular(12),
+    boxShadow: isDark ? null : [
+      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2)),
+    ],
+  ),
+)
+```
+
+### Service singleton usage
+```dart
+// CORRECT — factory constructor returns singleton
+CatalogService().getAvailableItems(userId);
+BookingService().createBooking(booking);
+ReviewService().submitReview(review);
+ReviewService().addOwnerResponse(reviewId, text);
+
+// WRONG — never do this
+final service = CatalogService();  // This IS fine (returns singleton via factory)
+// But never use: CatalogService._internal() or new CatalogService()
+```
+
+### StreamBuilder pattern
+```dart
+StreamBuilder<List<BookingModel>>(
+  stream: BookingService().streamOwnerBookings(userId, filter: 'pending'),
+  builder: (context, snapshot) {
+    if (snapshot.connectionState == ConnectionState.waiting) {
+      return const Center(child: CircularProgressIndicator());
+    }
+    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
+      return _buildEmptyState();
+    }
+    final items = snapshot.data!;
+    return ListView.builder(...);
+  },
+)
+```
+
+### Navigation pattern
+```dart
+Navigator.push(context, MaterialPageRoute(
+  builder: (_) => PublicBusinessProfileScreen(userId: businessUserId),
+));
+```
+
+### Snackbar feedback
+```dart
+SnackBarHelper.showSuccess(context, 'Booking confirmed!');
+SnackBarHelper.showError(context, 'Failed to submit review');
+```
+
+### Mounted check in async
+```dart
+await someAsyncOperation();
+if (!mounted) return;
+setState(() { ... });
+```
+
+### Empty state pattern
+```dart
+Widget _buildEmptyState(String icon, String title, String subtitle) {
+  return Center(
+    child: Column(
+      mainAxisAlignment: MainAxisAlignment.center,
+      children: [
+        Icon(icon, size: 48, color: Colors.grey),
+        SizedBox(height: 16),
+        Text(title, style: AppTextStyles.titleMedium),
+        SizedBox(height: 8),
+        Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey)),
+      ],
+    ),
+  );
+}
+```
+
+---
+
+## 14. Firestore Security Rules (Verified)
+
+All rules exist in `firestore.rules`:
+
+| Collection | Read | Create | Update | Delete |
+|-----------|------|--------|--------|--------|
+| `bookings/{bookingId}` | Customer OR owner | Customer only (customerId == auth.uid) | Either party — status/notes/cancelReason only | ❌ Never |
+| `business_reviews/{reviewId}` | Any authenticated | Reviewer (rating 1-5 validated) | Reviewer edits OR owner adds response only | Reviewer only |
+| `users/{id}/catalog/{itemId}` | Any authenticated | Owner only | Owner only | Owner only |
+| `users/{id}/profileViews/{viewId}` | Owner only | Any authenticated | ❌ Never | ❌ Never |
+| `businesses/{businessId}` | Any authenticated | Owner only | Owner only | Owner only |
+
+**Immutable booking fields (protected by rules):** customerId, businessOwnerId, serviceId, servicePrice
+
+---
+
+## 15. Files Changed Per Phase (Quick Reference)
+
+| Phase | Files Modified | Files Created |
+|-------|---------------|---------------|
+| 1 | `home_screen.dart` | `lib/widgets/business_result_card.dart` (optional) |
+| 2 | — | `lib/screens/business/simple/public_business_profile_screen.dart` |
+| 3 | `booking_request_screen.dart` (enhance) | — |
+| 4 | `main_navigation_screen.dart` or profile screen (add entry point) | `lib/screens/business/simple/customer_bookings_screen.dart` |
+| 5 | `bookings_screen.dart` (verify actions), `business_hub_screen.dart` (badge) | — |
+| 6 | `write_review_screen.dart` (enhance), `reviews_screen.dart` (reply UI) | — |
+| 7 | `business_hub_screen.dart` (add analytics section) | — |
