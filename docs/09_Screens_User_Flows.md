## 9. Screens & User Flows

### Complete Screen Inventory (62 screens)

#### Authentication Flow (6 screens)

| Screen | File | Purpose |
|--------|------|---------|
| SplashScreen | login/splash_screen.dart | 3-second animated launch |
| OnboardingScreen | login/onboarding_screen.dart | 4-page feature carousel |
| ChooseAccountTypeScreen | login/choose_account_type_screen.dart | Account type selection |
| LoginScreen | login/login_screen.dart | Email/phone/Google auth |
| ForgotPasswordScreen | login/forgot_password_screen.dart | 3-step password reset |
| ChangePasswordScreen | login/change_password_screen.dart | Password change (logged in) |

#### Home & Navigation (10 screens)

| Screen | File | Purpose |
|--------|------|---------|
| MainNavigationScreen | home/main_navigation_screen.dart | 5-tab root container |
| HomeScreen | home/home_screen.dart | AI post feed + discovery |
| ConversationsScreen | home/conversations_screen.dart | Chats/Groups/Calls tabs |
| LiveConnectTabScreen | home/live_connect_tab_screen.dart | People discovery |
| NearByScreen | home/near_by_screen.dart | Location-based feed |
| NearByPostsScreen | home/near_by_posts_screen.dart | Area-specific posts |
| ProfileWithHistoryScreen | home/profile_with_history_screen.dart | User profile + history |
| EditPostScreen | home/edit_post_screen.dart | Create/edit posts |
| VoiceAssistantScreen | home/voice_assistant_screen.dart | Voice AI interface |

#### E-Commerce (7 screens)

| Screen | File | Purpose |
|--------|------|---------|
| ProductDetailScreen | home/product/product_detail_screen.dart | Product view |
| SeeAllProductsScreen | home/product/see_all_products_screen.dart | Product catalog |
| CheckoutScreen | home/product/checkout_screen.dart | Cart + checkout |
| OrderSummaryScreen | home/product/order_summary_screen.dart | Order review |
| ConfirmingOrderScreen | home/product/confirming_order_screen.dart | Order processing |
| OrderTrackingScreen | home/product/order_tracking_screen.dart | Real-time tracking |
| MyOrdersScreen | home/product/my_orders_screen.dart | Order history |

#### Messaging (10 screens)

| Screen | File | Purpose |
|--------|------|---------|
| EnhancedChatScreen | chat/enhanced_chat_screen.dart | 1-on-1 messaging |
| GroupChatScreen | chat/group_chat_screen.dart | Group messaging |
| CreateGroupScreen | chat/create_group_screen.dart | Create group chat |
| GroupInfoScreen | chat/group_info_screen.dart | Group settings |
| MediaGalleryScreen | chat/media_gallery_screen.dart | 1-on-1 media gallery |
| GroupMediaGalleryScreen | chat/group_media_gallery_screen.dart | Group media gallery |
| PhotoViewerDialog | chat/photo_viewer_dialog.dart | Full-screen image viewer |
| VideoPlayerScreen | chat/video_player_screen.dart | Video playback |
| AudioPlayerDialog | chat/audio_player_dialog.dart | Voice message player |
| LinkPreviewDialog | chat/link_preview_dialog.dart | URL preview |

#### Calling (8 screens)

| Screen | File | Purpose |
|--------|------|---------|
| VoiceCallScreen | call/voice_call_screen.dart | 1-on-1 voice call |
| VideoCallScreen | call/video_call_screen.dart | 1-on-1 video call |
| IncomingVideoCallScreen | call/incoming_video_call_screen.dart | Incoming video (disabled) |
| GroupAudioCallScreen | call/group_audio_call_screen.dart | Group audio conference |
| GroupVideoCallScreen | call/group_video_call_screen.dart | Group video (disabled) |
| IncomingGroupAudioCallScreen | call/incoming_group_audio_call_screen.dart | Incoming group audio |
| IncomingGroupVideoCallScreen | call/incoming_group_video_call_screen.dart | Incoming group video (disabled) |
| CallHistoryScreen | call/call_history_screen.dart | Call history log |

