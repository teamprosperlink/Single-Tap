# Quick Start Checklist - Group Video Calling

Follow this checklist to get group video calling working in your app.

---

## ☑️ Step 1: Verify Dependencies (Already Done)

Your `pubspec.yaml` should already have:
- ✅ `flutter_webrtc` - For WebRTC functionality
- ✅ `cloud_firestore` - For signaling
- ✅ `firebase_auth` - For user authentication
- ✅ `permission_handler` - For camera/mic permissions

---

## ☑️ Step 2: Create Firestore Indexes

**CRITICAL:** You must create these indexes in Firebase Console, or calls won't work!

1. Go to **Firebase Console** → Your Project → **Firestore Database** → **Indexes**

2. Create these composite indexes:

### Index 1: Participants Query
- **Collection:** `group_calls/{callId}/participants`
- **Fields:**
  - `isActive` (Ascending)
  - `joinedAt` (Descending)

### Index 2: Signaling Query
- **Collection:** `group_calls/{callId}/signaling`
- **Fields:**
  - `from` (Ascending)
  - `to` (Ascending)
  - `type` (Ascending)

### Index 3: ICE Candidates Query
- **Collection:** `group_calls/{callId}/ice_candidates`
- **Fields:**
  - `from` (Ascending)
  - `to` (Ascending)

**Note:** Firestore will also prompt you to create indexes when you run the app. Just click the link in the error message!

---

## ☑️ Step 3: Add Group Call Button to Your UI

Choose where you want users to start group calls. Here are common places:

### Option A: In Chat Screen
```dart
// In your chat screen AppBar
IconButton(
  icon: const Icon(Icons.group_add),
  tooltip: 'Start Group Video Call',
  onPressed: () async {
    await GroupCallHelper.showParticipantSelectionAndStartCall(
      context: context,
      currentUserId: FirebaseAuth.instance.currentUser!.uid,
      currentUserName: FirebaseAuth.instance.currentUser!.displayName ?? 'You',
      currentUserPhotoUrl: FirebaseAuth.instance.currentUser!.photoURL,
    );
  },
)
```

### Option B: In Contacts/Friends Screen
```dart
// In your contacts screen
FloatingActionButton(
  onPressed: () async {
    await GroupCallHelper.showParticipantSelectionAndStartCall(
      context: context,
      currentUserId: FirebaseAuth.instance.currentUser!.uid,
      currentUserName: FirebaseAuth.instance.currentUser!.displayName ?? 'You',
      currentUserPhotoUrl: FirebaseAuth.instance.currentUser!.photoURL,
    );
  },
  child: const Icon(Icons.videocam),
)
```

### Option C: In Profile/User Detail Screen
```dart
// In user profile screen
ElevatedButton.icon(
  icon: const Icon(Icons.group_add),
  label: const Text('Group Video Call'),
  onPressed: () async {
    await GroupCallHelper.showParticipantSelectionAndStartCall(
      context: context,
      currentUserId: FirebaseAuth.instance.currentUser!.uid,
      currentUserName: FirebaseAuth.instance.currentUser!.displayName ?? 'You',
      currentUserPhotoUrl: FirebaseAuth.instance.currentUser!.photoURL,
    );
  },
)
```

---

## ☑️ Step 4: Handle Incoming Calls (Notifications)

### Simple Firestore Listener (Basic Setup)

Add this to your main screen or navigation wrapper:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supper/utils/group_call_helper.dart';

class MainNavigationScreen extends StatefulWidget {
  // Your existing code...
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  StreamSubscription? _callListener;

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Listen for notifications
    _callListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'group_video_call')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final callId = data['data']?['callId'] as String?;

            if (callId != null && mounted) {
              // Mark as read
              await doc.doc.reference.update({'read': true});

              // Handle incoming call
              await GroupCallHelper.handleIncomingGroupCall(
                context: context,
                callId: callId,
                currentUserId: currentUserId,
              );
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _callListener?.cancel();
    super.dispose();
  }

  // Rest of your code...
}
```

### Advanced: Firebase Cloud Messaging (FCM)

For production apps with background notifications, set up FCM:

```dart
// In your notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supper/utils/group_call_helper.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      final type = message.data['type'];
      if (type == 'group_video_call') {
        _handleIncomingCall(message.data['callId']);
      }
    });

    // Handle notification taps (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final type = message.data['type'];
      if (type == 'group_video_call') {
        _handleIncomingCall(message.data['callId']);
      }
    });
  }

  Future<void> _handleIncomingCall(String callId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    await GroupCallHelper.handleIncomingGroupCall(
      context: navigatorKey.currentContext!,
      callId: callId,
      currentUserId: currentUserId,
    );
  }
}
```

---

## ☑️ Step 5: Test on Real Devices

**IMPORTANT:** Emulators don't support camera/audio properly. You MUST test on physical devices!

### Minimum Test Setup
- **2 Android phones** OR
- **2 iPhones** OR
- **1 Android + 1 iPhone**

### Test Checklist

#### Basic Tests
- [ ] Start 2-person group call
- [ ] Start 4-person group call
- [ ] Accept incoming call
- [ ] Decline incoming call
- [ ] Toggle mute
- [ ] Toggle video
- [ ] Switch camera (front/back)
- [ ] Toggle speaker
- [ ] End call

#### Advanced Tests
- [ ] One participant joins late
- [ ] One participant leaves mid-call
- [ ] Network interruption (disable WiFi temporarily)
- [ ] App goes to background
- [ ] Multiple calls at once
- [ ] Long duration call (10+ minutes)

---

## ☑️ Step 6: Verify Permissions

Ensure your app has the correct permissions:

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application ...>
        <!-- Your app code -->
    </application>
</manifest>
```

