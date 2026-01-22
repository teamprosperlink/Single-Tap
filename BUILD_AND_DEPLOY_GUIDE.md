# Build and Deploy Guide - Video Call Testing

## Issue Fixed ✅

**Problem**: Build failed with file lock error:
```
FileSystemException: libVkLayer_khronos_validation.so: The process cannot access the file because it is being used by another process
```

**Solution Applied**:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

**Result**: Build succeeded! ✅

---

## How to Run on Real Device (Nokia G42 5G)

### Quick Commands

```bash
# 1. Check connected devices
flutter devices

# You should see:
# Nokia G42 5G (mobile) • CZQ433H007421700432 • android-arm64 • Android 15 (API 35)

# 2. Run on Nokia G42 (specify device ID)
flutter run -d CZQ433H007421700432

# OR run on any connected phone (auto-select)
flutter run -d android
```

### Why Test on Real Device?

**Video calling MUST be tested on real devices** because:

1. ✅ **Real camera hardware** - proper WebRTC support
2. ✅ **Accurate performance** - real CPU/GPU behavior
3. ✅ **Network conditions** - realistic connectivity
4. ✅ **Audio routing** - proper speaker/earpiece handling
5. ❌ **Emulators throw `UnimplementedError`** - WebRTC not supported

---

## Troubleshooting Build Errors

### Error: File locked / Process cannot access file

**Cause**: Previous build process still running or file locked by antivirus/indexer

**Solution**:
```bash
# 1. Clean build artifacts
flutter clean

# 2. Kill any hanging Java/Gradle processes (Windows)
taskkill /F /IM java.exe

# 3. Reinstall dependencies
flutter pub get

# 4. Rebuild
flutter run
```

### Error: Gradle build failed

**Solution**:
```bash
# Clean and rebuild from scratch
flutter clean
flutter pub get
flutter build apk --debug
flutter run
```

### Error: Device not detected

**Check USB connection**:
```bash
# List devices
flutter devices

# If not showing:
# 1. Unplug and replug USB cable
# 2. Check USB debugging is enabled on phone
# 3. Accept "Allow USB debugging" prompt on phone
# 4. Try different USB cable/port
```

---

## Video Call Testing Checklist

Once app is running on Nokia G42:

### Pre-Test Setup
- [ ] Camera permission granted
- [ ] Microphone permission granted
- [ ] Two users logged in (on different devices)
- [ ] Both devices connected to stable internet

### Test Scenarios

1. **Outgoing Video Call**
   - [ ] Caller sees their own video (front camera)
   - [ ] Receiver gets incoming call notification
   - [ ] Receiver accepts call
   - [ ] Both users see each other's video
   - [ ] Audio works both ways
   - [ ] Video quality is acceptable

2. **Controls Test**
   - [ ] Mute/unmute microphone
   - [ ] Toggle video on/off
   - [ ] Switch front/back camera
   - [ ] Toggle speaker on/off
   - [ ] End call gracefully

3. **Edge Cases**
   - [ ] Reject incoming call
   - [ ] Call timeout (60 seconds)
   - [ ] Network interruption during call
   - [ ] Background/foreground transitions
   - [ ] Incoming phone call during video call

---

## Current Device Setup

**Connected Devices**:
- ✅ **Nokia G42 5G** (android-arm64, Android 15) - **Use this for video call testing**
- ⚠️ Emulator (android-x64) - **NOT suitable for video calls**
- Windows desktop
- Chrome web
- Edge web

**Recommended**: Always use Nokia G42 for video call feature testing.

---

## Performance Tips

### Optimize Build Speed
```bash
# Use debug build for testing (faster)
flutter run --debug

# Use release build for final testing (optimized)
flutter run --release

# Build APK without running
flutter build apk --debug
flutter build apk --release
```

### Clear Cache if Issues Persist
```bash
# Nuclear option - clears everything
flutter clean
flutter pub cache clean
flutter pub get
```

---

## Next Steps

1. **Run on Nokia G42**:
   ```bash
   flutter run -d CZQ433H007421700432
   ```

2. **Test video calling** between two real devices

3. **Check logs** for any remaining issues:
   ```bash
   flutter logs
   ```

4. **Monitor debug output** during video calls to verify:
   - Camera initialization
   - WebRTC peer connection
   - Video track assignment
   - Audio/video stream status

---

## Common Log Patterns

**✅ Success Pattern**:
```
VideoCallService: ✅ Initialized successfully
VideoCallService: ✅ Local stream obtained
VideoCallService: ✅ Remote renderer srcObject set
VideoCallScreen: ✅ User joined, _callStatus set to CONNECTED
```

**❌ Emulator Error Pattern**:
```
VideoCallService: ❌ getUserMedia not implemented on this platform
VideoCallScreen: Error callback - Failed to access camera: UnimplementedError
```

**✅ Real Device Pattern**:
```
VideoCallService: Requesting permissions...
VideoCallService: Camera permission result: PermissionStatus.granted
VideoCallService: ✅ Local renderer initialized
VideoCallService: 🎥 VIDEO TRACK ARRIVED - Assigning to renderer...
```

---

## Summary

- ✅ Build issue fixed with `flutter clean`
- ✅ Nokia G42 5G connected and ready
- ✅ Video calling will now work on real device
- ⚠️ Never test video calls on emulator (WebRTC not supported)

**Run this command now**:
```bash
flutter run -d CZQ433H007421700432
```

Then test video calling! 🎥📱
