# Voice Call Profile Display Issue - Debug Guide

## Problem
Both users (caller and receiver) are seeing their own profile (name, photo) during a voice call instead of seeing the other person's profile.

## Expected Behavior
- **Caller (User A)**: Should see receiver's (User B's) name and photo
- **Receiver (User B)**: Should see caller's (User A's) name and photo

## Changes Made for Debugging

### 1. Added Debug Logging
Added comprehensive debug logging to trace user profiles through the call flow:

#### Files Modified:
1. **`lib/screens/call/voice_call_screen.dart`** (line 50):
   - Logs `otherUser` details when VoiceCallScreen initializes
   - Shows: `otherUser name` and `uid`

2. **`lib/screens/chat/incoming_call_screen.dart`** (lines 241, 292):
   - Logs caller profile when fetched from Firestore
   - Logs caller profile when navigating to VoiceCallScreen

3. **`lib/services/notification_service.dart`** (line 213):
   - Logs caller profile when handling call accepted via notification

4. **`lib/screens/chat/enhanced_chat_screen.dart`** (line 6071):
   - Logs `otherUser` and `currentUserId` when initiating a voice call

## How to Test & Debug

### Test Steps:
1. **Device A (Caller "suryalink")**: Open chat with another user
2. **Device A**: Tap the voice call button
3. **Watch logs on Device A** for this sequence:
   ```
   EnhancedChatScreen: Starting voice call - otherUser: [OTHER_USER_NAME] ([OTHER_USER_UID]), currentUserId: [YOUR_UID]
   VoiceCallScreen: initState - callId=[CALL_ID], isOutgoing=true, otherUser=[OTHER_USER_NAME] ([OTHER_USER_UID])
   ```

4. **Device B (Receiver)**: Accept the incoming call
5. **Watch logs on Device B** for this sequence:
   ```
   IncomingCallScreen: Fetched caller profile
   IncomingCallScreen: Using Firestore profile - [CALLER_NAME] (UID: [CALLER_UID])
   IncomingCallScreen: Navigating to VoiceCallScreen with callerProfile: [CALLER_NAME] ([CALLER_UID])
   VoiceCallScreen: initState - callId=[CALL_ID], isOutgoing=false, otherUser=[CALLER_NAME] ([CALLER_UID])
   ```

### What to Look For:
1. **Device A logs should show**:
   - `otherUser` = Device B's name and UID
   - `currentUserId` = Device A's UID

2. **Device B logs should show**:
   - `callerProfile` = Device A's name and UID
   - `otherUser` = Device A's name and UID

### If Logs Show Correct Data But UI Shows Wrong Profile:
This would mean the issue is in the UI layer (`_buildUserInfo()` method in VoiceCallScreen).

### If Logs Show Wrong Data:
This means the issue is in how profiles are being fetched/passed.

## Potential Root Causes

### Scenario 1: EnhancedChatScreen passes wrong profile
- Check if `widget.otherUser` in EnhancedChatScreen is actually the current user
- Verify the chat screen is initialized with the correct `otherUser`

### Scenario 2: Firestore query returns wrong user
- In `notification_service.dart` and `incoming_call_screen.dart`
- Check if `callerId` in the call document is correct
- Verify `callDoc.data()['callerId']` matches the actual caller's UID

### Scenario 3: Call document has wrong IDs
- Check the call document in Firestore:
  ```
  callerId: [Should be Device A's UID]
  receiverId: [Should be Device B's UID]
  callerName: [Should be Device A's name]
  receiverName: [Should be Device B's name]
  ```

### Scenario 4: VoiceCallScreen displays current user instead of otherUser
- Bug in `_buildUserInfo()` method
- Currently shows: `widget.otherUser.name` (line 570)
- Should be correct, but verify this is not accidentally using current user

## Code Verification Checklist

✅ **EnhancedChatScreen (line 6078)**: Passes `widget.otherUser` ← Correct
✅ **IncomingCallScreen (line 295)**: Passes `callerProfile` fetched from Firestore ← Correct
✅ **NotificationService (line 218)**: Passes `callerProfile` fetched from Firestore ← Correct
✅ **CallHistoryScreen (line 546)**: Passes `userProfile` created from call history ← Correct
✅ **VoiceCallScreen (line 570)**: Displays `widget.otherUser.name` ← Correct

## Next Steps

1. **Run the app with these changes**
2. **Make a voice call between two devices**
3. **Collect the debug logs** from both devices
4. **Share the logs** to identify where the wrong profile is being passed
5. Based on logs, we can pinpoint the exact location of the bug

## Expected Debug Output

### Device A (Caller - suryalink) Logs:
```
EnhancedChatScreen: Starting voice call - otherUser: ReceiverName (receiver-uid-123), currentUserId: suryalink-uid-456
VoiceCallScreen: initState - callId=call-789, isOutgoing=true, otherUser=ReceiverName (receiver-uid-123)
```

### Device B (Receiver) Logs:
```
IncomingCallScreen: Using Firestore profile - suryalink (UID: suryalink-uid-456)
IncomingCallScreen: Navigating to VoiceCallScreen with callerProfile: suryalink (suryalink-uid-456)
VoiceCallScreen: initState - callId=call-789, isOutgoing=false, otherUser=suryalink (suryalink-uid-456)
```

If logs show correct data but UI is wrong, the issue is in VoiceCallScreen's `_buildUserInfo()`.
If logs show wrong data, the issue is earlier in the call flow.
