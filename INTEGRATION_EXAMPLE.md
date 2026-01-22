# Group Video Call Integration Examples

## Quick Integration Guide

This document shows how to integrate group video calling into your existing screens.

---

## Example 1: Add Group Call Button to Chat Screen

Update your chat screen to include a group video call button:

```dart
// In your enhanced_chat_screen.dart or similar file

import 'package:supper/utils/group_call_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnhancedChatScreen extends StatefulWidget {
  // ... existing code
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen> {
  // ... existing code

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.name),
        actions: [
          // Existing voice call button
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _startVoiceCall,
          ),

          // Existing single video call button
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
          ),

          // 🆕 NEW: Group video call button
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Start Group Video Call',
            onPressed: _startGroupVideoCall,
          ),
        ],
      ),
      body: _buildChatBody(),
    );
  }

  // 🆕 NEW: Start group video call
  Future<void> _startGroupVideoCall() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await GroupCallHelper.showParticipantSelectionAndStartCall(
      context: context,
      currentUserId: currentUser.uid,
      currentUserName: currentUser.displayName ?? 'You',
      currentUserPhotoUrl: currentUser.photoURL,
    );
  }

  // Existing methods...
}
```

---

## Example 2: Handle Incoming Group Call Notifications

Update your notification handler to support group calls:

```dart
// In your notification_service.dart or main.dart

import 'package:supper/utils/group_call_helper.dart';

class NotificationService {
  // ... existing code

  Future<void> handleNotification(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    if (type == 'group_video_call') {
      // 🆕 NEW: Handle group video call notification
      final callId = data['callId'] as String?;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (callId != null && currentUserId != null) {
        await GroupCallHelper.handleIncomingGroupCall(
          context: navigatorKey.currentContext!,
          callId: callId,
          currentUserId: currentUserId,
        );
      }
    } else if (type == 'video_call') {
      // Existing single video call handling
      _handleSingleVideoCall(data);
    } else if (type == 'voice_call') {
      // Existing voice call handling
      _handleVoiceCall(data);
    }
  }
}
```

---

## Example 3: Add Group Call Option to Profile Screen

Add a floating action button or menu option:

```dart
// In your profile_screen.dart or user_detail_screen.dart

import 'package:supper/utils/group_call_helper.dart';

class UserProfileScreen extends StatelessWidget {
  final UserProfile userProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userProfile.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'group_call') {
                await _startGroupCall(context);
              } else if (value == 'single_call') {
                await _startSingleVideoCall(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'single_call',
                child: Row(
                  children: [
                    Icon(Icons.videocam),
                    SizedBox(width: 8),
                    Text('Video Call'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'group_call',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('Group Video Call'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildProfileBody(),
    );
  }

  Future<void> _startGroupCall(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await GroupCallHelper.showParticipantSelectionAndStartCall(
      context: context,
      currentUserId: currentUser.uid,
      currentUserName: currentUser.displayName ?? 'You',
      currentUserPhotoUrl: currentUser.photoURL,
    );
  }
}
```

---

## Example 4: Direct Group Call with Specific Users

Start a group call with predefined participants (no selection dialog):

```dart
// In any screen where you want to start a direct group call

import 'package:supper/utils/group_call_helper.dart';

Future<void> startGroupCallWithUsers({
  required BuildContext context,
  required List<UserProfile> users,
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // Convert UserProfile to Map format
  final selectedUsers = users.map((user) => {
    'userId': user.uid,
    'name': user.name,
    'photoUrl': user.photoUrl,
  }).toList();

  await GroupCallHelper.startGroupVideoCall(
    context: context,
    currentUserId: currentUser.uid,
    currentUserName: currentUser.displayName ?? 'You',
    currentUserPhotoUrl: currentUser.photoURL,
    selectedUsers: selectedUsers,
  );
}

// Usage example:
ElevatedButton(
  onPressed: () async {
    final friends = await _fetchFriends(); // Your method to get friends
    await startGroupCallWithUsers(
      context: context,
      users: friends,
    );
  },
  child: const Text('Call All Friends'),
)
```

---

## Example 5: Listen for Active Group Calls

Display a banner when there's an active group call:

```dart
// In your home screen or main navigation

import 'package:supper/utils/group_call_helper.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _groupCallSubscription;
  String? _activeCallId;

  @override
  void initState() {
    super.initState();
    _listenForActiveGroupCalls();
  }

  void _listenForActiveGroupCalls() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    _groupCallSubscription = FirebaseFirestore.instance
        .collection('group_calls')
        .where('status', whereIn: ['ringing', 'active'])
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final callId = doc.id;

        // Check if current user is a participant
        final participantDoc = await FirebaseFirestore.instance
            .collection('group_calls')
            .doc(callId)
            .collection('participants')
            .doc(currentUserId)
            .get();

        if (participantDoc.exists && mounted) {
          setState(() {
            _activeCallId = callId;
          });
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    _groupCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          // Show active call banner
          if (_activeCallId != null)
            GestureDetector(
              onTap: () async {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId != null) {
                  await GroupCallHelper.handleIncomingGroupCall(
                    context: context,
                    callId: _activeCallId!,
                    currentUserId: currentUserId,
                  );
                }
              },
              child: Container(
                color: Colors.green,
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.videocam, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Group call in progress - Tap to join',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

          // Rest of your home screen content
          Expanded(
            child: _buildHomeContent(),
          ),
        ],
      ),
    );
  }
}
```

