## 15. Testing Strategy

### Test Summary

| Metric | Value |
|--------|-------|
| **Total Test Cases** | **161** |
| Unit Tests (models) | 146 |
| Widget Tests | 6 |
| Service Tests | 10 |
| Integration Tests | 5 |
| Test Files | 11 |
| Test Helper Files | 1 |

### Test Structure

```
test/
├── test_helpers.dart                          # Firebase mock setup (0 tests)
├── widget_test.dart                           # App shell rendering (6 tests)
├── models/
│   ├── booking_model_test.dart                # BookingModel (12 tests)
│   ├── catalog_item_test.dart                 # CatalogItem (12 tests)
│   ├── conversation_model_test.dart           # ConversationModel (18 tests)
│   ├── extended_user_profile_test.dart        # ExtendedUserProfile (22 tests)
│   ├── post_model_test.dart                   # PostModel (30 tests)
│   ├── review_model_test.dart                 # ReviewModel (16 tests)
│   └── user_profile_test.dart                 # UserProfile (30 tests)
└── services/
    └── account_type_service_test.dart         # AccountTypeService (10 tests)

integration_test/
└── scroll_performance_test.dart               # Performance (5 tests)
```

### Test Infrastructure

| Package | Purpose |
|---------|---------|
| flutter_test | Widget and unit testing framework |
| integration_test | Integration test driver |
| mockito | Mock object generation |
| fake_cloud_firestore | Firestore mock for testing |

### Test Helpers (`test_helpers.dart`)

```dart
setupFirebaseCoreMocks()    // Mocks Firebase Core, Auth, Firestore via MethodChannel
tearDownFirebaseCoreMocks()  // Cleanup mocked platform channels
// Also mocks SharedPreferences for theme/token persistence
```

---

### Detailed Test Cases by File

#### 1. Widget Tests — `widget_test.dart` (6 tests)

**Group: App Widget Tests**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | App shell renders correctly | MaterialApp, Scaffold, "Supper App" text found |
| 2 | ProviderScope wraps MaterialApp correctly | ProviderScope and MaterialApp both in widget tree |
| 3 | Bottom navigation bar structure test | 4 nav items: Discover, Messages, Networking, Profile with correct icons |
| 4 | Navigation bar tap changes index | Tapping tabs changes displayed text (Tab 0 → Tab 1 → Tab 3) |
| 5 | Loading indicator renders correctly | CircularProgressIndicator renders |
| 6 | Error screen structure test | Error icon, error text, and retry button all render |

---

#### 2. BookingModel Tests — `booking_model_test.dart` (12 tests)

**Group: BookingStatus**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses all statuses | pending, confirmed, completed, cancelled all parse correctly |
| 2 | fromString defaults to pending | null and unknown strings → BookingStatus.pending |

**Group: formattedDate**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | formats January correctly | DateTime(2024, 1, 15) → "Jan 15, 2024" |
| 4 | formats December correctly | DateTime(2024, 12, 25) → "Dec 25, 2024" |
| 5 | formats single-digit day | DateTime(2024, 3, 5) → "Mar 5, 2024" |

**Group: statusLabel**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 6 | returns correct labels for all statuses | Pending, Confirmed, Completed, Cancelled labels match |

**Group: timeAgo**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | just now for less than 1 minute | < 60 seconds → "Just now" |
| 8 | minutes ago | 30 minutes → "30m ago" |
| 9 | hours ago | 5 hours → "5h ago" |
| 10 | days ago | 3 days → "3d ago" |
| 11 | falls back to formattedDate after 7 days | 10 days → returns formattedDate string |

**Group: copyWith**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 12 | preserves unchanged fields | copyWith(status) updates status, preserves all other fields |

---

#### 3. CatalogItem Tests — `catalog_item_test.dart` (12 tests)

