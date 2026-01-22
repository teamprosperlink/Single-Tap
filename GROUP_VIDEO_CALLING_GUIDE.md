# Group Video Calling Implementation Guide

## Overview

This guide explains how to implement WhatsApp-style group video calling in your Flutter app using WebRTC and Firebase. The implementation supports:

- ✅ **Single-person video calls** (existing feature)
- ✅ **Group video calls** with up to 8 participants (new feature)
- ✅ WhatsApp-style UI with grid layout
- ✅ Dynamic participant management (join/leave)
- ✅ Real-time video/audio streaming
- ✅ Call controls (mute, video toggle, camera switch, speaker)

---

## Architecture

### WebRTC Mesh Architecture
The group video calling uses a **mesh topology**, where each participant creates a direct peer-to-peer connection with every other participant:

```
Participant A ←→ Participant B
    ↓ ↘              ↓
    ↓   ↘            ↓
Participant C ←→ Participant D
```

**Note:** For production with more than 8 participants, consider upgrading to an SFU (Selective Forwarding Unit) architecture using services like:
- Agora
- Twilio Video
- Daily.co
- Jitsi

---

## Firestore Schema

### 1. Group Calls Collection

**Collection:** `group_calls/{callId}`

```javascript
{
  callId: string,
  callerUserId: string,
  callerName: string,
  callerPhotoUrl: string,
  status: "ringing" | "active" | "ended" | "cancelled",
  createdAt: timestamp,
  acceptedAt: timestamp,
  endedAt: timestamp,
  maxParticipants: number, // Default: 8
}
```

### 2. Participants Subcollection

**Subcollection:** `group_calls/{callId}/participants/{userId}`

```javascript
{
  userId: string,
  userName: string,
  userPhotoUrl: string,
  isActive: boolean,
  joinedAt: timestamp,
  leftAt: timestamp,
  declined: boolean,
  declinedAt: timestamp,
}
```

### 3. Signaling Subcollection (WebRTC Offer/Answer)

**Subcollection:** `group_calls/{callId}/signaling/{documentId}`

```javascript
{
  from: string,          // Sender userId
  to: string,            // Recipient userId
  type: "offer" | "answer",
  sdp: string,           // SDP (Session Description Protocol)
  timestamp: timestamp,
}
```

### 4. ICE Candidates Subcollection

**Subcollection:** `group_calls/{callId}/ice_candidates/{documentId}`

```javascript
{
  from: string,          // Sender userId
  to: string,            // Recipient userId
  candidate: string,     // ICE candidate string
  sdpMid: string,
  sdpMLineIndex: number,
  timestamp: timestamp,
}
```

---

## Required Firestore Indexes

Add these composite indexes to your Firestore:

```
Collection: group_calls/{callId}/signaling
  - from (Ascending) + to (Ascending) + type (Ascending)

Collection: group_calls/{callId}/ice_candidates
  - from (Ascending) + to (Ascending)

Collection: group_calls/{callId}/participants
  - isActive (Ascending) + joinedAt (Descending)
```

To create indexes:
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Add the fields listed above

---

## Implementation Steps

### Step 1: Start a Group Video Call

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supper/screens/call/group_video_call_screen.dart';