---

## Example 6: Firebase Cloud Messaging (FCM) Integration

Handle group call notifications via FCM:

```dart
// In your main.dart or notification_handler.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supper/utils/group_call_helper.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'];

  if (type == 'group_video_call') {
    // Show local notification for incoming group call
    await _showGroupCallNotification(message);
  }
}

class NotificationHandler {
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
      final data = message.data;
      final type = data['type'];

      if (type == 'group_video_call') {
        _handleForegroundGroupCall(message);
      }
    });

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      final type = data['type'];

      if (type == 'group_video_call') {
        _handleNotificationTap(message);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _handleForegroundGroupCall(RemoteMessage message) async {
    final callId = message.data['callId'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (callId != null && currentUserId != null) {
      // Show local notification or in-app popup
      await _showInAppCallDialog(callId, currentUserId);
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final callId = message.data['callId'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (callId != null && currentUserId != null) {
      await GroupCallHelper.handleIncomingGroupCall(
        context: navigatorKey.currentContext!,
        callId: callId,
        currentUserId: currentUserId,
      );
    }
  }
}
```

---

## Example 7: Custom Participant Selection

Create your own custom participant selector:

```dart
// Custom contact list screen with group call option

class ContactListScreen extends StatefulWidget {
  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final Set<String> _selectedUserIds = {};
  List<UserProfile> _contacts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedUserIds.isEmpty
          ? 'Select Contacts'
          : '${_selectedUserIds.length} Selected'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: _startGroupCall,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          final isSelected = _selectedUserIds.contains(contact.uid);

          return CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedUserIds.add(contact.uid);
                } else {
                  _selectedUserIds.remove(contact.uid);
                }
              });
            },
            title: Text(contact.name),
            subtitle: Text(contact.email),
            secondary: SafeCircleAvatar(
              photoUrl: contact.photoUrl,
              name: contact.name,
              radius: 24,
            ),
          );
        },
      ),
    );
  }

  Future<void> _startGroupCall() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final selectedUsers = _contacts
        .where((c) => _selectedUserIds.contains(c.uid))
        .map((c) => {
          'userId': c.uid,
          'name': c.name,
          'photoUrl': c.photoUrl,
        })
        .toList();

    await GroupCallHelper.startGroupVideoCall(
      context: context,
      currentUserId: currentUser.uid,
      currentUserName: currentUser.displayName ?? 'You',
      currentUserPhotoUrl: currentUser.photoURL,
      selectedUsers: selectedUsers,
    );
  }
}
```

---

## Testing Checklist

Before going live, test these scenarios:

- ✅ Start group call with 2 participants
- ✅ Start group call with 4 participants
- ✅ Start group call with 8 participants (max)
- ✅ One participant declines
- ✅ One participant joins late
- ✅ One participant leaves mid-call
- ✅ Caller cancels before anyone joins
- ✅ Test on different network conditions
- ✅ Test mute/unmute functionality
- ✅ Test video toggle
- ✅ Test camera switch
- ✅ Test with poor WiFi connection
- ✅ Test notification delivery
- ✅ Test background/foreground handling

---

## Common Issues & Solutions

### Issue 1: Participants can't see video

**Solution:**
```dart
// Ensure video tracks are enabled in GroupVideoCallService
for (var track in _localStream!.getVideoTracks()) {
  track.enabled = true;
}
```

### Issue 2: Notifications not working

**Solution:**
```dart
// Make sure FCM token is saved to Firestore
final token = await FirebaseMessaging.instance.getToken();
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'fcmToken': token});
```

### Issue 3: High bandwidth usage

**Solution:**
```dart
// Reduce video quality in GroupVideoCallService
'video': {
  'width': {'ideal': 640, 'max': 1280},
  'height': {'ideal': 480, 'max': 720},
  'frameRate': {'ideal': 15, 'max': 30},
}
```

---

## Next Steps

1. **Test thoroughly** on real devices (not emulators)
2. **Monitor Firestore usage** in Firebase Console
3. **Set up proper notification handling** with FCM
4. **Add call history** to track completed calls
5. **Consider upgrading to SFU** for better scalability beyond 8 participants

For more details, see [GROUP_VIDEO_CALLING_GUIDE.md](./GROUP_VIDEO_CALLING_GUIDE.md)