#### Business (14 screens)

| Screen | File | Purpose |
|--------|------|---------|
| BusinessHubScreen | business/simple/business_hub_screen.dart | Business dashboard |
| CatalogManagementScreen | business/simple/catalog_management_screen.dart | Catalog CRUD |
| CatalogItemForm | business/simple/catalog_item_form.dart | Add/edit catalog item |
| CatalogItemDetail | business/simple/catalog_item_detail.dart | Item detail view |
| BookingsScreen | business/simple/bookings_screen.dart | Booking management |
| BookingRequestScreen | business/simple/booking_request_screen.dart | Handle booking |
| CustomerBookingsScreen | business/simple/customer_bookings_screen.dart | My bookings (customer) |
| ReviewsScreen | business/simple/reviews_screen.dart | View reviews |
| WriteReviewScreen | business/simple/write_review_screen.dart | Write review |
| ProfileViewsScreen | business/simple/profile_views_screen.dart | Who viewed profile |
| BusinessInfoEdit | business/simple/business_info_edit.dart | Edit business info |
| BusinessHoursEdit | business/simple/business_hours_edit.dart | Edit operating hours |
| PublicBusinessProfileScreen | business/simple/public_business_profile_screen.dart | Public business page |
| NearbyBusinessesScreen | business/simple/nearby_businesses_screen.dart | Discover businesses |

#### Profile & Settings (11 screens)

| Screen | File | Purpose |
|--------|------|---------|
| ProfileViewScreen | profile/profile_view_screen.dart | View any user's profile |
| ProfileEditScreen | profile/profile_edit_screen.dart | Edit own profile |
| SettingsScreen | profile/settings_screen.dart | App settings |
| PersonalizationScreen | profile/personalization_screen.dart | Theme settings |
| DownloadsScreen | profile/downloads_screen.dart | Downloaded files |
| LibraryScreen | profile/library_screen.dart | Saved content |
| HelpCenterScreen | profile/help_center_screen.dart | FAQ & support |
| SafetyTipsScreen | profile/safety_tips_screen.dart | Safety guidelines |
| PrivacyPolicyScreen | profile/privacy_policy_screen.dart | Privacy policy |
| TermsOfServiceScreen | profile/terms_of_service_screen.dart | Terms of service |
| UpgradePlanScreen | profile/upgrade_plan_screen.dart | Premium plans |

#### Utility (2 screens)

| Screen | File | Purpose |
|--------|------|---------|
| LocationSettingsScreen | location/location_settings_screen.dart | Location preferences |
| PerformanceDebugScreen | performance_debug_screen.dart | Dev performance debug |

### Complete User Flow Map

```
APP LAUNCH
├── SplashScreen (3 sec)
├── AuthWrapper check
│   ├── [Not logged in] → OnboardingScreen → ChooseAccountType → LoginScreen
│   └── [Logged in] → MainNavigationScreen
│
MAIN APP (5 Tabs)
├── Tab 0: HomeScreen
│   ├── Create Post → EditPostScreen
│   ├── Voice → VoiceAssistantScreen
│   ├── Post card → ProfileViewScreen / EnhancedChatScreen
│   └── Menu → AppDrawer
│
├── Tab 1: ConversationsScreen
│   ├── Chats → EnhancedChatScreen
│   │   ├── Voice call → VoiceCallScreen → FloatingCallService
│   │   ├── Media → MediaGalleryScreen → PhotoViewer/VideoPlayer
│   │   └── Catalog → ProductDetailScreen
│   ├── Groups → GroupChatScreen
│   │   ├── Group info → GroupInfoScreen
│   │   ├── Group call → GroupAudioCallScreen
│   │   └── Create → CreateGroupScreen
│   └── Calls → CallHistoryScreen
│
├── Tab 2: LiveConnectTabScreen
│   ├── User card → ProfileDetailBottomSheet / ProfileViewScreen
│   ├── Chat → EnhancedChatScreen
│   └── Connect → ConnectionRequest
│
├── Tab 3: BusinessHubScreen
│   ├── Catalog → CatalogManagementScreen → CatalogItemForm
│   ├── Bookings → BookingsScreen → BookingRequestScreen
│   ├── Reviews → ReviewsScreen → WriteReviewScreen
│   ├── Profile Views → ProfileViewsScreen
│   └── Edit Info → BusinessInfoEdit / BusinessHoursEdit
│
├── Tab 4: NearByScreen
│   ├── Post card → ProfileViewScreen / EnhancedChatScreen
│   ├── Business card → PublicBusinessProfileScreen
│   └── Products → SeeAllProductsScreen → CheckoutScreen
│
PROFILE (from tab 4 or drawer)
├── ProfileWithHistoryScreen
│   ├── Edit → ProfileEditScreen
│   ├── Settings → SettingsScreen
│   │   ├── Change Password → ChangePasswordScreen
│   │   ├── Location → LocationSettingsScreen
│   │   ├── Personalization → PersonalizationScreen
│   │   ├── Terms/Privacy/Safety → Static pages
│   │   └── Logout → OnboardingScreen
│   └── Business toggle → Business setup
```

