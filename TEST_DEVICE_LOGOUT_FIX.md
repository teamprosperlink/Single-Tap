# Test Guide: Device Logout Fix

## Quick Summary
The regression where first-time device logout stopped working has been fixed. The issue was in the timestamp validation logic - it now correctly handles the case when the listener is still initializing.

## Testing Steps

### Setup
1. Open two devices/emulators
2. Clear all login data on both devices
3. Have the app code built with the latest fix

---

## Test 1: First-Time Logout (Device Online) ✅ THIS WAS BROKEN

**What to do:**
```
1. Device A: Login with email/password
   → Wait 2-3 seconds for app to fully load

2. Device B: Try to login with same email
   → Device conflict dialog should appear: "Your account was just logged in on..."

3. Device B: Click "Logout Other Device" button
   → Dialog shows loading spinner

4. Device A: Watch for logout
   → App should show login screen within 1-2 seconds
   → Check logs for: "[DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW"
```

**Expected Result**: ✅ Device A logs out immediately
**Was Broken**: Device A stayed logged in
**Now Fixed**: The null check for `_listenerStartTime` handles this case

---

## Test 2: Second Logout (Verify No Stale Signal Replay)

**What to do:**
```
1. Device A: Login again with same email
   → Wait for app to fully load

2. Device C: Try to login with same email
   → Device conflict dialog should appear

3. Device C: Click "Logout Other Device"
   → Dialog shows loading spinner

4. Device A: Should logout immediately (same as Test 1)
   → Check logs to confirm
```

**Expected Result**: ✅ Device A logs out (not affected by old signals)
**Verification**: Timestamp comparison correctly detects NEW signal

---

## Test 3: Multiple Logouts (Repeat 3-4 times)

**What to do:**
```
1. Repeat Test 2 three times with different devices (C, D, E)
2. Each time: Device A logs back in, new device logs in, click "Logout Other Device"
```

**Expected Result**: ✅ Works every single time
**Previous Behavior**: Failed on second+ attempts

---

## Test 4: Offline Device Logout

**What to do:**
```
1. Device A: Login
   → Wait for app to fully load

2. Device A: Force kill the app (swipe from recents, kill process)
   → OR toggle airplane mode to simulate offline

3. Device B: Login with same email
   → Device conflict dialog appears

4. Device B: Click "Logout Other Device"

5. Device A: Bring device back online / reopen app
   → App should logout within 2-3 seconds
   → Check logs for: "[DeviceSession] TOKEN CLEARED ON SERVER"
```

**Expected Result**: ✅ Device A detects empty token and logs out on reconnect
**Detection Method**: Token deletion detection (Priority 2)

---

## Test 5: Stale Session Auto-Cleanup

**What to do:**
```
1. Device A: Login

2. Device A: Force kill app (don't logout gracefully)

3. Wait 6+ minutes (must be more than 5 minute threshold)

4. Device B: Try to login with same email
   → Should NOT see device conflict dialog
   → Should allow normal login

5. Check logs on Device B for: "[AuthService] Old session is STALE - automatically clearing"
```

**Expected Result**: ✅ Old stale session auto-cleared, Device B logs in directly
**Previous Behavior**: Would show device conflict dialog even though Device A is dead

---

## Logs to Watch For

### Device A (Old Device - Should Logout)
```
✅ SUCCESSFUL LOGOUT:
[DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW

OR (if offline):
[DeviceSession] TOKEN CLEARED ON SERVER
[DeviceSession] Logout triggered: Another device logged in

TIMESTAMP VALIDATION (confirms fix working):
[DeviceSession] ⚠️ CRITICAL: Listener not yet initialized, treating forceLogout as NEW signal
[DeviceSession] forceLogoutTime: 2026-01-13 ..., listenerTime: 2026-01-13 ..., isNewSignal: true
```

### Device B (New Device - Should Login)
```
✅ SUCCESSFUL LOGOUT OF OTHER DEVICE:
[AuthService] ✓ STEP 0 succeeded - old device token cleared
[AuthService] Cloud Function called successfully
[AuthService] ✓ Forced logout completed

✅ STALE SESSION CLEANUP:
[AuthService] Session age: 6 minutes (stale if > 5)
[AuthService] Old session is STALE - automatically clearing
[AuthService] Old device session cleared successfully
```

---

## Troubleshooting

### Issue: Device A not logging out
**Check**:
1. Are logs showing "FORCE LOGOUT SIGNAL"?
   - If YES: listener is working, something else wrong
   - If NO: listener not detecting signal, check Firestore

2. Check Firestore Console:
   - Go to `users/{userId}` document
   - `forceLogout` should be `true` (before Device B fully logs in)
   - `forceLogoutTime` should have recent timestamp
   - `activeDeviceToken` should be empty or new token

3. Check timestamp:
   - Is `forceLogoutTime` AFTER listener start time?
   - If NO: timestamp comparison may be failing (but fix should handle this)

### Issue: Device B shows device conflict dialog but logout doesn't work
**Check**:
1. Cloud Function is deployed: `firebase deploy --only functions:forceLogoutOtherDevices`
2. Fallback Firestore write works if Cloud Function fails
3. Both should set `forceLogout=true` with timestamp

### Issue: Stale session not auto-cleaning
**Check**:
1. Wait time: Must be > 5 minutes since last update
2. `lastSessionUpdate` timestamp exists in user doc
3. Check logs for "Session age: X minutes"

---

## Success Criteria

All tests should pass for production deployment:

- [ ] Test 1: First logout works immediately (was broken, now fixed)
- [ ] Test 2: Second logout works (no stale signal replay)
- [ ] Test 3: Multiple logouts work consistently
- [ ] Test 4: Offline device logs out on reconnect
- [ ] Test 5: Stale sessions auto-cleanup after 5 minutes
- [ ] All Firestore fields set correctly
- [ ] No unexpected logouts
- [ ] Logs show expected messages

---

## Deployment Checklist

- [ ] Flutter app built with latest fix
- [ ] Test locally on 2 devices
- [ ] Cloud Functions already deployed
- [ ] No database schema changes needed
- [ ] Ready for production release

---

## Key Files Modified

1. **lib/main.dart** - Fixed timestamp validation logic
   - Added null check for `_listenerStartTime`
   - If null: treat logout as NEW (safest for first-time)
   - If not null: use timestamp comparison

2. **lib/services/auth_service.dart** - Already has all fixes
   - Auto-cleanup for stale sessions
   - Immediate token deletion
   - Proper flag reset on login/logout

3. **functions/index.js** - Already has all fixes
   - 3-step logout process
   - Timestamp tracking

---

**Last Commit**: `93ca79c - Fix: Handle null _listenerStartTime in timestamp validation`
**Status**: Ready for testing
