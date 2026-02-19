# Video Call Camera Troubleshooting Guide

## 🎥 Camera Not Working - Complete Solutions

### **Step 1: Check App Permissions**

#### Android:
1. Open **Settings** → **Apps** → **[Your App Name]**
2. Tap **Permissions**
3. Check **Camera** - should show "Allowed"
4. Check **Microphone** - should show "Allowed"
5. If denied, tap each permission and select **"Allow"**

#### iOS:
1. Open **Settings** → **Privacy** → **Camera**
2. Your app should be listed with a toggle **ON** (green)
3. If toggle is OFF, tap to enable
4. Go to **Settings** → **Privacy** → **Microphone**
5. Your app should also have toggle **ON**

### **Step 2: Restart the App**
- Close the app completely
- Wait 3 seconds
- Reopen the app
- Try video call again

### **Step 3: Check Device Camera**
- Try opening device's built-in camera app
- If it doesn't work, camera hardware might be damaged
- If it works, return to troubleshooting step 4

### **Step 4: Ensure Another App Isn't Using Camera**
- Close all other apps (especially other messaging apps like SingleTap, Telegram)
- Camera can only be used by ONE app at a time
- Try video call again

### **Step 5: Check Network Connection**
- Ensure you have WiFi or mobile data
- Try on WiFi first (cellular can be slower)
- Check if other person's device can receive your local camera stream
- If they see a black screen for you → camera isn't sending

### **Step 6: Restart Device**
- This often fixes WebRTC issues
- Power off completely for 10 seconds
- Power back on
- Try video call again

### **Step 7: Check Firestore Connection**
- The app needs to communicate with Firestore to exchange video streams
- If Firestore is blocked/slow, camera won't connect
- Check internet speed (should be at least 1 Mbps for video)

### **Step 8: Debug Mode - Check Logs**

#### Android (Android Studio):
1. Connect device via USB
2. Open **Logcat** in Android Studio
3. Search for: `VideoCallService` or `Error`
4. Look for error messages like:
   - `"Camera permission denied"`
   - `"Error getting local stream"`
   - `"Failed to initialize renderer"`

#### iOS (Xcode):
1. Connect device via USB
2. Open **Xcode** → **Window** → **Devices and Simulators**
3. Select your device and app
4. Open **Console** tab
5. Look for messages with `VideoCallService`

### **Step 9: Camera Hardware Reset**

#### Android:
1. Go to **Settings** → **Apps** → **Camera**
2. Tap **Storage** → **Clear Cache**
3. Go back and tap **Clear Data**
4. Restart device
5. Try again

#### iOS:
1. Force close the app: Swipe up from bottom and swipe the app up
2. Go to **Settings** → **General** → **iPhone Storage**
3. Find your app and tap it
4. Tap **Offload App** → **Reinstall App**
5. Try again

---

## 🔍 Common Camera Issues & Solutions

### **Issue 1: Black Screen Instead of Camera**
```
✗ My camera shows black/empty
✓ Other person's camera works fine
```

**Causes:**
- Camera permission denied
- App doesn't have permission to access camera
- Another app is using camera

**Solution:**
1. Check permissions (Step 1 above)
2. Restart app (Step 2)
3. Close other apps (Step 4)
4. Restart device (Step 6)

---

### **Issue 2: Other Person Can't See My Camera**
```
✗ They see black screen for my video
✓ I can see their camera fine
✓ My device camera app works
```

**Causes:**
- My local stream isn't being sent
- Firestore signaling failed
- WebRTC connection not established

**Solution:**
1. Check network (Step 5)
2. Check Firestore connection
3. Restart app and try again
4. Check logs for WebRTC errors (Step 8)

---

### **Issue 3: Camera Shows But Video Freezes**
```
✗ Camera starts but freezes/lags
✓ Audio still works
```

**Causes:**
- Poor network connection
- Device running out of memory
- Camera frame rate too high

**Solution:**
1. Move closer to WiFi router (Step 5)
2. Close other apps to free up RAM
3. Try reducing camera resolution (in code, change 1280x720 to 640x480)

---