**Group: CatalogItemType**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses service | 'service' → CatalogItemType.service |
| 2 | fromString maps legacy booking to service | 'booking' → CatalogItemType.service (backwards compat) |
| 3 | fromString defaults to product | 'product', null, 'unknown' all → CatalogItemType.product |

**Group: formattedPrice**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 4 | null price returns Contact for price | null price → "Contact for price" |
| 5 | INR uses rupee symbol | 500 INR → "₹500" |
| 6 | USD uses dollar symbol | 25 USD → "$25" |
| 7 | whole number omits decimals | 100.0 INR → "₹100" |
| 8 | fractional price shows 2 decimals | 99.99 INR → "₹99.99" |
| 9 | unknown currency uses currency code | 50 EUR → "EUR50" |

**Group: copyWith**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | preserves unchanged fields | copyWith(name) updates name, preserves others |
| 11 | can update multiple fields | copyWith(price, currency, isAvailable) updates all three |

**Group: defaults**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 12 | default values are correct | currency=INR, type=product, isAvailable=true, viewCount=0, isFeatured=false, tags=[] |

---

#### 4. ConversationModel Tests — `conversation_model_test.dart` (18 tests)

**Group: getOtherParticipantId**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | returns the other participant | user-1 → user-2, user-2 → user-1 |
| 2 | returns empty string when only self | Single participant → '' |

**Group: getDisplayName**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | returns other participant name for 1-on-1 | user-1 sees "Bob", user-2 sees "Alice" |
| 4 | returns group name for group chat | isGroup=true → "Team Chat" |
| 5 | returns Group Chat when group has no name | isGroup=true, no name → "Group Chat" |
| 6 | returns Unknown User when not in names map | Missing participant → "Unknown User" |

**Group: getDisplayPhoto**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | returns other participant photo for 1-on-1 | user-1 → bob.jpg |
| 8 | returns group photo for group chat | isGroup=true → groupPhoto URL |
| 9 | returns null for group without photo | isGroup=true, no photo → null |

**Group: unread messages**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | hasUnreadMessages true when count > 0 | unreadCount=3 → true |
| 11 | hasUnreadMessages false when count is 0 | unreadCount=0 → false |
| 12 | hasUnreadMessages false when user not in map | Missing user → false |
| 13 | getUnreadCount returns correct count | count=5 → 5 |
| 14 | getUnreadCount returns 0 for missing user | Missing → 0 |

**Group: typing**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | isUserTyping true when typing | isTyping=true → true |
| 16 | isUserTyping false when not typing | isTyping=false → false |
| 17 | isUserTyping false for missing user | Missing → false |

**Group: business chat**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 18 | isBusinessChat returns true with metadata flag | metadata['isBusinessChat']=true → true |

*Additional business chat tests:* isBusinessChat false without metadata, business getters extract from metadata (businessId, businessName, businessLogo, businessSenderId), getDisplayNameWithBusiness shows business/personal name based on sender, getDisplayPhotoWithBusiness shows logo or falls back to participant photo, copyWith preserves unchanged fields.

---

#### 5. ExtendedUserProfile Tests — `extended_user_profile_test.dart` (22 tests)

**Group: displayLocation**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | returns city when set | city='Mumbai' → 'Mumbai' |
| 2 | returns location when city is null | city=null → 'Maharashtra' |
| 3 | returns Location not set when both null | both null → 'Location not set' |
| 4 | returns Location not set when city is empty | city='' → 'Location not set' |

**Group: formattedDistance**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 5 | returns null when distance is null | null → null |
| 6 | returns meters when < 1 km | 0.5 km → '500 m away' |
| 7 | returns km when >= 1 km | 3.7 km → '3.7 km away' |
| 8 | rounds meters to nearest integer | 0.123 km → '123 m away' |

**Group: hasConnectionType**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 9 | returns true when type is present | 'friendship' in list → true |
| 10 | returns false when type is absent | 'dating' not in list → false |

**Group: activityNames**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 11 | returns list of activity names | [Activity(Running), Activity(Swimming)] → ['Running', 'Swimming'] |
| 12 | returns empty list when no activities | null → [] |