### Form Summary

| Screen | Form Type | Key Fields |
|--------|-----------|-----------|
| LoginScreen | Authentication | Email/Phone, Password, OTP (6 digits) |
| ForgotPasswordScreen | Recovery | Phone, OTP, New Password (3 steps) |
| EditPostScreen | Content | Title, Description, Price, Currency, Images, Hashtags |
| ProfileEditScreen | Profile | Name, Phone, Location, Gender, DOB, Photo, Bio |
| CatalogItemForm | Business | Type, Name, Description, Price, Duration, Image |
| CreateGroupScreen | Group | Group name, Member selection |
| WriteReviewScreen | Review | Rating (1-5 stars), Review text |
| BusinessInfoEdit | Business | Name, Description, Category, Contact, Logo |
| BusinessHoursEdit | Schedule | Per-day open/close times |
| CheckoutScreen | Commerce | Quantity, Address, Payment, Coupon |

### Detailed Screen Documentation

#### HomeScreen (`home/home_screen.dart` — 3,206 lines)

ChatGPT-style AI chat interface. Users type natural language, Gemini AI processes intent, returns matches and conversational responses.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_intentController` | TextEditingController | User input field |
| `_chatScrollController` | ScrollController | Auto-scroll to latest message |
| `_conversation` | List<Map<String, dynamic>> | Chat message history |
| `_currentChatId` | String? | Active chat session ID |
| `_isProcessing` | bool | Shows loading indicator while AI processes |
| `_isRecording` | bool | Voice recording active state |
| `_speech` | SpeechToText | Speech recognition engine |
| `_tts` | FlutterTts | Text-to-speech engine |
| `_likedMessages` / `_dislikedMessages` | Set<String> | Message feedback tracking |
| `_suggestions` | List<String> | AI-generated quick reply suggestions |
| `_matches` | List<Map<String, dynamic>> | Semantic match results |

**Widget Tree:**
```
Scaffold
└── SafeArea
    └── Stack
        ├── Background (image + dark overlay)
        └── Column
            ├── Search input (with focus state toggle)
            ├── Expanded chat conversation (ListView of message bubbles)
            │   ├── User message bubbles (right-aligned, gradient)
            │   ├── AI response bubbles (left-aligned, glassmorphic)
            │   └── Match cards (inline results with Chat/Profile buttons)
            └── Bottom action bar (voice mic, send button, TTS toggle)