### **Issue 4: "Camera Permission Denied" Error**
```
✗ Shows error dialog: "Camera permission denied"
```

**Solution:**
1. Go to Settings → Apps → Permissions → Camera
2. Change from "Deny" to "Allow"
3. Restart app
4. Try video call again

---

### **Issue 5: Camera Works First Time, Then Black Screen**
```
✗ First call works, second call shows black screen
```

**Causes:**
- Renderer wasn't properly disposed/reinitialized
- Previous camera stream still active

**Solution:**
1. Restart app completely
2. Wait 5 seconds between calls
3. Check if both calls are trying to use same device (can't happen, but device might be confused)

---

### **Issue 6: Camera Permission Keeps Getting Asked**
```
✗ Permission dialog shows every time
```

**Causes:**
- App not storing permission grant
- Device OS resets permissions after app update

**Solution:**
1. Uninstall app
2. Restart device
3. Reinstall app fresh
4. Grant permissions when asked

---

## 📱 Device-Specific Solutions

### **Samsung Devices**
- Go to **Settings** → **Apps** → **Permissions**
- Enable "Camera" for your app
- Some Samsung devices have additional permission layer

### **Xiaomi Devices**
- Go to **Settings** → **Apps** → **Permissions**
- Some Xiaomi devices disable camera by default
- Check "App Permissions" specifically

### **OnePlus Devices**
- Go to **Settings** → **Apps & notifications** → **App permissions**
- Camera permissions might be under "Advanced" section

### **iPhone (iOS)**
- Check **Settings** → **Privacy** → **Camera**
- Make sure app toggle is green (enabled)
- If app missing, reinstall it

---

## 🔧 Advanced Debugging

### **Check if Renderer is Initialized**

Look for these log messages in console:

✅ **Good signs:**
```
VideoCallService: Local stream assigned to renderer
VideoCallService: Added local video track
VideoCallService: Local stream obtained
```

❌ **Bad signs:**
```
VideoCallService: Error assigning local stream to renderer
VideoCallService: Local renderer initialization error
VideoCallService: Error getting local stream
```

### **Check if WebRTC Connection is Established**

Look for:
```
VideoCallService: Peer connection created successfully
VideoCallService: Local stream assigned to renderer
VideoCallService: ICE candidate added
```

### **Check Permission Errors**

Look for:
```
VideoCallService: Camera permission result: PermissionStatus.denied
VideoCallService: Microphone permission result: PermissionStatus.denied
```

---

## 🎯 Quick Checklist Before Debugging

- [ ] Camera permission granted in Settings
- [ ] Microphone permission granted in Settings
- [ ] No other app using camera
- [ ] WiFi or cellular connection active
- [ ] Device has sufficient battery (not low power mode)
- [ ] Device not overheating
- [ ] Both devices logged in with different accounts
- [ ] Firestore database accessible
- [ ] App is latest version

---

## 📞 Still Not Working?

If none of these work, check:

1. **Logs for specific error messages** (Step 8)
   - Take a screenshot of error message
   - Share it for help

2. **Device Model & iOS/Android Version**
   - Some older devices don't support WebRTC
   - iOS 11+ or Android API 21+ required

3. **Firestore Rules**
   - Check if Firestore rules allow call signaling
   - May need to update security rules

4. **Network Firewall**
   - School/office WiFi might block WebRTC
   - Try on mobile data
   - Try on home WiFi

5. **App Cache**
   - Settings → Apps → [Your App] → Storage → Clear Cache
   - Restart app

---

## ✅ Testing Camera Locally

Before starting a real call, test if camera works:

1. Open app
2. Go to **Settings** or **Profile**
3. Try to upload a photo/take a picture
4. If camera works there, it should work in video calls
5. If it doesn't work, fix camera permissions first

---

**Remember:** Camera streaming requires:
- ✅ Permission granted
- ✅ Good network (WiFi preferred)
- ✅ Firestore connection
- ✅ Both devices active
- ✅ At least 1 Mbps upload speed

If all these are OK but camera still doesn't work, it's likely a permissions issue. Double-check Settings!
