# Video Call Incoming Screen - Debug Guide

## Issue: Video call receive karte waqt error

### Step 1: Check Console Logs

Jab video call receive ho, console mein yeh logs dekhne chahiye:

```
📞 _showIncomingCall: Showing IncomingCallScreen for callId=xyz123
✅ Ended all CallKit calls to prevent conflict
📱 Call type: video         ← YEH IMPORTANT HAI
✅ Call status updated to ringing
✅ Video call accepted: Resetting _isShowingIncomingCall flag
```

**Agar `Call type: audio` dikhe instead of `video`, toh issue hai!**

### Step 2: Verify Call Document in Firestore

Firebase Console mein jao:
1. Open Firestore Database
2. Navigate to `calls` collection
3. Find recent call document
4. Check `type` field:
   - ✅ Should be: `"video"`
   - ❌ If missing or `"audio"`: Problem found!

### Step 3: Quick Fix - Force Video Call Type

Agar `type` field missing hai, toh yeh temporary fix try karein:

#### Option A: Debug Mode Fix
[lib/screens/home/main_navigation_screen.dart](lib/screens/home/main_navigation_screen.dart) mein line 506 ke baad add karein:

```dart
// Get call type (audio/video) from Firestore
String callType = 'audio'; // default
try {
  final callDoc = await _firestore.collection('calls').doc(callId).get();
  callType = callDoc.data()?['type'] ?? 'audio';

  // DEBUG: Force log the entire call document
  debugPrint('🔍 Full call document: ${callDoc.data()}');
  debugPrint('📱 Call type: $callType');
} catch (e) {
  debugPrint('⚠️ Error getting call type: $e');
}
```

Run karein aur console output share karein.

### Step 4: Check if IncomingVideoCallScreen Properly Imported

File: [lib/screens/home/main_navigation_screen.dart](lib/screens/home/main_navigation_screen.dart)

Line 23 pe yeh import hona chahiye:
```dart
import '../call/incoming_video_call_screen.dart';
```

### Step 5: Verify Video Call Screen File Exists

Check karein ki yeh file exist karti hai:
```
lib/screens/call/incoming_video_call_screen.dart
```

### Step 6: Common Errors & Solutions

#### Error 1: "Class IncomingVideoCallScreen not found"
**Solution:**
```bash
cd c:\Users\csp\Documents\plink-live
flutter clean
flutter pub get
flutter run
```

#### Error 2: Screen shows but then crashes
**Problem:** Shayad `UserProfile.fromFirestore()` mein issue
**Solution:** Check if caller's user document exists in Firestore

#### Error 3: Audio call screen shows instead of video
**Problem:** `type` field not set or wrong
**Solution:**
1. Delete old call documents from Firestore
2. Create fresh video call
3. Check logs for call type

#### Error 4: "Failed to show incoming call"
**Problem:** Navigation error
**Solution:** Check if context is mounted:
```dart
if (mounted && context.mounted) {
  // Navigate
}
```

### Step 7: Test with Debug Prints

Add yeh debug code `_showIncomingCall` mein:

```dart
void _showIncomingCall({
  required String callId,
  required String callerName,
  String? callerPhoto,
  required String callerId,
}) async {
  debugPrint('🔥 _showIncomingCall STARTED');
  debugPrint('🔥 callId: $callId');
  debugPrint('🔥 callerName: $callerName');
  debugPrint('🔥 callerId: $callerId');

  if (_isShowingIncomingCall) {
    debugPrint('❌ Already showing incoming call, returning');
    return;
  }

  _isShowingIncomingCall = true;
  HapticFeedback.heavyImpact();

  // ... rest of code

  // Get call type
  String callType = 'audio';
  try {
    final callDoc = await _firestore.collection('calls').doc(callId).get();
    final data = callDoc.data();
    debugPrint('🔥 Call document data: $data');
    callType = data?['type'] ?? 'audio';
    debugPrint('🔥 Detected call type: $callType');
  } catch (e) {
    debugPrint('❌ Error getting call type: $e');
  }

  // Show screen
  if (callType == 'video') {
    debugPrint('✅ Showing VIDEO call screen');
    // ...
  } else {
    debugPrint('✅ Showing AUDIO call screen');
    // ...
  }
}
```

### Step 8: Manual Test

**Test karne ka tarika:**

1. **Device A (Caller):**
   - Open app
   - Go to chat with Device B
   - Tap video call icon (camera icon)
   - Wait...

2. **Device B (Receiver):**
   - App should automatically show incoming screen
   - Check console logs
   - Take screenshot if error shows

3. **Expected on Device B:**
   - Incoming video call screen with caller's photo
   - "Incoming video call" text at top
   - Green Accept button, Red Decline button
   - Ringtone playing

### Step 9: Alternative - Direct Navigation Test

Test incoming screen directly:

```dart
// Add temporary button in any screen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingVideoCallScreen(
          callId: 'test123',
          callerName: 'Test User',
          callerPhoto: null,
          callerId: 'testUserId123',
        ),
      ),
    );
  },
  child: Text('Test Video Call Screen'),
)
```

Agar yeh kaam kare, toh screen theek hai - issue call detection mein hai.

### Step 10: Share Debug Info

Kripya yeh info share karein:

1. **Console logs** (complete)
2. **Error message** (exact text)
3. **Firestore call document** (screenshot)
4. **App behavior:**
   - Incoming screen shows? YES/NO
   - Which screen shows? (Video incoming / Audio incoming / Direct call screen)
   - Crash hota hai? YES/NO

## Quick Fix Commands

```bash
# Clean and rebuild
cd c:\Users\csp\Documents\plink-live
flutter clean
flutter pub get
flutter run

# Check for errors
flutter analyze lib/screens/call/incoming_video_call_screen.dart
flutter analyze lib/screens/home/main_navigation_screen.dart
```

## Expected Console Output (Success Case)

```
📞 _showIncomingCall: Showing IncomingCallScreen for callId=abc123
✅ Ended all CallKit calls to prevent conflict
🔍 Full call document: {
  callerId: user1,
  receiverId: user2,
  type: video,           ← MUST BE "video"
  status: calling,
  callerName: John Doe,
  callerPhoto: https://...,
  timestamp: ...
}
📱 Call type: video
✅ Call status updated to ringing
✅ Showing VIDEO call screen      ← Should say VIDEO not AUDIO
📞 IncomingVideoCallScreen: Status changed to ringing
📱 Ringtone started playing
```

Agar yeh output nahi aa raha, toh exact output share karein!
