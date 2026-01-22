# Video Call Testing Guide - Blank Screen Debugging

## 🎯 Quick Start Testing

### Option 1: Test on Physical Device (RECOMMENDED)

```bash
# Connect Android phone via USB
adb devices

# Run app on phone
flutter run -d <device-id>
```

### Option 2: Test on Emulator

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator-id>

# Run app
flutter run
```

## 📱 Step-by-Step Testing Process

### Test 1: Camera Permission Test (2 minutes)

1. Install and open app
2. Navigate to any screen
3. Try to trigger camera (e.g., profile photo upload)
4. **Expected:** Permission dialog appears
5. Grant camera and microphone permissions
6. **Expected:** Camera preview shows

**If camera doesn't work here, video calls won't work either!**

### Test 2: Video Test Screen (3 minutes)

Temporarily add navigation to test screen:

```dart
// In lib/screens/home/main_navigation_screen.dart or anywhere
import 'package:supper/screens/call/video_test_screen.dart';

// Add a button
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoTestScreen()),
    );
  },
  child: const Text('Test Video'),
)
```

**Test Steps:**
1. Tap "Test Video" button
2. Tap "Permissions" → Verify both granted
3. Tap "Start" → Camera should show immediately
4. Check logs at bottom for errors
5. Tap "Switch" → Camera should flip
6. Verify "Has video: true (tracks: 1)"

**Success Criteria:**
- ✅ Camera preview visible within 1 second
- ✅ No errors in logs
- ✅ Video track count = 1
- ✅ Status shows "Camera started successfully"

**If this test fails, DON'T proceed to actual calls!**

### Test 3: Single Device Video Call Test (5 minutes)

**Preparation:**
- Create two Firebase test accounts
- Login on same device alternately

**Steps:**
1. Login as User A
2. Start video call to User B
3. **Expected:** See own face immediately
4. Note the debug logs
5. Logout and login as User B
6. Check for incoming call notification

**What to check:**
```
Debug logs should show:
✅ VideoCallService: Renderer initialized
✅ VideoCallService: Local stream obtained
✅ VideoCallService: Video track enabled: true
✅ VideoCallScreen BUILD: localReady=true, texture=<number>
```

### Test 4: Two Device Video Call Test (10 minutes)

**Requirements:**
- 2 Android devices OR 1 device + 1 emulator
- Both logged into different accounts
- Good WiFi connection

**Device A (Caller):**
1. Open chat with Device B user
2. Tap video call button (📹)
3. **CHECKPOINT 1:** Should see own face immediately
4. Screen should show "Calling..."
5. Wait for Device B to answer

**Device B (Receiver):**
1. Should receive notification
2. Tap "Accept" on incoming call screen
3. **CHECKPOINT 2:** Should see Device A's face
4. Own face should be in small PIP (top-right)

**During Call:**
- [x] Both see each other's faces clearly
- [x] No black/blank screens
- [x] Video is smooth (not frozen)
- [x] Audio works
- [x] Can switch camera
- [x] Can toggle video on/off
- [x] PIP shows correctly

## 🐛 Common Issues & Solutions

### Issue 1: Permissions Denied
**Symptoms:** App crashes or shows permission error

**Solution:**
```bash
# Grant permissions manually via ADB
adb shell pm grant com.app.supper android.permission.CAMERA
adb shell pm grant com.app.supper android.permission.RECORD_AUDIO
```

Or in device settings:
```
Settings → Apps → Supper → Permissions → Enable all
```

### Issue 2: Blank Screen on Emulator
**Symptoms:** Call connects but video is black

**Root Cause:** Emulator camera not configured

**Solution:**
1. Open AVD Manager in Android Studio
2. Click Edit (pencil icon) on your emulator
3. Click "Show Advanced Settings"
4. Under Camera:
   - Front: `Webcam0` (your laptop camera)
   - Back: `VirtualScene` or `Webcam0`
5. Save and restart emulator

### Issue 3: "texture=null" in Logs
**Symptoms:** Debug shows `texture=null`

**Root Cause:** Platform channel initialization failed

**Solution:**
```bash
# Complete clean rebuild
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run --no-hot-reload
```

### Issue 4: Works in Test Screen, Fails in Calls
**Symptoms:** Video test screen works, but actual calls show blank

**Root Cause:** WebRTC peer connection or signaling issue

**Check:**
1. Firestore rules allow read/write on `calls` collection
2. Internet connection stable on both devices
3. ICE candidates being exchanged (check Firestore)

**Solution:**
```dart
// Check Firestore call document
await FirebaseFirestore.instance
  .collection('calls')
  .doc(callId)
  .get()
  .then((doc) {
    print('Call data: ${doc.data()}');
    print('Has offer: ${doc.data()?['offer'] != null}');
    print('Has answer: ${doc.data()?['answer'] != null}');
  });