### iOS (`ios/Runner/Info.plist`)
```xml
<dict>
    <key>NSCameraUsageDescription</key>
    <string>We need access to your camera for video calls</string>

    <key>NSMicrophoneUsageDescription</key>
    <string>We need access to your microphone for calls</string>

    <!-- Rest of your Info.plist -->
</dict>
```

---

## ☑️ Step 7: Monitor & Debug

### Check Firestore Data

During testing, check Firebase Console to verify:
- [ ] `group_calls` collection is being created
- [ ] `participants` subcollection has all users
- [ ] `signaling` messages are being exchanged
- [ ] `ice_candidates` are being created

### Check Logs

In your IDE console, look for these log messages:

**Success Indicators:**
```
✅ GroupVideoCallService: Initialized successfully
✅ Joined group call successfully
✅ Participant joined: user123
✅ Remote stream ready for user123
```

**Error Indicators:**
```
❌ GroupVideoCallService: Initialization error
❌ Error joining call
❌ Error creating peer connection
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Black screen | Check camera permission & renderer initialization |
| No audio | Check microphone permission & speaker enabled |
| Participants not connecting | Verify Firestore indexes are created |
| High CPU usage | Reduce video quality in service |

---

## ☑️ Step 8: Production Checklist

Before releasing to production:

### Security
- [ ] Add Firestore security rules
- [ ] Validate user authentication
- [ ] Rate-limit call creation
- [ ] Prevent unauthorized access

### Example Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Group calls
    match /group_calls/{callId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.callerUserId;
      allow update: if request.auth != null;

      // Participants
      match /participants/{userId} {
        allow read, write: if request.auth != null;
      }

      // Signaling
      match /signaling/{docId} {
        allow read, write: if request.auth != null;
      }

      // ICE candidates
      match /ice_candidates/{docId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

### Performance
- [ ] Monitor Firestore read/write usage
- [ ] Set up billing alerts in Firebase
- [ ] Consider caching strategies
- [ ] Optimize video quality based on network

### User Experience
- [ ] Add loading indicators
- [ ] Show network quality indicators
- [ ] Handle network failures gracefully
- [ ] Add reconnection logic

---

## 🎯 Quick Reference

### Start Group Call
```dart
await GroupCallHelper.showParticipantSelectionAndStartCall(
  context: context,
  currentUserId: currentUser.uid,
  currentUserName: currentUser.name,
  currentUserPhotoUrl: currentUser.photoUrl,
);
```

### Handle Incoming Call
```dart
await GroupCallHelper.handleIncomingGroupCall(
  context: context,
  callId: callId,
  currentUserId: currentUserId,
);
```

### Cancel Call
```dart
await GroupCallHelper.cancelGroupCall(callId);
```

### End Call
```dart
await GroupCallHelper.endGroupCall(callId);
```

---

## 📚 Additional Resources

- **Complete Guide:** [GROUP_VIDEO_CALLING_GUIDE.md](./GROUP_VIDEO_CALLING_GUIDE.md)
- **Integration Examples:** [INTEGRATION_EXAMPLE.md](./INTEGRATION_EXAMPLE.md)
- **Summary:** [VIDEO_CALLING_COMPLETE_SUMMARY.md](./VIDEO_CALLING_COMPLETE_SUMMARY.md)

---

## ✅ Final Checklist

Before marking this as complete:

- [ ] Firestore indexes created
- [ ] Group call button added to UI
- [ ] Notification handling implemented
- [ ] Tested on 2+ real devices
- [ ] Permissions verified (Android & iOS)
- [ ] Firestore security rules added
- [ ] Production monitoring set up

---

**You're ready to go! 🚀**

Start testing and enjoy your WhatsApp-style group video calling feature!
