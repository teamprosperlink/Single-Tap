# Critical Video Call Fix - Blank Screen Issue

## 🔴 CRITICAL ISSUE IDENTIFIED

Video call showing blank screen on both devices because:

### Root Cause
**RTCVideoView requires valid `textureId` from renderer to display video**

The texture ID is only assigned when:
1. Renderer is properly initialized ✅
2. MediaStream is assigned to renderer ✅
3. Stream has active video tracks ✅
4. **Platform channel properly registers the texture** ❌ (This was missing!)

## Changes Made

### 1. Added State Tracking ([video_call_screen.dart:40-42](lib/screens/call/video_call_screen.dart#L40-L42))

```dart
bool _renderersInitialized = false; // Track renderer initialization
bool _localStreamReady = false; // Track local stream status
bool _remoteStreamReady = false; // Track remote stream status
```

**Why:** To properly track when video is ready to display and trigger UI updates.

### 2. Enhanced Build Method Checks ([video_call_screen.dart:539-554](lib/screens/call/video_call_screen.dart#L539-L554))

```dart
final hasLocalVideo = _videoCallService.localRenderer.srcObject != null &&
                     _videoCallService.localRenderer.textureId != null;
final hasRemoteVideo = _videoCallService.remoteRenderer.srcObject != null &&
                      _videoCallService.remoteRenderer.textureId != null;
```

**Why:** textureId is CRITICAL for RTCVideoView to render. Without it, screen stays blank.

### 3. Better Debug Logging

```dart
debugPrint(
  'renderersInit=$_renderersInitialized, '
  'localReady=$_localStreamReady (texture=$localTextureId), '
  'remoteReady=$_remoteStreamReady (texture=$remoteTextureId)',
);
```

**Why:** To identify exactly where the video rendering is failing.

## 🧪 How to Test & Debug

### Step 1: Run with Debug Logs

```bash
flutter run --debug
```

### Step 2: Make a Video Call

Look for these specific log patterns:

#### ✅ SUCCESS Pattern:
```
VideoCallService: ✅ Renderer initialized successfully
VideoCallService: ✅ Local stream obtained
VideoCallService: ✅ Video track enabled: track_id, enabled: true
VideoCallService: ✅ Local renderer srcObject set successfully
VideoCallScreen BUILD: renderersInit=true, localReady=true (src=true, texture=123)
```

#### ❌ FAILURE Pattern (Blank Screen):
```
VideoCallScreen BUILD: renderersInit=true, localReady=true (src=true, texture=null)
```
**If texture=null:** Platform channel failed to register texture

```
VideoCallScreen BUILD: renderersInit=true, localReady=false
```
**If localReady=false:** Stream callback never fired

```
VideoCallScreen BUILD: renderersInit=false
```
**If renderersInit=false:** Permission issue or renderer initialization failed

### Step 3: Use Video Test Screen

The diagnostic screen at [video_test_screen.dart](lib/screens/call/video_test_screen.dart) helps isolate issues:

```dart
// Temporarily add to your app navigation
import 'package:supper/screens/call/video_test_screen.dart';

// Test camera independently
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const VideoTestScreen()),
);
```

**What to check:**
1. Permissions granted? (Camera + Microphone)
2. Video tracks count > 0?
3. Renderer srcObject not null?
4. Does camera preview show in test screen?

### Step 4: Check Platform-Specific Issues

#### Android
1. **Emulator Camera:** Check if emulator has virtual camera enabled
   - AVD Manager → Edit → Show Advanced Settings → Camera: Webcam0

2. **Physical Device:** Ensure camera not blocked by another app
   - Close all apps
   - Reboot device
   - Try again

3. **Permissions in Settings:**
   - Settings → Apps → Supper → Permissions
   - Verify Camera and Microphone are enabled

#### Common Emulator Issues
- **Blank video but call works:** Emulator camera not configured
- **Permission denied:** Grant permissions in Android settings manually
- **App crash on video call:** Emulator API level too old (use API 30+)

