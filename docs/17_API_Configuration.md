## 17. API Configuration & Environment

### Environment Variables (`.env`)

| Variable | Purpose |
|----------|---------|
| GEMINI_API_KEY | Google Gemini AI API key |
| GOOGLE_CLIENT_ID | Google Sign-In OAuth client ID |
| FIREBASE_WEB_API_KEY | Firebase Web API key |
| FIREBASE_WEB_AUTH_DOMAIN | Firebase Auth domain |
| FIREBASE_WEB_PROJECT_ID | Firebase project ID |
| FIREBASE_WEB_STORAGE_BUCKET | Firebase Storage bucket |
| FIREBASE_WEB_MESSAGING_SENDER_ID | FCM sender ID |
| FIREBASE_WEB_APP_ID | Firebase Web app ID |
| FIREBASE_ANDROID_API_KEY | Firebase Android API key |
| FIREBASE_ANDROID_APP_ID | Firebase Android app ID |
| FIREBASE_IOS_API_KEY | Firebase iOS API key |
| FIREBASE_IOS_APP_ID | Firebase iOS app ID |
| FIREBASE_IOS_BUNDLE_ID | Firebase iOS bundle ID |

### API Configuration (`api_config.dart`)

| Setting | Value |
|---------|-------|
| Gemini Flash Model | gemini-2.5-flash |
| Gemini Embedding Model | gemini-embedding-001 |
| API Base URL | https://generativelanguage.googleapis.com |
| Temperature | 0.7 |
| Top K | 40 |
| Top P | 0.95 |
| Max Output Tokens | 1024 |
| Embedding Dimension | 768 |
| Connection Timeout | 30 seconds |
| Receive Timeout | 30 seconds |
| API Call Timeout | 45 seconds |
| Max Retries | 3 |
| Retry Delay | 2 seconds |

### Firebase Project

| Setting | Value |
|---------|-------|
| Project ID | suuper2 |
| Auth Domain | suuper2.firebaseapp.com |
| Storage Bucket | suuper2.firebasestorage.app |
| Realtime Database | suuper2-default-rtdb.firebaseio.com |
| Android Package | com.plink.supper |

### WebRTC Configuration

| Setting | Value |
|---------|-------|
| STUN Server 1 | stun:stun.l.google.com:19302 |
| STUN Server 2 | stun:openrelay.metered.ca:80 |
| TURN Server | openrelay.metered.ca (443, TCP/UDP) |
| ICE Candidate Pool | 10 |

### Geocoding API Fallback Chain

| Priority | API | Type |
|----------|-----|------|
| 1 (Web) | BigDataCloud | Free, CORS-friendly |
| 2 (Web) | OpenCage | Free tier |
| 3 (Mobile) | OSM Nominatim | Free |
| 4 (Fallback) | Flutter geocoding package | Local |

---

