## 13. Platform Configuration & Device Compatibility

### Android Configuration

| Setting | Value |
|---------|-------|
| Application ID | com.plink.supper |
| Compile SDK | 36 (Android 15) |
| Target SDK | 34 (Android 14) |
| Min SDK | Flutter-managed (~21+, Android 5.0) |
| NDK Version | 28.2.13676358 |
| Java Version | 17 |
| Kotlin Target | JVM 17 |
| Gradle Version | 8.12 |
| MultiDex | Enabled |
| Core Library Desugaring | 2.0.3 |
| Google Services Plugin | 4.4.2 |

### iOS Configuration

| Setting | Value |
|---------|-------|
| Bundle ID | com.plink.supper |
| Deployment Target | Flutter-managed (~12.0+) |
| Supported Orientations | Portrait, Landscape Left/Right |
| Background Modes | remote-notification, voip, audio, fetch |

### Web Configuration

| Setting | Value |
|---------|-------|
| Firebase SDK | 10.7.0 (compat) |
| Display | Standalone (PWA) |
| Orientation | Portrait primary |
| Auth Domain | suuper2.firebaseapp.com |

### Windows Configuration

| Setting | Value |
|---------|-------|
| CMake Minimum | 3.14 |
| C++ Standard | C++17 |
| Unicode | Enabled |

### macOS Configuration

| Setting | Value |
|---------|-------|
| Principal Class | NSApplication |
| Main Nib | MainMenu |

### Platform Support Matrix

| Feature | Android | iOS | Web | Windows | macOS | Linux |
|---------|---------|-----|-----|---------|-------|-------|
| Firebase Auth | Yes | Yes | Yes | Yes | Yes | Yes |
| Cloud Firestore | Yes | Yes | Yes | Yes | Yes | Yes |
| FCM Push | Yes | Yes | Partial | No | No | No |
| Voice Calls (WebRTC) | Yes | Yes | Yes | Partial | Partial | No |
| Camera/Photos | Yes | Yes | Partial | No | No | No |
| GPS Location | Yes | Yes | Partial | No | No | No |
| Voice Input (STT) | Yes | Yes | Partial | No | No | No |
| Local Notifications | Yes | Yes | No | No | No | No |
| CallKit | No | Yes | No | No | No | No |
| SQLite (offline) | Yes | Yes | No | Yes | Yes | Yes |

---