```

**User Interactions:**
- Text submit → `_processIntent()` sends to Gemini AI → renders response + matches
- Voice recording → `_startVoiceRecording()` / `_finishRecording()` with speech-to-text
- TTS toggle → `_toggleTts(key, text)` reads AI response aloud
- Message like/dislike → tracks feedback in `_likedMessages` / `_dislikedMessages`
- Chat auto-save → persists conversation to Firestore on each message

**Navigation Targets:** EnhancedChatScreen, ProductDetailScreen, SeeAllProductsScreen, VoiceAssistantScreen, PublicBusinessProfileScreen

**Services:** UniversalIntentService, RealtimeMatchingService, GeminiService, FirebaseAuth, PhotoCacheService, CatalogService

---

#### EnhancedChatScreen (`chat/enhanced_chat_screen.dart` — 11,529 lines)

Full-featured 1-on-1 messaging screen with media, audio recording/playback, search, reactions, and reply threading.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_messageController` | TextEditingController | Message input |
| `_conversationId` | String? | Active conversation ID |
| `_replyToMessage` | MessageModel? | Reply threading target |
| `_editingMessage` | MessageModel? | Message being edited |
| `_isTyping` | bool | Typing indicator state |
| `_showEmojiPicker` | bool | Emoji panel visibility |
| `_isSearching` / `_searchQuery` | bool / String | In-chat message search |
| `_searchResults` / `_currentSearchIndex` | List / int | Search result navigation |
| `_loadedMessages` | List | Paginated message list |
| `_hasMoreMessages` | bool | Pagination state |
| `_audioRecorder` | FlutterSoundRecorder? | Voice message recording |
| `_audioPlayer` | FlutterSoundPlayer? | Voice message playback |
| `_isMultiSelectMode` | bool | Bulk message selection |
| `_selectedMessageIds` | Set<String> | Selected messages for bulk actions |
| `_todayImageCount` / `_todayVideoCount` / `_todayAudioCount` | int | Daily media send limits |

**Widget Tree:**
```
PopScope
└── Scaffold
    ├── AppBar (user name, online status, call/search/menu icons)
    └── Stack
        ├── Background (image + dark overlay)
        └── SafeArea → Column
            ├── Search bar (conditional, with prev/next navigation)
            ├── Expanded message list (StreamBuilder on Firestore)
            │   ├── Date separator headers
            │   ├── ChatMessageBubble (text, media, audio, reply preview)
            │   └── Typing indicator bubble
            ├── Reply/edit preview bar (conditional)
            ├── Emoji picker panel (conditional, bottom)
            └── Input area (text field, emoji toggle, mic, attachment, send)
```

**User Interactions:**
- Send text/media/audio messages with reply threading
- Voice recording with waveform visualization and duration timer
- In-chat search with result highlighting and prev/next navigation
- Message reactions, edit, delete, copy, forward
- Multi-select mode for bulk delete
- Typing indicators (real-time Firestore updates)
- Image/video picker with daily send limits

**Navigation Targets:** VoiceCallScreen, MediaGalleryScreen, PhotoViewerDialog, MainNavigationScreen

**Services:** ConversationService, HybridChatService, ActiveChatService, NotificationService, FirebaseStorage, ImagePicker, FlutterSoundRecorder/Player

---

#### LiveConnectTabScreen (`home/live_connect_tab_screen.dart` — 3,252 lines)

People discovery screen with 2 tabs: "Discover Connect" (browse nearby) and "Smart Connect" (AI-matched). Features 6 connection type groups with pagination.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_tabController` | TabController | 2-tab navigation |
| `_nearbyPeople` / `_filteredPeople` | List<Map> | User lists |
| `_selectedInterests` / `_selectedConnectionTypes` / `_selectedActivities` | List<String> | Active filters |
| `_currentUserLat` / `_currentUserLon` | double? | GPS coordinates |
| `_distanceFilter` | double | Max distance km |
| `_selectedGenders` | List<String> | Gender filter |
| `_connectionStatusCache` / `_requestStatusCache` | Map | Connection state cache |
| `_hasMoreUsers` / `_lastDocument` | bool / DocumentSnapshot? | Cursor pagination |
| `_expandedConnectionGroups` / `_expandedActivityGroups` | Map<String, bool> | Group UI expand state |

**Widget Tree:**
```
Scaffold
├── AppBar with TabBar (Discover Connect | Smart Connect)
└── TabBarView
    ├── Tab 1: Discover (grid/list of user cards with filters)
    │   ├── Filter bar (interests, distance, gender, connection type)
    │   ├── Search bar with voice search
    │   └── User card grid (CachedNetworkImage, badges, distance)
    └── Tab 2: Smart Connect (AI-curated matches)
