# Group Audio Call Fix - Real-time Firestore Listener

## Problem
Group audio calls were not working properly:
- ❌ Other members not receiving notifications
- ❌ All calls showing as "Missed call"
- ❌ No incoming call UI showing to participants
- ❌ Only caller seeing the call screen

## Root Cause
The client-side notification method (`sendNotificationToUser`) was only storing notifications in Firestore but **not triggering actual CallKit UI** for incoming calls.

## Solution Implemented

### 1. **Real-time Firestore Listener**
Added a Firestore listener that automatically detects new group calls:

```dart
void startListeningForGroupCalls() {
  _firestore
    .collection('group_calls')
    .where('participants', arrayContains: currentUserId)
    .where('status', isEqualTo: 'calling')
    .snapshots()
    .listen((snapshot) {
      // When new call detected, show CallKit UI immediately
      await _navigateToGroupCall(callData);
    });
}
```

### 2. **Automatic Initialization After Login**
Listener starts automatically after user logs in (from MainNavigationScreen):

```dart
void _safeInit() {
  // ... other initializations ...

  // Start listening for group audio calls (Firestore real-time listener)
  try {
    NotificationService().startListeningForGroupCalls();
    debugPrint('✅ Group call listener initialized in MainNavigationScreen');
  } catch (e) {
    debugPrint('Error starting group call listener: $e');
  }
}
```

**Important:** The listener is initialized in `MainNavigationScreen` (not in `NotificationService.initialize()`) to ensure the user is logged in before starting the listener.

### 3. **Removed Redundant Client-Side Notifications**
Removed the manual notification sending loop since Firestore listener handles it automatically.

## How It Works Now

### Call Flow:

```
1. User A clicks call button
   ↓
2. Create group_calls document in Firestore
   {
     status: 'calling',
     participants: [userA, userB, userC],
     callerId: userA,
     ...
   }
   ↓
3. Firestore listener (running on all users' devices) detects new call
   ↓
4. For User B and User C:
   - Listener sees: "New call where I'm a participant"
   - Automatically shows CallKit full-screen UI
   - Ring tone starts
   - Accept/Decline buttons appear
   ↓
5. User B clicks "Accept"
   ↓
6. Navigate to call screen
   ↓
7. Both users see each other as "Connected"
```

## Files Modified

### 1. `lib/services/notification_service.dart`
- ✅ Added `dart:async` import for StreamSubscription
- ✅ Added `startListeningForGroupCalls()` method
- ✅ Added `stopListeningForGroupCalls()` method
- ✅ Removed listener call from `initialize()` method (moved to MainNavigationScreen)

### 2. `lib/screens/home/main_navigation_screen.dart`
- ✅ Added group call listener initialization in `_safeInit()` method
- ✅ Listener starts after user login, ensuring `currentUser` is available

### 3. `lib/screens/chat/group_chat_screen.dart`
- ✅ Removed client-side notification loop
- ✅ Removed unused NotificationService import
- ✅ Added debug message confirming Firestore listener handles notifications

## Testing

### Scenario 1: Both Users with App Open ✅
1. User A creates group call
2. User B immediately sees full-screen incoming call UI
3. User B clicks Accept
4. Both users enter call screen and see each other

### Scenario 2: User B Has App Closed ⚠️
1. User A creates group call
2. User B does NOT receive notification (requires Cloud Functions + Blaze plan)

## Important Notes

### ✅ What Works NOW:
- Full-screen CallKit incoming call UI
- SingleTap-style call messages (positioned correctly)
- Call duration tracking
- Participant count display
- Real-time call status updates
- Accept/Reject functionality
- Works when **both users have app open**

### ⚠️ Limitation (Free Plan):
- Notifications only work when app is **OPEN/FOREGROUND**
- Does NOT work when app is **CLOSED/BACKGROUND**
- Requires Firebase Blaze plan + Cloud Functions for background notifications

## Next Steps

### For Full SingleTap Experience:
1. Upgrade to Firebase Blaze plan
2. Deploy Cloud Function:
   ```bash
   cd functions
   npx firebase deploy --only functions:onGroupCallCreated
   ```
3. Then notifications will work even when app is closed

### Current Recommendation:
- For testing/development: Current implementation is sufficient
- For production: Upgrade to Blaze plan for full functionality

## Summary

**Before:**
- ❌ No incoming call UI showing
- ❌ All calls marked as missed
- ❌ Notifications not working

**After:**
- ✅ Full-screen incoming call UI (SingleTap-style)
- ✅ Real-time call detection via Firestore
- ✅ Automatic CallKit trigger
- ✅ Works perfectly when app is open
- ✅ SingleTap-style call history and positioning

---

**Implementation Date:** January 24, 2026
**Status:** ✅ Working (with app open requirement)
**Known Limitation:** Requires app to be open for notifications (free plan constraint)
