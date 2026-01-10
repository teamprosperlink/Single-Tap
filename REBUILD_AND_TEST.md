# 🚀 REBUILD AND TEST - Auto-Logout Fix

## Status: READY TO REBUILD

All fixes are in place. Now you need to rebuild the app for changes to take effect.

## Rebuild Steps

```bash
cd /path/to/plink-live

# 1. Clean everything
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Rebuild app
flutter run

# Wait for build to complete...
```

## After Rebuild - Test

### Setup
- **Device A**: Emulator (or phone 1)
- **Device B**: Real phone (or emulator 2)
- **Test Account**: test@example.com / password123

### Test Steps

**Step 1: Device A Login**
```
1. Open emulator app
2. Login with test@example.com
3. Should see home screen ✓
4. Keep it open
5. Open Android Studio console to watch logs
```

**Step 2: Device B Try Login**
```
1. Open real device
2. Try login with test@example.com
3. Should get error: "Already logged in on [Device A name]" ❌
4. Device B cannot access app ✓
```

**Step 3: Device B Logout (Force)**
```
Option 1: Force logout
1. Kill app on Device B
2. Wait 2 seconds
3. Or manually clear app data

Option 2: If able to login somehow
1. Tap logout/settings
2. Logout properly
```

**Step 4: Watch Device A Auto-Logout**

Console should show:
```
[DirectDetection] ✓ Starting direct logout detection for user: xyz123
[DirectDetection] ✓ Direct detection timer started (100ms interval)

[ValidateSession] Comparing tokens:
[ValidateSession]   Local:  ABC123...
[ValidateSession]   Server: NULL...

[ValidateSession] ❌ Server token deleted - LOGOUT DETECTED
[ValidateSession] Calling forceLogout()
[ForceLogout] ===== STARTING FORCE LOGOUT =====
[ForceLogout] ✓ Local device token cleared
[ForceLogout] ✓ Firebase and Google sign-out completed

[DirectDetection] ❌ SESSION INVALID - LOGOUT TRIGGERED!
[DirectDetection] Cancelling all timers and subscriptions
[DirectDetection] ✓ Calling _performRemoteLogout()

[Logout] ========== REMOTE LOGOUT INITIATED ==========
[Logout] ✓ Local device token cleared
[Logout] ✓ SNACKBAR SHOWN - USER CAN SEE NOTIFICATION
[Logout] ✓ Step 1: forceLogout() succeeded
[Logout] Step 2: Verification - current user: NULL (GOOD!)
[Logout] ========== LOGOUT PROCESS COMPLETE ==========
[Logout] ✓ StreamBuilder<User?> should now detect state change
[Logout] ✓ LoginScreen should appear in 1-2 seconds
```

Screen should show:
```
1. Red snackbar appears: "Logged out: Account accessed on another device"
2. After 1-2 seconds → LoginScreen appears ✓
```

**Step 5: Device B Can Now Login**
```
1. Device B: Try login again with test@example.com
2. Should succeed ✓
3. See home screen ✓
```

## Success Criteria

### ✅ Test PASSES if:
- [x] Device A shows red snackbar
- [x] Device A auto-redirects to LoginScreen
- [x] Console shows all [DirectDetection] messages
- [x] Console shows all [Logout] messages
- [x] Device B can login after Device A logout
- [x] No errors in console

### ❌ Test FAILS if:
- [ ] No red snackbar appears
- [ ] LoginScreen doesn't appear
- [ ] Console shows errors
- [ ] Device B still cannot login

## Expected Timeline

```
Device B Logout: T=0
Device A Console: [DirectDetection] checking (every 100ms)
Device A Console: T+100ms: [ValidateSession] checks tokens
Device A Console: T+200ms: Token mismatch detected!
Device A Console: T+300ms: [DirectDetection] SESSION INVALID
Device A Console: T+400ms: _performRemoteLogout() starts
Device A Screen: T+500ms: Red snackbar appears
Device A Screen: T+1500ms: LoginScreen appears ✓
```

Total time: ~1.5 seconds from logout to LoginScreen

## If Test Fails

### Console shows [ValidateSession] but no [DirectDetection]

**Problem**: Polling timer not running
**Solution**:
- Restart emulator
- Check if app is still in foreground
- Check if _autoCheckTimer is being cancelled too early

### Console shows everything but no snackbar

**Problem**: ScaffoldMessenger issue or widget not mounted
**Solution**:
- Check if context is available
- Restart app
- Check if snackbar duration (8 seconds) is visible

### App crashes after logout detection

**Problem**: Null reference or mounted check issue
**Solution**:
- Check console for exception
- Look for "Widget not mounted" messages
- Report the specific error

## Quick Rebuild Command

```bash
flutter clean && flutter pub get && flutter run -v
```

Use `-v` flag for verbose output if you want to see everything.

## Ready?

```bash
flutter clean
flutter pub get
flutter run
```

**Then test and report results!** 🎯