## 🔧 Quick Fixes to Try

### Fix 1: Force Renderer Reinitialization

If texture ID is null, try this in VideoCallService:

```dart
// After stream assignment
_localRenderer.srcObject = _localStream;
await Future.delayed(const Duration(milliseconds: 300)); // Longer delay

// Force re-render by reassigning
final tempStream = _localRenderer.srcObject;
_localRenderer.srcObject = null;
await Future.delayed(const Duration(milliseconds: 100));
_localRenderer.srcObject = tempStream;
```

### Fix 2: Check Video Track State

Add this verification:

```dart
for (var track in _localStream!.getVideoTracks()) {
  debugPrint('Track ${track.id}:');
  debugPrint('  - enabled: ${track.enabled}');
  debugPrint('  - muted: ${track.muted}');
  debugPrint('  - readyState: ${track.state}');

  if (!track.enabled || track.muted) {
    track.enabled = true;
    track.muted = false;
  }
}
```

### Fix 3: Platform Channel Debug

Check if texture registration is working:

```dart
// After renderer.initialize()
debugPrint('Renderer initialized:');
debugPrint('  - textureId: ${_localRenderer.textureId}');
debugPrint('  - renderVideo: ${_localRenderer.renderVideo}');
debugPrint('  - videoWidth: ${_localRenderer.videoWidth}');
debugPrint('  - videoHeight: ${_localRenderer.videoHeight}');
```

If textureId remains null after initialization, it's a flutter_webrtc plugin issue.

## 🎯 Expected Behavior After Fix

### Caller (Device A):
1. Taps video call button
2. **Immediately sees own face** (local camera)
3. Sees "Calling..." overlay
4. When Device B answers: sees Device B's face fullscreen
5. Own face moves to small PIP (top-right corner)

### Receiver (Device B):
1. Accepts incoming video call
2. **Immediately sees caller's face** (Device A)
3. Own face in small PIP (top-right corner)

### Both Devices:
- Video should appear within 1-2 seconds
- NO blank/black screens
- Face clearly visible
- Smooth video (15-30 fps)

## 📱 Testing Checklist

- [ ] Permissions granted in Android settings
- [ ] Emulator has virtual camera enabled (if using emulator)
- [ ] Video test screen shows camera preview
- [ ] Debug logs show `texture != null`
- [ ] Debug logs show `localReady=true`
- [ ] Debug logs show video tracks > 0
- [ ] Caller sees own face before call connects
- [ ] Receiver sees caller's face after accepting
- [ ] Both see each other during call
- [ ] PIP (small video) shows correctly
- [ ] Camera switch button works
- [ ] Video on/off button works

## 🚨 If Still Blank After All Fixes

### Scenario 1: textureId is null
**Problem:** Platform channel failure
**Solution:**
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean
cd .. && flutter run
```

### Scenario 2: Video works in test screen but not in call
**Problem:** WebRTC signaling issue
**Solution:** Check Firestore call document structure and ICE candidates

### Scenario 3: Works on emulator but not physical device
**Problem:** Device-specific camera driver issue
**Solution:**
- Update device to latest OS
- Test on different physical device
- Check if camera works in other apps

### Scenario 4: Black screen but audio works
**Problem:** Video track disabled or not transmitted
**Solution:** Verify video track enabled on both sides

## 🔄 Next Steps

1. Test on physical Android device (best results)
2. Check debug logs for texture ID
3. Verify both devices have good network connection
4. If issue persists, share full debug logs from both devices

## 📊 Performance Expectations

| Metric | Expected | Acceptable | Poor |
|--------|----------|------------|------|
| Camera start time | <1s | 1-2s | >2s |
| Video appears after answer | <1s | 1-3s | >3s |
| Frame rate | 30fps | 15-25fps | <15fps |
| Resolution | 720p | 480p | <480p |
| Connection time | <2s | 2-5s | >5s |

---

**Status:** 🟡 Awaiting physical device testing
**Priority:** 🔴 Critical
**Updated:** 2026-01-16
