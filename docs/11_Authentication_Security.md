## 11. Authentication & Security

### Authentication Methods

| Method | Package | Details |
|--------|---------|---------|
| Email/Password | firebase_auth | Standard signup/login |
| Google Sign-In | google_sign_in | OAuth2 with high-quality photo extraction |
| Phone OTP | firebase_auth | SMS verification (30 countries supported) |

### Authentication Flow

```
SplashScreen (3 sec)
    ↓
AuthWrapper (StreamBuilder<User?>)
    ├── [null] → OnboardingScreen → ChooseAccountType → LoginScreen
    │                                                       ├── Email login
    │                                                       ├── Google Sign-In
    │                                                       └── Phone OTP
    │                                                            ↓
    │                                                     Device Session Check
    │                                                       ├── [No conflict] → Save session → Main app
    │                                                       └── [Conflict] → DeviceLoginDialog
    │                                                            ├── "Logout Other Device" → Force logout
    │                                                            └── "Stay Logged In" → Both active
    └── [User] → MainNavigationScreen + Device monitoring
```

### Single-Device Session Management (WhatsApp-style)

Only one device can be active at a time:

```
Device A (logged in)                    Device B (new login)
├── localStorage: token_A              ├── Generate token_B
├── Firestore: activeDeviceToken=A     ├── Read Firestore: finds token_A
├── Listener: watching changes         ├── Show DeviceLoginDialog
│                                      │
│                                      User clicks "Logout Other Device"
│                                      ├── DELETE activeDeviceToken (immediate)
│                                      ├── SET forceLogout=true
│                                      ├── WAIT 1.5 seconds
│                                      └── SET activeDeviceToken=token_B
│
├── Listener detects forceLogout=true
├── _performRemoteLogout()
├── Clear all caches & subscriptions
├── FirebaseAuth.signOut()
└── Show login screen (~500ms)
```

**Protection Mechanisms:**
- 5-second initialization window (prevents false logouts during login)
- Timestamp validation (logout signal must be after listener started)
- Stale session detection (auto-clears sessions > 5 minutes old)

### Firestore Security Rules (`firestore.rules`)

| Collection | Read | Write | Special Rules |
|-----------|------|-------|---------------|
| users/{userId} | Authenticated | Owner only | Device fields writable by any auth user; self-verification blocked |
| posts | Authenticated | Owner | Active posts only |
| conversations | Participants only | Participants | Membership check |
| calls | Participants | Participants | - |
| notifications | Owner | Owner | - |
| bookings | Authenticated | Owner | - |
| business_reviews | Authenticated | Authenticated | - |

**Business Profile Stats**: Any authenticated user can increment `profileViews`, `catalogViews`, `enquiryCount`.

### Storage Security Rules (`storage.rules`)

| Path | Read | Write | Limits |
|------|------|-------|--------|
| profiles/{userId}/* | Authenticated | Owner | Images < 50MB |
| posts/{userId}/* | Authenticated | Owner | Images < 50MB |
| chat/{conversationId}/* | Authenticated | Owner | Images < 50MB, Video < 200MB |
| voice_notes/* | Authenticated | Owner | Audio < 5MB |
| catalog/{userId}/* | Authenticated | Owner | Images < 50MB |

### Permissions

#### Android (21 permissions)

| Permission | Purpose |
|-----------|---------|
| INTERNET | Network access |
| CAMERA | Video calls, profile photos |
| RECORD_AUDIO | Voice calls, voice messages |
| ACCESS_FINE_LOCATION | GPS positioning |
| ACCESS_COARSE_LOCATION | Approximate location |
| ACCESS_BACKGROUND_LOCATION | Background location updates |
| READ_MEDIA_IMAGES/VIDEO/AUDIO | Android 13+ media access |
| READ/WRITE_EXTERNAL_STORAGE | Legacy storage (API < 33) |
| BLUETOOTH, BLUETOOTH_CONNECT | Audio routing |
| READ_PHONE_STATE, CALL_PHONE | Call handling |
| USE_FULL_SCREEN_INTENT | Incoming call UI |
| WAKE_LOCK, VIBRATE | Notifications |
| FOREGROUND_SERVICE | Background operations |
| POST_NOTIFICATIONS | Android 13+ notifications |
| SYSTEM_ALERT_WINDOW | Floating call overlay |

#### iOS (Background Modes)

| Mode | Purpose |
|------|---------|
| remote-notification | FCM push notifications |
| voip | VoIP calls |
| audio | Background audio |
| fetch | Background data fetch |

#### iOS Permission Descriptions

| Permission | Description |
|-----------|-------------|
| Camera | "Video calls and profile photos" |
| Photo Library | "Select profile images" |
| Photo Library Additions | "Save photos to library" |
| Location When In Use | "Nearby users and location-based matching" |
| Microphone | "Voice calls" |

---