```

**User Interactions:**
- Tab switch, search/voice search, filter toggles
- Connection request send → `_sendConnectionRequest(userId)`
- Profile view → ProfileDetailBottomSheet or ProfileViewScreen
- Swipe card actions (skip/connect)
- Scroll pagination (loads 20 users per page)

**Navigation Targets:** EnhancedChatScreen, ProfileViewScreen

**Services:** ConnectionService, LocationService, FirebaseAuth, FirebaseFirestore, VoiceSearchMixin

---

#### ConversationsScreen (`home/conversations_screen.dart` — 2,980 lines)

3-tab messaging hub: Chats (1-on-1), Groups, Calls. Real-time updates via Firestore StreamBuilder.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_tabController` | TabController | 3 tabs: Chats, Groups, Calls |
| `_searchQuery` | String | Filter conversations by name |
| `_userCache` | Map<String, Map> | Avoid repeated Firestore reads |
| `_isCallSelectionMode` | bool | Bulk call delete mode |
| `_individualCalls` / `_groupCalls` | List | Call history (lazy-loaded on Calls tab) |
| `_isConversationSelectionMode` | bool | Bulk conversation delete mode |

**Widget Tree:**
```
Scaffold
├── AppBar with TabBar (Chats | Groups | Calls)
│   └── Search icon + voice search
└── TabBarView
    ├── Tab 0: Chats (StreamBuilder → conversation tiles with unread badges)
    ├── Tab 1: Groups (StreamBuilder → group tiles with member count)
    └── Tab 2: Calls (lazy-loaded call history with duration, type icons)
```

**User Interactions:**
- Search/voice search conversations
- Tap conversation → open chat, long-press → selection mode
- Swipe-to-delete conversations
- Create new group (FAB)
- Tab change triggers lazy call listener start/stop

**Navigation Targets:** EnhancedChatScreen, GroupChatScreen, CreateGroupScreen, VoiceCallScreen, GroupAudioCallScreen

**Services:** FirebaseAuth, FirebaseFirestore, CurrentUserCache, NotificationService, VoiceSearchMixin

---

#### LoginScreen (`login/login_screen.dart`)

Dual-mode authentication: email/password and phone OTP with 6-digit input boxes. Includes device session enforcement (single-device login).

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_isSignUpMode` | bool | Toggle login/signup form |
| `_emailOrPhoneController` / `_passwordController` | TextEditingController | Form inputs |
| `_isOtpSent` / `_verificationId` | bool / String? | Phone OTP flow state |
| `_otpBoxControllers` | List<TextEditingController> | 6 individual OTP digit boxes |
| `_otpFocusNodes` | List<FocusNode> | Auto-advance focus between OTP boxes |
| `_selectedCountryCode` | String | Phone country code (+91 default) |
| `_pendingUserId` | String? | Device login conflict resolution |
| `_animationController` / `_fadeAnimation` / `_slideAnimation` | AnimationController / Animation | Entry animations |

**Widget Tree:**
```
Scaffold
└── AnimatedBuilder (fade + slide entry)
    └── Stack
        ├── Background gradient + overlay
        └── SafeArea → SingleChildScrollView
            ├── Logo header
            ├── Form
            │   ├── Email/phone input (auto-detects mode)
            │   ├── Password field (conditional, email mode only)
            │   ├── OTP section (conditional, 6 digit boxes)
            │   └── Terms checkbox
            ├── Login/Sign Up button
            └── Forgot password link
