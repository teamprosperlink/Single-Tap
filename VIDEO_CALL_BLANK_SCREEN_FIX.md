# Video Call Blank Screen Fix

## Problem
Video call screen showing blank/black screen instead of camera feed on both devices (caller and receiver) during video calls.

## Root Causes Identified

### 1. **Renderer Initialization Race Condition**
- Renderers were being initialized but not properly cleaned before reuse
- Multiple initialization attempts without proper disposal causing conflicts

### 2. **Video Track Enabling Issues**
- Video tracks not explicitly enabled after stream creation
- Missing verification that tracks exist before rendering

### 3. **Media Constraints Issues**
- Using old-style constraints format (`mandatory`/`optional`) instead of modern format
- Not optimal for all devices

### 4. **Stream Assignment Timing**
- Insufficient delay between stream creation and renderer assignment
- No verification that renderer actually received the stream

## Fixes Applied

### 1. VideoCallService Initialization ([video_call_service.dart:89-148](lib/services/other services/video_call_service.dart#L89-L148))

**Before:**
```dart
try {
  await _localRenderer.initialize();
} catch (e) {
  // Try again if already initialized
}
```

**After:**
```dart
// Dispose first if already exists to ensure clean state
try {
  await _localRenderer.dispose();
} catch (e) {
  // Ignore if not initialized
}

// Now initialize fresh
await _localRenderer.initialize();
debugPrint('  VideoCallService: ✅ Local renderer initialized');

await _remoteRenderer.initialize();
debugPrint('  VideoCallService: ✅ Remote renderer initialized');
```

**Why:** Ensures clean state by disposing old renderers before reinitializing, preventing conflicts.

### 2. Local Stream Creation ([video_call_service.dart:307-402](lib/services/other services/video_call_service.dart#L307-L402))

**Before:**
```dart
final mediaConstraints = {
  'video': {
    'facingMode': _isFrontCamera ? 'user' : 'environment',
    'mandatory': {
      'minWidth': '640',
      'minHeight': '480',
    },
    'optional': [...]
  }
};
```

**After:**
```dart
// Platform-optimized media constraints
final mediaConstraints = {
  'audio': {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  },
  'video': {
    'facingMode': _isFrontCamera ? 'user' : 'environment',
    'width': {'ideal': 1280, 'min': 640},
    'height': {'ideal': 720, 'min': 480},
    'frameRate': {'ideal': 30, 'min': 15},
  },
};

// Verify we have video tracks
if (_localStream!.getVideoTracks().isEmpty) {
  throw Exception('No video tracks in local stream');
}

// CRITICAL: Enable all tracks explicitly
for (var track in _localStream!.getVideoTracks()) {
  track.enabled = true;
  debugPrint('✅ Video track enabled: ${track.id}');
}

// Wait for renderer to process the stream
await Future.delayed(const Duration(milliseconds: 200));

// Verify renderer has the stream
if (_localRenderer.srcObject == null) {
  throw Exception('Failed to assign local stream to renderer');
}
```

**Why:**
- Modern constraint format for better device compatibility
- Explicit track enabling ensures video is active
- Verification steps catch issues early
- Delay allows renderer to properly process the stream

### 3. Video Call Screen UI Updates ([video_call_screen.dart:517-652](lib/screens/call/video_call_screen.dart#L517-L652))

**Added:**
- Track count verification before rendering
- Better debug logging showing track status
- Fallback UI showing user avatar when video is loading
- Proper checks for video track existence

```dart
final hasLocalVideo = _videoCallService.localRenderer.srcObject != null;
final hasRemoteVideo = _videoCallService.remoteRenderer.srcObject != null;
final localStream = _videoCallService.localRenderer.srcObject;
final remoteStream = _videoCallService.remoteRenderer.srcObject;

debugPrint(
  'VideoCallScreen BUILD: status=$_callStatus, '
  'localSrc=$hasLocalVideo (tracks: ${localStream?.getVideoTracks().length ?? 0}), '
  'remoteSrc=$hasRemoteVideo (tracks: ${remoteStream?.getVideoTracks().length ?? 0})',
);

// Only show RTCVideoView if stream AND tracks exist
child: hasRemoteVideo && (remoteStream?.getVideoTracks().isNotEmpty ?? false)
    ? RTCVideoView(...)
    : Container(/* Loading state with avatar */)
```

### 4. Error Handling

Added comprehensive error handling throughout:
- Permission denial feedback
- Stream creation failures
- Renderer assignment verification
- Track validation

## New: Video Test Screen

Created diagnostic screen at [video_test_screen.dart](lib/screens/call/video_test_screen.dart) for debugging camera issues:

**Features:**
- Permission testing
- Camera preview
- Real-time debug logs
- Camera switching test
- Track count display
- Status messages

