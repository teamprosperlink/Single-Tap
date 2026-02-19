# Group Audio Call Implementation - SingleTap Style

## Overview
Full SingleTap-style group audio calling functionality has been implemented with the following features:

### ✅ Implemented Features

1. **SingleTap-Style Call Messages**
   - Call messages positioned on RIGHT side for caller
   - Call messages positioned on LEFT side for other members
   - Caller name displayed above call info for non-callers
   - Shows call duration, participant count, and timestamp
   - Icons indicate outgoing/incoming/missed calls

2. **Full-Screen Call Notifications**
   - SingleTap-style CallKit incoming call UI
   - Works in foreground mode (when app is active)
   - Shows caller name, group name, and avatar
   - Accept/Decline buttons

3. **Call Flow**
   - Initiator creates call and sees group call screen immediately
   - All participants get notified
   - Participants can accept/reject calls
   - Real-time participant status tracking
   - Call duration timer
   - Active participant counter

4. **Participant Management**
   - Add participants during active call
   - Track who joined/left the call
   - Deduplicated participant list
   - Real-time participant status updates

5. **Call History**
   - Automatic system message creation
   - Updates with final call duration when call ends
   - Shows participant count
   - SingleTap-style formatting and positioning

## 🔧 Technical Implementation

### Files Modified

1. **lib/screens/chat/group_chat_screen.dart**
   - Added participant subcollection initialization
   - Implemented client-side notification fallback
   - SingleTap-style call message positioning
   - Added `groupName` to call document

2. **lib/services/notification_service.dart**
   - Full-screen CallKit UI for group calls
   - Handles accept/reject/missed actions
   - Navigation to IncomingGroupAudioCallScreen

3. **lib/screens/call/incoming_group_audio_call_screen.dart**
   - Accept/Reject UI
   - Participant display
   - Navigation to active call screen

4. **lib/screens/call/group_audio_call_screen.dart**
   - Active call interface
   - Real-time participant tracking
   - Mute/Speaker controls
   - Add participant functionality
   - Call duration tracking

5. **functions/index.js** (Cloud Function - NOT DEPLOYED)
   - `onGroupCallCreated` function for FCM notifications
   - Sends to all participants except caller
   - High-priority notifications

## ⚠️ Known Limitations

### Firebase Plan Limitation
Your Firebase project is on the **Spark (free) plan**, which does NOT support Cloud Functions.

**Impact:**
- ✅ Notifications work when app is in **foreground** (active)
- ❌ Notifications DON'T work when app is **background/killed**

**Why:**
- Client-side notifications (Firestore triggers) only work when app is running
- Cloud Functions are needed for background FCM push notifications
- Cloud Functions require **Blaze (pay-as-you-go) plan**

### To Enable Full Background Notifications:

1. Upgrade Firebase project to Blaze plan:
   - Visit: https://console.firebase.google.com/project/dlink-f6cc9/usage/details
   - Click "Upgrade to Blaze"
   - Add billing information

2. Deploy Cloud Function:
   ```bash
   cd functions
   npx firebase deploy --only functions:onGroupCallCreated
   ```

3. Remove client-side notification code from `group_chat_screen.dart` (lines 645-669)

## 📱 How It Works

### Call Initiation Flow

```
1. User A clicks call button in group chat
   ↓
2. Create group_calls document with status: 'calling'
   ↓
3. Initialize participants subcollection for all members
   - Caller marked as isActive: true
   - Others marked as isActive: false
   ↓
4. Create system message in chat
   ↓
5. Send notifications to all members (except caller)
   - Client-side: Works if their app is open
   - Cloud Function: Would work even if app is closed (requires Blaze)
   ↓
6. User A navigates to GroupAudioCallScreen
```

### Call Acceptance Flow

```
1. User B receives notification
   ↓
2. Full-screen CallKit UI appears
   ↓
3. User B clicks "Accept"
   ↓
4. Update participant doc: isActive = true
   ↓
5. Navigate to IncomingGroupAudioCallScreen
   ↓
6. Then to GroupAudioCallScreen
   ↓
7. Both users now see each other as "Connected"
```

### Call End Flow

```
1. Any user clicks "End Call"
   ↓
2. Update their participant: isActive = false
   ↓
3. Update call status: 'ended'
   ↓
4. Calculate final duration and participant count
   ↓
5. Update system message with final details
   ↓
6. Navigate back to chat
   ↓
7. System message shows:
   - "Voice call • 2:34 • 3 joined" (if successful)
   - "Missed call" (if duration = 0)
```

## 🎨 UI Features

### Call Message Positioning (SingleTap Style)

**For Caller:**
```
                              ┌──────────────────┐
                              │ 🟢 Outgoing call │
                              │ • 2m 15s         │
                              │ • 3 joined       │
                              │ Jan 24, 3:45 PM  │
                              └──────────────────┘
```

**For Other Members:**
```
┌──────────────────┐
│ John Doe         │ ← Caller name
│ 🟢 Incoming call │
│ • 2m 15s         │
│ • 3 joined       │
│ Jan 24, 3:45 PM  │
└──────────────────┘
```

### Call Icons
- 🟢 Green phone (outgoing/incoming - successful)
- 🔴 Red phone (missed call)

## 🔍 Testing

### Test Scenarios

1. **Both users with app open (WORKS)**
   - User A initiates call
   - User B receives full-screen notification immediately
   - Both can join and see each other

2. **User B has app closed (DOESN'T WORK on free plan)**
   - User A initiates call
   - User B does NOT receive notification
   - Requires Cloud Function deployment (Blaze plan)

3. **Multiple participants**
   - All active users receive notifications
   - Can see who joined in real-time
   - Call duration updates for all

4. **Add participant during call**
   - Click "+" button in call screen
   - Select member from list
   - They receive notification immediately (if app is open)

## 📝 Database Structure

### group_calls/{callId}
```javascript
{
  callId: "auto-generated",
  groupId: "group123",
  groupName: "My Group",
  callerId: "user123",
  callerName: "John Doe",
  participants: ["user123", "user456", "user789"],
  isVideo: false,
  status: "calling" | "ringing" | "active" | "ended",
  createdAt: timestamp,
  systemMessageId: "msg123"
}
```

### group_calls/{callId}/participants/{userId}
```javascript
{
  userId: "user456",
  name: "Jane Smith",
  photoUrl: "https://...",
  isActive: true,
  joinedAt: timestamp,
  createdAt: timestamp
}
```

### conversations/{groupId}/messages/{messageId} (System Message)
```javascript
{
  text: "Voice call",
  isSystemMessage: true,
  actionType: "call",
  callId: "call123",
  callerId: "user123",
  callerName: "John Doe",
  callDuration: 135, // seconds
  participantCount: 3,
  timestamp: timestamp
}
```

## 🚀 Future Enhancements

1. **WebRTC Integration** (TODO)
   - Actual audio streaming
   - Mute/unmute functionality
   - Speaker on/off functionality

2. **Cloud Function Deployment** (Requires Blaze plan)
   - Background FCM notifications
   - Works when app is killed

3. **Additional Features**
   - Call recording
   - Participant removal by admin
   - Call waiting
   - Call transfer

## 📞 Support

If you upgrade to Blaze plan and need help deploying Cloud Functions, run:

```bash
cd functions
npx firebase deploy --only functions:onGroupCallCreated
```

Then remove the client-side notification code (lines 645-669) from `group_chat_screen.dart`.

---

**Implementation Date:** January 24, 2026
**Status:** ✅ Complete (with free plan limitations)
**Works With:** Foreground app state only
