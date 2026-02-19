# Quick Test Guide - Listener Restart Fix

**What Was Fixed**: Device A's listener now restarts even when Device B logs in with the same account

**Status**: ✅ Commit a6a70c7 - Ready for testing

---

## Build

```bash
cd c:/Users/csp/Documents/plink-live
flutter clean && flutter pub get
```

---

## Test Setup

### Terminal 1: Device A (First Device)
```bash
flutter run -d emulator-5554
```
- Login with: `test@example.com` / `password123`
- Wait 30 seconds for app to fully load
- You should see the main app screen
- **Leave it running**

### Terminal 2: Device B (New Device) - After 30 Seconds
```bash
flutter run -d emulator-5556
```
- Login with: **SAME** `test@example.com` / `password123`
- Watch for loading spinner (no dialog should appear)
- Wait 2-3 seconds
- Should navigate to main app

---

## Expected Timeline

```
0s:   Device B: User clicks login
2s:   Device B: Loading spinner appears
5s:   Device A: Listener detects change
10s:  Device A: Protection window expires
11s:  Device A: Sees forceLogout=true signal
12s:  Device A: LOGOUT! Shows login screen ✓
13s:  Device B: Shows main app screen ✓
```

---

## What You Should See

### Device B (New Device)
```
✓ Loading spinner (no dialog)
✓ No errors
✓ After 2-3 seconds: Main app loads
✓ Ready to use
```

### Device A (Old Device)
```
✓ Was using app normally
✓ Suddenly sees login screen
✓ Message: "You've been logged out from another device"
✓ Can login again if needed
```

---

## Logs to Check

### Device B - Look for:
```
[LoginScreen] Starting automatic logout of other device...
[LoginScreen] Waiting 2.5 seconds for listener to initialize...
[LoginScreen] ✓ Other device logout command sent
[LoginScreen] ✓ Navigating Device B to main app...
```

### Device A - Look for:
```
[BUILD] Restarting device session monitoring - checking for new device logins...
[BUILD] Auth verified after delay, starting listener
[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
[RemoteLogout] 🔴 Calling signOut()...
[RemoteLogout] ✓ Firebase sign out completed
```

---

## Success Criteria ✅

- [ ] Device B shows loading spinner (NO dialog)
- [ ] Device B does NOT logout immediately
- [ ] Device B navigates to main app
- [ ] Device A shows login screen
- [ ] No errors in Device A logs
- [ ] Only Device B is logged in after test

---

## If Something Goes Wrong

### Issue: Device B shows error
**Check**:
- Firestore rules deployed? `npx firebase deploy --only firestore:rules`
- Network connection OK?
- Same email/password for both devices?

### Issue: Device A doesn't logout
**Check logs for**:
- `[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED`
- If NOT present: Check Device B logs for logout signal being sent

### Issue: Both devices logged in (Old issue)
**This should be FIXED now**
- If still happening: Clear app data and rebuild
- `flutter clean && flutter pub get`

---

## Quick Commands

```bash
# View logs
flutter run -v

# Clear app data
flutter clean

# View specific device logs
adb logcat | grep "DeviceSession\|LoginScreen\|RemoteLogout"

# Kill running emulators
adb emu kill

# List devices
adb devices
```

---

## What This Tests

✅ Listener restart logic (the fix)
✅ Protection window (10 seconds)
✅ Automatic logout (Device B triggers Device A logout)
✅ Single device login (SingleTap-style)
✅ No user confusion (no dialog shown)
✅ Proper logout message (Device A gets logged out)

---

## Time Estimate

- Build: 2-3 minutes
- Device A login: 1-2 minutes
- Device B login: 1-2 minutes
- Observation: 10-15 seconds
- **Total**: ~5-10 minutes

---

## References

- **Technical Details**: See `FIX_LISTENER_RESTART.md`
- **Feature Docs**: See `SingleTap_STYLE_LOGOUT.md`
- **Full Summary**: See `SESSION_SUMMARY_FIX_COMPLETE.md`

---

**Ready?** Run the commands above and watch the magic happen! 🚀

The listener fix ensures Device A detects Device B's login and automatically logs out.