Future<void> startGroupVideoCall({
  required String currentUserId,
  required String currentUserName,
  required String? currentUserPhotoUrl,
  required List<Map<String, dynamic>> selectedUsers,
  required BuildContext context,
}) async {
  final firestore = FirebaseFirestore.instance;

  try {
    // Create group call document
    final callDoc = firestore.collection('group_calls').doc();
    final callId = callDoc.id;

    await callDoc.set({
      'callId': callId,
      'callerUserId': currentUserId,
      'callerName': currentUserName,
      'callerPhotoUrl': currentUserPhotoUrl,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
      'maxParticipants': 8,
    });

    // Add all participants (including caller)
    final batch = firestore.batch();

    // Add caller
    batch.set(
      callDoc.collection('participants').doc(currentUserId),
      {
        'userId': currentUserId,
        'userName': currentUserName,
        'userPhotoUrl': currentUserPhotoUrl,
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    // Add other participants
    for (var user in selectedUsers) {
      batch.set(
        callDoc.collection('participants').doc(user['userId']),
        {
          'userId': user['userId'],
          'userName': user['name'],
          'userPhotoUrl': user['photoUrl'],
          'isActive': false, // They haven't joined yet
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();

    // Send notifications to all participants (implement your notification logic)
    for (var user in selectedUsers) {
      await _sendGroupCallNotification(
        receiverUserId: user['userId'],
        callerName: currentUserName,
        callId: callId,
      );
    }

    // Navigate to group video call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupVideoCallScreen(
          callId: callId,
          userId: currentUserId,
          userName: currentUserName,
          participants: [
            {
              'userId': currentUserId,
              'name': currentUserName,
              'photoUrl': currentUserPhotoUrl,
            },
            ...selectedUsers,
          ],
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error starting group call: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to start call: $e')),
    );
  }
}

// Implement your notification service
Future<void> _sendGroupCallNotification({
  required String receiverUserId,
  required String callerName,
  required String callId,
}) async {
  // Use Firebase Cloud Messaging (FCM) or Firestore notifications
  await FirebaseFirestore.instance
      .collection('notifications')
      .add({
    'userId': receiverUserId,
    'type': 'group_video_call',
    'title': 'Group Video Call',
    'body': '$callerName is calling...',
    'callId': callId,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
```

### Step 2: Handle Incoming Group Call Notification

When a user receives a notification, show the incoming call screen:

```dart
import 'package:supper/screens/call/incoming_group_video_call_screen.dart';

Future<void> handleIncomingGroupCall({
  required String callId,
  required String currentUserId,
  required BuildContext context,
}) async {
  final firestore = FirebaseFirestore.instance;

  try {
    // Fetch call details
    final callDoc = await firestore.collection('group_calls').doc(callId).get();
    if (!callDoc.exists) return;

    final callData = callDoc.data()!;
    final status = callData['status'] as String;

    // Only show if call is still ringing or active
    if (status != 'ringing' && status != 'active') return;

    // Fetch participants
    final participantsSnapshot = await firestore
        .collection('group_calls')
        .doc(callId)
        .collection('participants')
        .get();

    final participants = participantsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'userId': data['userId'],
        'name': data['userName'],
        'photoUrl': data['userPhotoUrl'],
      };
    }).toList();

    // Navigate to incoming call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingGroupVideoCallScreen(
          callId: callId,
          callerName: callData['callerName'],
          callerPhotoUrl: callData['callerPhotoUrl'],
          participants: participants,
          currentUserId: currentUserId,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error handling incoming call: $e');
  }
}
```

### Step 3: Add Group Call Button to Chat Screen

Add a button in your chat interface to start group calls:

```dart
// In your chat screen or contacts screen
IconButton(
  icon: Icon(Icons.video_call),
  onPressed: () async {
    // Show dialog to select participants
    final selectedUsers = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => SelectParticipantsDialog(),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty) {
      await startGroupVideoCall(
        currentUserId: currentUser.uid,
        currentUserName: currentUser.name,
        currentUserPhotoUrl: currentUser.photoUrl,
        selectedUsers: selectedUsers,
        context: context,
      );
    }
  },
)
```

---

## UI Features

### Grid Layout Behavior

The UI automatically adjusts based on participant count:

- **1 participant:** Full screen
- **2 participants:** Vertical split (50/50)
- **3-4 participants:** 2×2 grid
- **5-6 participants:** 2×3 grid
- **7-8 participants:** 2×4 grid (scrollable)

### Call Controls

All participants have access to:
- 🎥 **Video toggle** - Turn camera on/off
- 🔄 **Camera switch** - Switch between front/back camera
- 🎤 **Mute toggle** - Mute/unmute microphone
- 🔊 **Speaker toggle** - Enable/disable speaker
- ❌ **End call** - Leave the group call

---

## Testing the Implementation

### Test Scenario 1: 2-Person Group Call

1. User A starts a group call with User B
2. User B receives notification and accepts
3. Both users should see each other in split screen
4. Test controls: mute, video toggle, camera switch

### Test Scenario 2: 4-Person Group Call

1. User A starts a group call with Users B, C, D
2. All users accept the call
3. UI should show 2×2 grid layout
4. Test participant leaving and rejoining

### Test Scenario 3: Network Interruption

1. Start a group call
2. Disable WiFi on one device
3. Other participants should see that user leave
4. Re-enable WiFi - user should be able to rejoin

---

## Limitations & Recommendations

### Current Limitations

1. **Max 8 participants** - Mesh architecture becomes unstable beyond 8 peers
2. **High bandwidth usage** - Each participant sends/receives N-1 streams
3. **CPU intensive** - Encoding/decoding multiple video streams

### Recommendations for Production

1. **Use SFU for >8 participants:**
   - Agora (recommended): https://www.agora.io/
   - Twilio Video: https://www.twilio.com/video
   - Daily.co: https://www.daily.co/

2. **Implement bandwidth optimization:**
   - Reduce video quality for thumbnails
   - Use simulcast for better quality control
   - Implement dominant speaker detection

3. **Add features:**
   - Screen sharing
   - Chat during calls
   - Recording
   - Virtual backgrounds
   - Noise cancellation

---

## Troubleshooting

### Video Not Showing

**Problem:** Black screen or avatar instead of video

**Solutions:**
1. Check camera permissions: `Permission.camera.status`
2. Verify renderer initialization: `renderer.textureId != null`
3. Check video track enabled: `track.enabled == true`
4. Look for errors in console: `flutter run --verbose`

### Audio Issues

**Problem:** Can't hear other participants

**Solutions:**
1. Check microphone permission: `Permission.microphone.status`
2. Verify speaker is enabled: `Helper.setSpeakerphoneOn(true)`
3. Check audio tracks: `stream.getAudioTracks()`
4. Test on physical device (audio may not work on emulator)

### Participants Not Connecting

**Problem:** Participants can't see each other

**Solutions:**
1. Verify Firestore indexes are created
2. Check ICE candidate exchange in Firestore
3. Ensure TURN servers are working (try stun:stun.l.google.com:19302)
4. Check network firewall settings

### High CPU Usage

**Problem:** App becomes slow during group call

**Solutions:**
1. Reduce video resolution in `mediaConstraints`
2. Limit frame rate to 15-20 fps
3. Use hardware acceleration (already enabled in flutter_webrtc)
4. Consider using SFU architecture

---

## Code Files Summary

### New Files Created

1. **`lib/services/other services/group_video_call_service.dart`**
   - Manages WebRTC connections for group calls
   - Handles peer connections, signaling, and ICE candidates
   - Controls audio/video tracks and renderers

2. **`lib/screens/call/group_video_call_screen.dart`**
   - Main group call UI with grid layout
   - Call controls and participant management
   - WhatsApp-style design

3. **`lib/screens/call/incoming_group_video_call_screen.dart`**
   - Incoming call notification screen
   - Accept/decline functionality
   - Participant preview

### Existing Files (No Changes Needed)

- `lib/services/other services/video_call_service.dart` - Single-person video calls
- `lib/screens/call/video_call_screen.dart` - Single-person video call UI

Both single and group video calling work independently!

---

## Next Steps

1. **Test on real devices** - Emulators don't support camera/audio well
2. **Implement notification service** - Use FCM for push notifications
3. **Add call history** - Store completed calls in Firestore
4. **Add UI for selecting participants** - Create a contact picker dialog
5. **Monitor bandwidth usage** - Test with different network conditions
6. **Consider upgrading to SFU** - For better scalability

---

## Support & Resources

- **Flutter WebRTC Documentation:** https://github.com/flutter-webrtc/flutter-webrtc
- **WebRTC Basics:** https://webrtc.org/getting-started/overview
- **Firebase Firestore:** https://firebase.google.com/docs/firestore
- **Agora Flutter SDK:** https://docs.agora.io/en/video-calling/get-started/get-started-sdk

---

## License

This implementation is part of the Supper app project.
