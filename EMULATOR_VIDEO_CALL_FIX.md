# Fix: Video Call UnimplementedError on Android Emulator

## Problem
When running video calls on Android emulator, you get:
```
VideoCallScreen: Error callback - Failed to access camera: UnimplementedError
VideoCallScreen: Join call failed, ending call...
```

## Root Cause
Android emulators (especially x86_64) have **limited WebRTC support** and often cannot access the camera properly, throwing `UnimplementedError` when calling `navigator.mediaDevices.getUserMedia()`.

## Solutions

### Solution 1: Use a Real Android Device (RECOMMENDED ✅)

Video calling features **must be tested on a real Android device** for reliable results.

**Steps:**
1. Enable USB Debugging on your Android phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times to enable Developer Options
   - Go to Settings → Developer Options
   - Enable "USB Debugging"

2. Connect your phone via USB cable

3. Run Flutter commands:
   ```bash
   # Check if device is detected
   flutter devices

   # Should show something like:
   # • Pixel 7 (mobile) • ABC123XYZ • android-arm64 • Android 14 (API 34)

   # Run on your device
   flutter run
   ```

4. Test video calling - it should work properly now!

### Solution 2: Configure Emulator Camera (May Work)

If you must use the emulator, try configuring it to use your webcam:

**Steps:**
1. Open Android Studio → AVD Manager
2. Click ✏️ (Edit) on your emulator
3. Click "Show Advanced Settings"
4. Scroll down to "Camera" section:
   - **Front Camera**: Webcam0 (or Emulated)
   - **Back Camera**: Webcam0 (or Emulated)
5. Save and restart the emulator
6. Grant camera permissions in the app

**Note:** This may still not work reliably due to emulator limitations.

### Solution 3: Add Emulator Detection and Graceful Handling

We can improve the error handling to detect emulators and show a better message:

**File: `lib/services/other services/video_call_service.dart`**

Add this at the top of `initialize()` method:
```dart
// Detect if running on emulator
final deviceInfo = await DeviceInfoPlugin().androidInfo;
final isEmulator = !deviceInfo.isPhysicalDevice;

if (isEmulator) {
  debugPrint('⚠️ VideoCallService: Running on emulator - video calls may not work');
  onError?.call(
    'Video calling may not work on emulators. Please test on a real device.'
  );
  // Continue anyway but warn user
}
```

## Why Emulators Don't Work Well for Video Calls

1. **No Real Camera Hardware**: Emulators simulate cameras, but the simulation is incomplete
2. **WebRTC Limitations**: The `flutter_webrtc` plugin relies on native platform APIs that aren't fully implemented in emulators
3. **x86/x64 Emulation**: ARM-to-x86 translation can cause issues with media APIs
4. **Performance**: Video encoding/decoding is CPU-intensive and slow on emulators

## Recommended Testing Workflow

1. **Development**: Test basic UI/UX on emulator (without actually making calls)
2. **Feature Testing**: Test video calling on **real Android device only**
3. **Production**: Always deploy to real devices for video calling features

## Current Error Handling

The app already has error handling for `UnimplementedError`:

- **Line 427**: Catches `UnimplementedError` when `getUserMedia()` fails
- **Line 513**: Shows error message to user
- **Line 680**: Catches `UnimplementedError` in `joinCall()` and shows helpful message

The error is being caught correctly - the issue is that emulators fundamentally don't support WebRTC properly.

## Conclusion

**You MUST test video calling on a real Android device.** Emulators are not suitable for video call testing due to inherent WebRTC limitations.