```

### Issue 5: Black Screen But Audio Works
**Symptoms:** Can hear other person but can't see them

**Root Cause:** Video tracks not being transmitted

**Check Debug Logs:**
```
❌ BAD: "Local stream has 1 audio tracks and 0 video tracks"
✅ GOOD: "Local stream has 1 audio tracks and 1 video tracks"
```

**Solution:**
Verify video constraints in VideoCallService:
```dart
'video': {
  'facingMode': 'user',  // NOT null
  'width': {'ideal': 1280, 'min': 640},  // NOT empty
  'height': {'ideal': 720, 'min': 480},
  'frameRate': {'ideal': 30, 'min': 15},
}
```

### Issue 6: Camera Opens Then Immediately Closes
**Symptoms:** Brief flash of camera, then black

**Root Cause:** Stream being disposed prematurely

**Check:**
```dart
// Ensure dispose is NOT called during active call
if (_localStream != null && !_isEndingCall) {
  // Keep stream alive
}
```

## 📊 Debug Log Analysis

### ✅ Healthy Logs Pattern

```
VideoCallService: Requesting user media with constraints...
VideoCallService: ✅ Local stream obtained, ID: some-uuid
VideoCallService: Local stream has 1 audio tracks and 1 video tracks
VideoCallService: ✅ Video track enabled: track-id, kind: video, enabled: true
VideoCallService: ✅ Audio track enabled: track-id, kind: audio, enabled: true
VideoCallService: ✅ Added audio track to peer connection
VideoCallService: ✅ Added video track to peer connection
VideoCallService: Assigning local stream to renderer...
VideoCallService: ✅ Local renderer srcObject set successfully
VideoCallService: 📹 Local stream ready callback triggered
VideoCallScreen BUILD: renderersInit=true, localReady=true (src=true, texture=123, tracks: 1)
```

### ❌ Unhealthy Logs Pattern

```
VideoCallService: ❌ Initialization error - Permission denied
```
**Fix:** Grant permissions

```
VideoCallService: ❌ Error getting local stream: No video tracks in local stream
```
**Fix:** Camera hardware issue or constraints wrong

```
VideoCallScreen BUILD: renderersInit=true, localReady=false (src=false, texture=null, tracks: 0)
```
**Fix:** Stream never assigned or callback failed

```
VideoCallService: ⚠️ Could not set speaker: error
```
**Non-critical:** Audio will work through earpiece

## 🎬 Screen Recording for Bug Reports

If issue persists, record screen and share:

### Android:
1. Swipe down notification panel
2. Tap "Screen record"
3. Reproduce issue
4. Stop recording
5. Share video + logs

### Get Logs:
```bash
# While app is running
flutter logs > video_call_logs.txt

# OR use adb
adb logcat -d > video_call_logs.txt
```

## 🔍 Advanced Debugging

### Enable WebRTC Native Logs

Add to AndroidManifest.xml:
```xml
<application
    android:name="${applicationName}"
    android:debuggable="true">
    <!-- Enable WebRTC logging -->
</application>
```

### Monitor Firestore Real-Time

Open Firebase Console → Firestore → Watch `calls` collection during call:

**What to check:**
- `status`: Should progress `calling` → `ringing` → `connected`
- `offer`: Should appear within 1 second (from caller)
- `answer`: Should appear within 1 second (from receiver)
- `callerCandidates`: Should have ICE candidates
- `receiverCandidates`: Should have ICE candidates

**If missing:**
- Signaling failing
- Network blocked
- Firestore rules wrong

### Check Network Connectivity

```bash
# Test STUN server
adb shell ping stun.l.google.com

# Check firewall
# Ensure ports 3478, 19302 not blocked
```

## 📈 Performance Monitoring

### Frame Rate Check
During call, check logs for frame drops:
```
Good: 30 fps consistently
Acceptable: 20-29 fps
Poor: <20 fps (choppy video)
```

### Resolution Check
```dart
debugPrint('Video resolution: ${_localRenderer.videoWidth}x${_localRenderer.videoHeight}');

// Expected:
// 1280x720 (HD) - Best
// 640x480 (SD) - Acceptable
// <640x480 - Poor quality
```

### Bandwidth Usage
Video calls use ~1-2 Mbps per direction
- Test on WiFi first
- Mobile data may be slow/expensive

## 🎯 Success Criteria

Call is successful when:
- [x] Camera appears <1 second on caller side
- [x] Other person's face visible <2 seconds after answer
- [x] Video smooth (no freezing)
- [x] Audio clear and synced
- [x] Can toggle camera, mute, video
- [x] No crashes or errors
- [x] PIP shows correctly when connected

## 📞 Support

If all tests fail:
1. Share full logs from both devices
2. Share screen recording
3. Note device models and Android versions
4. Describe exact symptoms
5. Mention when issue started (after update? new device?)

---

**Remember:** Test on **physical devices** for best results. Emulators can have camera issues that don't represent real-world behavior.