**Group: helper getters**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 13 | isBusiness returns true for business type | accountType=business → isBusiness=true |
| 14 | isPersonal returns true for personal type | default → isPersonal=true |
| 15 | isVerifiedAccount checks verification | verified → true, unverified → false |
| 16 | isPendingVerification checks pending | pending → true |

**Group: fromMap**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 17 | parses legacy string activities | ['Running', 'Yoga'] → string list |
| 18 | parses map activities | [{'name': 'Swimming'}] → name extracted |
| 19 | display name falls back to phone | name='' → uses phone number |
| 20 | display name falls back from User to phone | name='User' → uses phone number |
| 21 | extracts business name from businessProfile | businessName='My Shop', category='Retail' |
| 22 | extracts verification status | verification.status='verified' → VerificationStatus.verified |

---

#### 6. PostModel Tests — `post_model_test.dart` (30 tests)

**Group: matchesIntent** (16 intent-matching test cases)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | offering matches seeking | offering ↔ seeking = true |
| 2 | selling matches buying | selling ↔ buying = true |
| 3 | giving matches requesting | giving ↔ requesting = true |
| 4 | lost matches found | lost ↔ found = true |
| 5 | hiring matches job_seeking | hiring ↔ job_seeking = true |
| 6 | renting matches rent_seeking | renting ↔ rent_seeking = true |
| 7 | symmetric intents with same action type | is_symmetric=true, same action → true |
| 8 | free vs paid exchange incompatibility | free offering ↔ paid seeking = false |
| 9 | equity vs paid exchange incompatibility | equity ↔ paid = false |
| 10 | same non-symmetric action type | selling ↔ selling = false |
| 11 | neutral action type always matches | neutral ↔ any action = true |
| 12 | meetup matches meetup (legacy symmetric) | meetup ↔ meetup = true |
| 13 | dating matches dating (legacy symmetric) | dating ↔ dating = true |
| 14 | friendship matches friendship (legacy) | friendship ↔ friendship = true |
| 15 | connecting matches connecting (legacy) | connecting ↔ connecting = true |
| 16 | unrelated action types return false | hiring ↔ selling = false |

**Group: matchesPrice** (7 price-matching test cases)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 17 | both no price returns true | both null → true |
| 18 | seller price within buyer max | 50 within max=100 → true |
| 19 | seller price above buyer max | 150 > max=100 → false |
| 20 | seller price within buyer min-max range | 75 within [50, 100] → true |
| 21 | seller price below buyer min | 30 < min=50 → false |
| 22 | reversed roles: buyer range includes seller | seller=80, buyer max=100 → true |
| 23 | only one side has price | one null → true |

**Group: computed getters** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 24 | primaryIntent returns from analysis | analysis['primary_intent'] → getter |
| 25 | primaryIntent falls back to originalPrompt | no analysis → originalPrompt |
| 26 | actionType from analysis | analysis['action_type'] → getter |
| 27 | actionType defaults to neutral | missing → 'neutral' |
| 28 | searchKeywords from analysis | ['plumber', 'repair', 'pipe'] |
| 29 | categoryDisplay formats domain | 'home_services' → 'Home Services' |
| 30 | emotionalTone defaults to casual | missing → 'casual' |

---

#### 7. ReviewModel Tests — `review_model_test.dart` (16 tests)

**Group: RatingSummary** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | empty factory creates zeroed summary | distribution[5]=0, totalReviews=0 |
| 2 | getPercentage returns 0 when no reviews | empty → 0% |
| 3 | getPercentage calculates correct distribution | 5-star=50%, 4-star=30%, 1-star=5% |
| 4 | getPercentage returns 0 for missing rating | 3-star missing → 0% |
| 5 | fromMap parses string keys to int | {'5': 25} → distribution[5]=25 |
| 6 | toMap converts int keys to string | distribution[5]=10 → {'5': 10} |
| 7 | fromMap/toMap round-trip | round-trip preserves all values |