```

**Navigation Targets:** MainNavigationScreen (success), ForgotPasswordScreen, ChooseAccountTypeScreen

**Services:** AuthService, FirebaseAuth, FirebaseFirestore

---

#### MainNavigationScreen (`home/main_navigation_screen.dart`)

Root container managing 5 bottom tabs with real-time listeners for unread counts and incoming calls.

**State Variables:**
| Variable | Type | Purpose |
|----------|------|---------|
| `_currentIndex` | int | Active tab index |
| `_tabController` | TabController | 5-tab controller |
| `_unreadSubscription` | StreamSubscription? | Unread message badge listener |
| `_incomingCallSubscription` | StreamSubscription? | Incoming call listener |
| `_isShowingIncomingCall` | bool | Prevent duplicate call dialogs |
| `_handledCallIds` | Set<String> | Prevent re-handling same call |

**5 Tabs:** HomeScreen → ConversationsScreen → LiveConnectTabScreen → BusinessHubScreen → NetworkingScreen

**Features:**
- Persists last tab index to SharedPreferences
- Haptic feedback on tab change
- WidgetsBindingObserver for online status updates on app lifecycle
- CallKit integration for native incoming call UI
- Unread badge counts on Messages tab

**Services:** LocationService, NotificationService, FirebaseAuth, FirebaseFirestore, CallKit, SharedPreferences

---

#### ProfileViewScreen (`profile/profile_view_screen.dart`)

View any user's profile. Adapts layout for personal vs business accounts. Logs profile views for business analytics.

**Widget Tree:**
```
Scaffold → SafeArea → Stack
├── SingleChildScrollView
│   ├── Image carousel (PageView with dot indicators)
│   ├── Profile info (name, bio, verification badges)
│   ├── Post details (if navigated from post card)
│   ├── Catalog grid (if business account)
│   └── Reviews section (if business account)
├── Top bar (back, online indicator, more options)
└── Bottom action bar (Message, Connect, Write Review buttons)
```

**Navigation Targets:** EnhancedChatScreen, CatalogItemDetailScreen, WriteReviewScreen

---

#### PublicBusinessProfileScreen (`business/simple/public_business_profile_screen.dart`)

Public-facing business profile with catalog, hours, and reviews.

**Widget Tree:**
```
Scaffold → CustomScrollView
├── SliverAppBar (flexible cover image)
└── SliverToBoxAdapter sections
    ├── Action row (message, call, review buttons)
    ├── About section (business description)
    ├── Catalog grid (available items only)
    ├── Business hours schedule
    └── Reviews with RatingSummary breakdown
```

**Navigation Targets:** EnhancedChatScreen, WriteReviewScreen, CatalogItemDetailScreen, ReviewsScreen, BookingRequestScreen

**Services:** CatalogService, ReviewService, FirebaseAuth, FirebaseFirestore

---

#### CatalogManagementScreen (`business/simple/catalog_management_screen.dart`)

Business inventory management with search, filters, grid/list toggle, and animated FAB.

**Widget Tree:**
```
Scaffold
├── AppBar (search field + filter dropdown)
├── StreamBuilder on catalog items
│   ├── Grid view (CatalogCardWidget cards)
│   └── List view (CatalogCardWidget rows)
└── Animated FAB (collapses on scroll down, expands on scroll up)
```

**User Interactions:**
- Search filters items by name/description
- Type filter dropdown (product/service/all)
- Grid/list toggle
- Item tap → bottom sheet (edit, mark sold/available, delete)
- FAB → add new catalog item

**Navigation Targets:** CatalogItemForm (add/edit)

**Services:** CatalogService, FirebaseAuth

---

#### OnboardingScreen (`login/onboarding_screen.dart`)

4-page feature carousel with 3D card effect (viewportFraction: 0.8). Purely presentational.

**Widget Tree:**
```
Scaffold → Stack
├── Background gradient + image overlay
└── SafeArea
    ├── Header (logo + Skip button)
    ├── PageView (4 onboarding cards with parallax effect)
    └── Bottom (dot indicators + Get Started button)
```

**Navigation Targets:** ChooseAccountTypeScreen

---

#### ProfileEditScreen (`profile/profile_edit_screen.dart`)

Edit own profile with form validation, photo upload, and business account toggle.

**Form Fields:** Name, Phone, Location (auto-detect), Bio, Gender dropdown, Occupation dropdown, Date of birth picker, Profile photo (tap to change)

**Navigation Targets:** BusinessInfoEdit (when business toggle activated)

**Services:** AuthService, UserManager, FirebaseAuth, FirebaseFirestore, FirebaseStorage, LocationService, ImagePicker, AccountTypeService

---

