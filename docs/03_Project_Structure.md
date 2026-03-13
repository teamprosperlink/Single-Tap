## 3. Project Structure

```
lib/
├── main.dart                              # App entry + AuthWrapper + SplashScreen
├── main_web.dart                          # Web-specific entry point
├── firebase_options.dart                  # Firebase config (from .env)
│
├── config/
│   └── app_theme.dart                     # Theme constants, spacing, colors
│
├── database/
│   └── message_database.dart              # SQLite message cache (offline)
│
├── mixins/
│   └── voice_search_mixin.dart            # Voice search for any screen
│
├── models/                                # Data models (15 files)
│   ├── base/
│   │   ├── base_category_model.dart       # Abstract category base
│   │   ├── base_order_item.dart           # Abstract order item base
│   │   └── priceable_mixin.dart           # Price formatting mixin
│   ├── booking_model.dart                 # Bookings
│   ├── catalog_item.dart                  # Products/services
│   ├── conversation_model.dart            # Chat conversations
│   ├── extended_user_profile.dart         # Discovery profile
│   ├── inquiry_model.dart                 # Business inquiries
│   ├── live_connect_filter.dart           # Networking filters
│   ├── menu_model.dart                    # Restaurant menu system
│   ├── message_model.dart                 # Chat messages
│   ├── post_model.dart                    # AI-matchable posts
│   ├── review_model.dart                  # Reviews/ratings
│   └── user_profile.dart                  # User + BusinessProfile
│
├── providers/                             # Riverpod state management
│   └── other providers/
│       ├── app_providers.dart             # 11 providers (auth, user, connectivity)
│       └── theme_provider.dart            # Dark/glassmorphism theme
│
├── res/                                   # Resources & configuration
│   ├── config/
│   │   ├── api_assets.dart                # Asset paths + API endpoints
│   │   ├── api_config.dart                # AI config + matching thresholds
│   │   ├── app_colors.dart                # 471-line color system
│   │   └── app_text_styles.dart           # 682-line typography system
│   └── utils/
│       ├── api_error_handler.dart          # Error classification
│       ├── app_optimizer.dart              # Performance optimization
│       ├── memory_manager.dart             # Buffer management
│       ├── performance_monitor.dart        # Performance tracking
│       ├── photo_url_helper.dart           # Google photo URL fixing
│       └── snackbar_helper.dart            # Glassmorphic snackbars
│
├── screens/                               # UI screens (62 files)
│   ├── login/                             # Auth flow (6 screens)
│   ├── home/                              # Main tabs + features (10 screens)
│   │   └── product/                       # E-commerce (7 screens)
│   ├── chat/                              # Messaging (10 screens)
│   ├── call/                              # Voice/video calls (8 screens)
│   ├── business/simple/                   # Business management (14 screens)
│   ├── profile/                           # User profile (11 screens)
│   ├── location/                          # Location settings (1 screen)
│   └── performance_debug_screen.dart      # Dev debugging
│
├── services/                              # Business logic (34+ files)
│   ├── ai_services/
│   │   └── gemini_service.dart            # Gemini AI integration
│   ├── cache_services/
│   │   └── cache_service.dart             # LRU caching layer
│   ├── chat_services/
│   │   ├── chat_service.dart              # Low-level chat ops
│   │   └── conversation_service.dart      # Conversation management
│   ├── error_services/
│   │   └── error_tracking_service.dart    # Crashlytics integration
│   ├── location_services/
│   │   ├── geocoding_service.dart         # Reverse geocoding
│   │   └── location_service.dart          # GPS + location updates
│   ├── other_services/
│   │   ├── group_video_call_service.dart  # Group video calls
│   │   ├── group_voice_call_service.dart  # Group voice calls
│   │   ├── video_call_service.dart        # 1-on-1 video calls
│   │   └── voice_call_service.dart        # 1-on-1 voice calls
│   ├── profile_services/
│   │   ├── photo_cache_service.dart       # Photo URL caching
│   │   └── profile_service.dart           # Profile CRUD
│   ├── account_type_service.dart          # Account upgrade/management
│   ├── active_chat_service.dart           # Active chat tracking
│   ├── analytics_service.dart             # Firebase Analytics
│   ├── auth_service.dart                  # Authentication
│   ├── booking_service.dart               # Booking management
│   ├── catalog_service.dart               # Business catalog
│   ├── connection_service.dart            # User connections
│   ├── connectivity_service.dart          # Network monitoring
│   ├── current_user_cache.dart            # Current user caching
│   ├── firebase_provider.dart             # Firebase access point
│   ├── floating_call_service.dart         # Floating call overlay
│   ├── group_chat_service.dart            # Group chat management
│   ├── hybrid_chat_service.dart           # SQLite + Firebase sync
│   ├── notification_service.dart          # FCM + local notifications
│   ├── realtime_matching_service.dart     # Real-time match detection
│   ├── review_service.dart                # Reviews/ratings
│   ├── unified_matching_service.dart      # Advanced matching
│   ├── unified_post_service.dart          # Post CRUD + matching
│   ├── universal_intent_service.dart      # Intent processing wrapper
│   ├── user_manager.dart                  # User profile streaming
│   └── voice_assistant_service.dart       # Voice AI assistant
│
├── utils/
│   └── currency_utils.dart                # Currency formatting
│
└── widgets/                               # Reusable components (18 files)
    ├── account_badges.dart                # 6 badge widgets
    ├── app_background.dart                # Background with particles
    ├── app_drawer.dart                    # ChatGPT-style drawer
    ├── audio_visualizer.dart              # Audio wave visualization
    ├── catalog_card_widget.dart           # Product/service card
    ├── catalog_chat_bubble.dart           # Catalog item in chat
    ├── chat_common.dart                   # Shared chat components
    ├── coming_soon_widget.dart            # Feature placeholder
    ├── country_code_picker_sheet.dart     # Country code selector
    ├── device_login_dialog.dart           # Multi-device dialog
    ├── floating_particles.dart            # Particle animation
    ├── safe_circle_avatar.dart            # Rate-limit-safe avatar
    ├── select_participants_dialog.dart    # Group call participant picker
    ├── voice_orb.dart                     # Voice assistant orb
    ├── chat widgets/
    │   └── match_card_with_actions.dart   # Match result card
    ├── other widgets/
    │   ├── glass_text_field.dart          # Glassmorphic inputs
    │   └── user_avatar.dart              # Cached user avatar
    └── profile widgets/
        └── profile_detail_bottom_sheet.dart # Premium profile sheet
```

### File Statistics

| Category | Count |
|----------|-------|
| Screen files | 62 |
| Service files | 34+ |
| Model files | 15 |
| Widget files | 18 |
| Provider files | 2 |
| Config files | 4 |
| Utility files | 7 |
| **Total Dart files** | **140+** |

---