**Group: formattedDate** (7 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 8 | minutes ago | 15 min → '15 min ago' |
| 9 | hours ago | 3 hours → '3 hours ago' |
| 10 | yesterday | 1 day → 'Yesterday' |
| 11 | days ago | 4 days → '4 days ago' |
| 12 | weeks ago | 14 days → '2 weeks ago' |
| 13 | months ago | 60 days → '2 months ago' |
| 14 | years ago | 400 days → '1 years ago' |

**Group: copyWith & defaults** (2 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | copyWith preserves unchanged fields | rating updated, other fields preserved |
| 16 | default values correct | images=[], isVerifiedPurchase=false, isVisible=true, isFlagged=false |

---

#### 8. UserProfile Tests — `user_profile_test.dart` (30 tests)

**Group: AccountType** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | fromString parses business variants | 'business', 'Business', 'business account' → business |
| 2 | fromString defaults to personal | null, 'unknown', '' → personal |
| 3 | displayName returns correct labels | personal → 'Personal Account', business → 'Business Account' |

**Group: AccountStatus** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 4 | fromString parses all statuses | 'suspended', 'pending_verification' parse correctly |
| 5 | fromString defaults to active | null, 'unknown' → active |
| 6 | displayName returns correct labels | active → 'Active', pendingVerification → 'Pending Verification' |

**Group: VerificationStatus** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | fromString parses all statuses | 'pending', 'verified', 'rejected' parse correctly |
| 8 | fromString defaults to none | null, 'xyz' → none |
| 9 | displayName returns correct labels | none → 'Not Verified', verified → 'Verified' |

**Group: DayHours** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 10 | formatted shows open-close times | '09:00' - '18:00' → '09:00 - 18:00' |
| 11 | formatted shows Closed when isClosed | isClosed=true → 'Closed' |
| 12 | formatted shows Not set when null | null times → 'Not set' |
| 13 | fromMap creates correct instance | map → open='10:00', close='22:00' |
| 14 | toMap round-trips correctly | round-trip preserves values |

**Group: BusinessHours** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 15 | defaultHours creates Mon-Fri 9-18, Sat 10-16, Sun closed | Schedule matches expected defaults |
| 16 | fromMap creates schedule from nested map | monday open='08:00', tuesday isClosed=true |
| 17 | toMap round-trips correctly | round-trip preserves schedule |

**Group: BusinessProfile** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 18 | fromMap with null returns empty profile | null → businessName=null, profileViews=0, isLive=false |
| 19 | fromMap handles legacy field names | companyName → businessName, industry → softLabel |
| 20 | fromMap prefers new field names over legacy | New field names override legacy |
| 21 | copyWith preserves unchanged fields | Updates businessName, preserves rest |
| 22 | isCurrentlyOpen delegates to hours | No hours → false |

**Group: VerificationData** (3 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 23 | fromMap with null returns default | null → status=none, verifiedAt=null |
| 24 | fromMap parses status correctly | 'verified' → VerificationStatus.verified |
| 25 | toMap round-trips status | pending → 'pending' |

**Group: UserProfile** (5 tests)

| # | Test Name | Assertions |
|---|-----------|-----------|
| 26 | isBusiness true when businessProfile set | businessProfile set → true |
| 27 | isBusiness false when null | null → false |
| 28 | isVerifiedAccount checks verification | verified → true, unverified → false |
| 29 | copyWith preserves unchanged fields | Updates name, preserves email and uid |
| 30 | id defaults to uid | id == uid |

---

#### 9. AccountTypeService Tests — `account_type_service_test.dart` (10 tests)

**Group: getAccountFeatures**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | personal account has limited features | canBuySell=true, maxPosts=5, verifiedBadge=false, portfolio=false, analytics=false |
| 2 | business account has full features | maxPosts=-1 (unlimited), verifiedBadge=true, portfolio=true, analytics=true, maxTeamMembers=10 |

**Group: isFeatureAvailable**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 3 | personal cannot access portfolio | portfolio → false |
| 4 | business can access portfolio | portfolio → true |
| 5 | personal can buy/sell | canBuySell → true |
| 6 | unknown feature returns false | 'nonexistent' → false for both types |

**Group: getPostLimit**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 7 | personal limit is 5 | personal → 5 |
| 8 | business limit is -1 (unlimited) | business → -1 |

**Group: getAccountTypeInfo**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 9 | personal account info | name='Personal Account', icon='person', color is int |
| 10 | business account info | name='Business Account', icon='business', color is int |

---

#### 10. Integration Tests — `scroll_performance_test.dart` (5 tests)

**Group: Performance Tests**

| # | Test Name | Assertions |
|---|-----------|-----------|
| 1 | Chat list scroll performance | 5 scroll cycles (up/down fling) complete in < 3000ms |
| 2 | Message list rendering performance | Message list scrolls smoothly after tapping chat tile |
| 3 | Navigation performance | Tab navigation across 3 tabs completes in < 2000ms |
| 4 | Image loading performance | Images render, count > 0 after 2-second load wait |
| 5 | All tabs navigation possible | BottomNavigationBar has ≥ 3 items |

---

### Test Coverage Matrix

```
┌─────────────────────────┬───────┬────────┬───────────┬──────────┬─────────┐
│ Model / Area            │ Parse │ Format │ Serialize │ Compute  │ Copy    │
├─────────────────────────┼───────┼────────┼───────────┼──────────┼─────────┤
│ BookingModel            │  ✓    │  ✓     │           │  ✓       │  ✓      │
│ CatalogItem             │  ✓    │  ✓     │           │          │  ✓      │
│ ConversationModel       │       │        │           │  ✓       │  ✓      │
│ ExtendedUserProfile     │  ✓    │  ✓     │  ✓        │  ✓       │         │
│ PostModel               │       │        │           │  ✓       │         │
│ ReviewModel             │  ✓    │  ✓     │  ✓        │          │  ✓      │
│ UserProfile             │  ✓    │  ✓     │  ✓        │  ✓       │  ✓      │
│ AccountTypeService      │       │        │           │  ✓       │         │
├─────────────────────────┼───────┼────────┼───────────┼──────────┼─────────┤
│ Widget (App shell)      │       │        │           │  ✓       │         │
│ Integration (Perf)      │       │        │           │  ✓       │         │
└─────────────────────────┴───────┴────────┴───────────┴──────────┴─────────┘

Legend: Parse = enum/string parsing, Format = display formatting,
        Serialize = fromMap/toMap round-trip, Compute = computed getters/logic,
        Copy = copyWith preservation
```

### Recommended Test Expansion

#### Widget Testing (Priority: High)

| Widget | Test Areas |
|--------|-----------|
| SafeCircleAvatar | Fallback rendering, rate-limit handling |
| CatalogCardWidget | Compact vs normal, availability badge |
| ChatMessageBubble | Sent vs received, read receipts |
| VoiceOrb | State transitions, animation states |
| MatchCardWithActions | Score display, action button callbacks |
| GlassTextField | Input handling, search variant |

#### Feature Testing (Priority: High)

| Feature | Test Areas |
|---------|-----------|
| Authentication | Login/signup flows, OTP verification, device session |
| Post Creation | Intent analysis mock, embedding generation |
| Matching | Score calculation, threshold filtering |
| Chat | Message sending, typing indicators, media |
| Business | Catalog CRUD, booking status changes |

#### Integration Testing (Priority: Medium)

| Flow | Test Areas |
|------|-----------|
| End-to-End Auth | Splash → Login → Home |
| Post & Match | Create post → Find matches → View results |
| Chat Flow | Open conversation → Send message → Receive |
| Business Flow | Enable business → Add catalog → Receive booking |

---

