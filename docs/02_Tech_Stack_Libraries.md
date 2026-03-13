## 2. Tech Stack & Libraries

### Core Framework

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter | 3.35.7 |
| Language | Dart | 3.9.2 |
| State Management | Riverpod | 2.6.1 |
| Backend | Firebase | Multi-service |
| AI Engine | Google Gemini | gemini-2.5-flash |
| Embeddings | Gemini Embedding | gemini-embedding-001 |

### Firebase Services (8 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| firebase_core | ^3.8.0 | Core initialization |
| firebase_auth | ^5.3.3 | Authentication (email, Google, phone) |
| cloud_firestore | ^5.4.4 | NoSQL database |
| cloud_functions | ^5.6.2 | Cloud Functions (force logout) |
| firebase_storage | ^12.3.4 | File/media storage |
| firebase_messaging | ^15.1.4 | Push notifications (FCM) |
| firebase_crashlytics | ^4.2.1 | Crash reporting |
| firebase_analytics | ^11.3.3 | Usage analytics |

### AI & Machine Learning

| Package | Version | Purpose |
|---------|---------|---------|
| google_generative_ai | ^0.4.7 | Gemini AI (generation + embeddings) |
| speech_to_text | ^7.3.0 | Voice input transcription |
| flutter_tts | ^4.2.5 | Text-to-speech output |

### Real-Time Communication

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_webrtc | ^0.12.5 | P2P voice/video calls |
| flutter_callkit_incoming | ^3.0.0 | Native call UI (iOS CallKit, Android) |
| flutter_ringtone_player | ^4.0.0+4 | Ringtone for incoming calls |

### Networking & HTTP

| Package | Version | Purpose |
|---------|---------|---------|
| http | ^1.2.2 | HTTP client (geocoding APIs) |
| dio | ^5.7.0 | Advanced HTTP (media upload/download) |

### Location & Geolocation

| Package | Version | Purpose |
|---------|---------|---------|
| geolocator | ^13.0.2 | GPS positioning |
| geocoding | ^3.0.0 | Reverse geocoding (coordinates → address) |

### Media Handling (7 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| cached_network_image | ^3.4.1 | Image caching with placeholders |
| image_picker | ^1.1.2 | Camera/gallery image selection |
| video_player | ^2.9.2 | Video playback |
| chewie | ^1.8.5 | Video player controls |
| flutter_image_compress | ^2.3.0 | Image compression before upload |
| video_compress | ^3.1.2 | Video compression before upload |
| file_picker | ^8.1.4 | File selection (documents, etc.) |

### Audio

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_sound | ^9.16.3 | Voice message recording |
| audioplayers | ^6.1.0 | Audio playback |

### Notifications

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_local_notifications | ^18.0.1 | Local notification display |

### UI/UX Components (8 packages)

| Package | Version | Purpose |
|---------|---------|---------|
| cupertino_icons | ^1.0.8 | iOS-style icons |
| badges | ^3.1.2 | Badge indicators |
| shimmer | ^3.0.0 | Loading shimmer effects |
| flutter_chat_bubble | ^2.0.2 | Chat bubble styling |
| lottie | ^3.3.2 | Lottie animations |
| google_fonts | ^8.0.1 | Google Fonts (Poppins) |
| font_awesome_flutter | ^10.12.0 | FontAwesome icons |
| fl_chart | ^0.69.0 | Charts/data visualization |

### Device & Platform

| Package | Version | Purpose |
|---------|---------|---------|
| permission_handler | ^11.3.1 | Runtime permissions |
| device_info_plus | ^11.3.3 | Device identification |
| package_info_plus | ^8.0.3 | App version info |
| connectivity_plus | ^6.0.5 | Network monitoring |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| uuid | ^4.5.2 | Unique ID generation |
| url_launcher | ^6.3.1 | Open URLs/apps |
| shared_preferences | ^2.3.2 | Key-value local storage |
| path_provider | ^2.1.4 | File system paths |
| timeago | 3.7.0 | Relative timestamps |
| share_plus | ^10.1.4 | Native share sheet |
| open_filex | ^4.5.0 | Open files with native apps |
| mime | ^2.0.0 | MIME type detection |
| intl | ^0.19.0 | Internationalization |
| emoji_picker_flutter | ^4.3.0 | Emoji selection UI |
| flutter_dotenv | ^5.1.0 | Environment variables |

### Local Storage

| Package | Version | Purpose |
|---------|---------|---------|
| sqflite | ^2.3.0 | SQLite (offline message cache) |
| path | ^1.9.0 | Path manipulation |

### PDF

| Package | Version | Purpose |
|---------|---------|---------|
| syncfusion_flutter_pdf | ^28.1.33 | PDF generation/viewing |

### Development Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_test | SDK | Widget/unit testing |
| integration_test | SDK | Integration testing |
| flutter_launcher_icons | ^0.13.1 | App icon generation |
| flutter_lints | ^3.0.2 | Code linting rules |
| mockito | ^5.4.4 | Mock objects for testing |
| fake_cloud_firestore | ^3.1.0 | Firestore mocks |

**Total: 55+ dependencies**

---