**Usage:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const VideoTestScreen()),
);
```

## Testing Instructions

### 1. Test Video Diagnostic Tool

```dart
// Add this temporarily to your app for testing
import 'package:supper/screens/call/video_test_screen.dart';

// Navigate to it from anywhere
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const VideoTestScreen()),
);
```

**Test Steps:**
1. Tap "Permissions" - Verify both camera and microphone are granted
2. Tap "Start" - Camera should show immediately
3. Check logs for any errors
4. Tap "Switch" - Camera should flip between front/back
5. Verify "Has video: true (tracks: 1 or more)"

### 2. Test Actual Video Call

1. **Device A (Caller):**
   - Open chat with Device B
   - Tap video call button
   - Should see own camera immediately
   - Wait for Device B to answer

2. **Device B (Receiver):**
   - Accept incoming video call
   - Should see Device A's video fullscreen
   - Own video in small PIP (top right)

3. **Both Devices:**
   - Verify face is visible (not blank screen)
   - Test camera switch button
   - Test video on/off button
   - Test mute button

### 3. Check Debug Logs

Run with logs:
```bash
flutter run --debug
```

Look for these success indicators:
```
✅ VideoCallService: Renderer initialized successfully
✅ VideoCallService: Local stream obtained
✅ VideoCallService: Video track enabled
✅ VideoCallService: Local renderer srcObject set successfully
📹 VideoCallService: Local stream ready callback triggered
```

Look for these error indicators:
```
❌ VideoCallService: Initialization error
❌ Failed to get media stream
❌ No video tracks in local stream
❌ Failed to assign local stream to renderer
```

## Common Issues & Solutions

### Issue 1: "Permissions denied"
**Solution:** Go to device Settings → Apps → Supper → Permissions → Enable Camera and Microphone

### Issue 2: "No video tracks in local stream"
**Solution:** Camera is being used by another app. Close all apps and try again.

### Issue 3: "Black screen but call connects"
**Possible Causes:**
1. Renderer not initialized - Check logs for initialization errors
2. Tracks disabled - Verify track.enabled = true in logs
3. Stream not assigned - Check srcObject is not null

### Issue 4: Works on emulator but not physical device
**Solution:** Ensure physical device has:
- Working camera hardware
- Updated camera drivers
- Sufficient lighting (some cameras disable in very dark conditions)

## Performance Considerations

### Optimal Settings
- Resolution: 1280x720 (ideal), 640x480 (minimum)
- Frame rate: 30fps (ideal), 15fps (minimum)
- Codec: VP8 (default WebRTC)

### Battery Impact
- Video calls consume ~20-30% more battery than voice calls
- Consider adding low-power mode option in future

## Architecture Changes

### Before
```
User → VideoCallScreen → VideoCallService (async init) → ❌ Race condition
```

### After
```
User → VideoCallScreen → Explicit renderer init → VideoCallService → Stream verification → ✅ Reliable
```

## Future Improvements

1. **Add connection quality indicator**
   - Show network strength
   - Adapt video quality based on bandwidth

2. **Add camera preview before call**
   - Let user see themselves before joining
   - Adjust lighting/position

3. **Add video effects**
   - Background blur
   - Filters
   - Virtual backgrounds

4. **Optimize for low-end devices**
   - Detect device capabilities
   - Auto-adjust resolution/framerate

## Files Modified

1. [lib/services/other services/video_call_service.dart](lib/services/other services/video_call_service.dart)
   - Initialize() method: Improved renderer initialization
   - _getLocalStream(): Enhanced media constraints and verification

2. [lib/screens/call/video_call_screen.dart](lib/screens/call/video_call_screen.dart)
   - build(): Added track verification
   - Enhanced debug logging
   - Better loading states with user avatars

3. [lib/screens/call/video_test_screen.dart](lib/screens/call/video_test_screen.dart) ⭐ NEW
   - Diagnostic tool for debugging camera issues

## Rollback Instructions

If issues persist, revert changes:
```bash
git checkout HEAD -- lib/services/other\ services/video_call_service.dart
git checkout HEAD -- lib/screens/call/video_call_screen.dart
git rm lib/screens/call/video_test_screen.dart
```

## Additional Resources

- [flutter_webrtc documentation](https://pub.dev/packages/flutter_webrtc)
- [WebRTC Native APIs](https://webrtc.org/getting-started/overview)
- [Android Camera Permissions](https://developer.android.com/training/permissions/requesting)

## Support

If blank screen persists after these fixes:
1. Run video test screen and share logs
2. Check device camera works in other apps
3. Verify Android version (minimum API 21)
4. Test on different device/emulator
5. Check Firestore call document for proper signaling

---

**Status:** ✅ Ready for testing
**Date:** 2026-01-16
**Tested on:** Android Emulator (API 36), needs physical device testing
