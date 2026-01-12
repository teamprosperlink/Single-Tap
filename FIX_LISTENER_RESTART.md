# Fix: Listener Restart on Device B Login

**Status**: ✅ **FIXED AND READY FOR TESTING**
**Date**: January 12, 2026
**Issue**: Device A's listener was NOT restarting when Device B logged in with same account, preventing logout signal detection

---

## The Problem

When Device B logged in with the same account:
- Device A had UID = "user123"
- Device B also has UID = "user123"
- The code checked: `if (_lastInitializedUserId != uid)`
- Since both have same UID, condition was **FALSE**
- Listener initialization code was **SKIPPED**
- Device A never detected the `forceLogout=true` signal
- **Result**: Both devices stayed logged in ❌

---

## The Root Cause

**Original Code** (lines 713-725 - BROKEN):
```dart
if (_lastInitializedUserId != uid) {
  print('[BUILD] Starting device session monitoring for new user: $uid');
  // listener initialization
}
```

**Problem**: This condition only triggers when UID changes. When Device B logs in with SAME UID:
- `_lastInitializedUserId` = "user123" (already set during Device A login)
- `uid` = "user123" (same account)
- Condition evaluates to FALSE → listener code skipped

---

## The Solution

**Fixed Code** (lines 712-730):
```dart
// CRITICAL FIX: Always restart listener for device logout detection
// Even if same user (uid), another device might have logged in
// Need to detect new activeDeviceToken and forceLogout changes
print('[BUILD] Restarting device session monitoring - checking for new device logins...');
print('[BUILD] Subscription BEFORE: $_deviceSessionSubscription');

// CRITICAL FIX: Add delay to ensure Firebase auth is fully ready
// This prevents PERMISSION_DENIED errors when Firestore listener starts
Future.delayed(const Duration(milliseconds: 500), () {
  // Verify user is still authenticated after delay
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null && currentUser.uid == uid && mounted) {
    print('[BUILD] Auth verified after delay, starting listener');
    _startDeviceSessionMonitoring(uid);
    print('[BUILD] Subscription AFTER: $_deviceSessionSubscription');
  } else {
    print('[BUILD] User auth invalid after delay, skipping listener');
  }
});
```

**Why This Works**:
1. **Removed the `if (_lastInitializedUserId != uid)` check** - Always executes listener initialization
2. **Added 500ms delay** - Ensures Firebase auth is fully ready before Firestore listener starts
3. **Verify auth status after delay** - Confirms user is still logged in before starting listener
4. **Result**: Listener ALWAYS restarts when user logs in, even with same UID

---

## What Happens Now (Device B Login Flow)

```
Device B Login:
  ↓
Firebase auth succeeds (UID = "user123")
  ↓
StreamBuilder detects auth state change
  ↓
✅ ALWAYS calls _startDeviceSessionMonitoring()
  (Previously skipped because UID didn't change)
  ↓
Listener restarts (subscriptions canceled and recreated)
  ↓
Listener ready to detect forceLogout signal
  ↓
Device B's login code sends forceLogout=true to Firestore
  ↓
Device A's listener fires with new snapshot
  ↓
Device A detects forceLogout=true
  ↓
Device A calls _performRemoteLogout()
  ↓
Device A logs out ✓
Device B shows main app ✓
```

---

## Code Changes Summary

**File**: `lib/main.dart`
**Lines Changed**: 708-730
**Change Type**: Logic fix - removed UID check, ensured listener always restarts

### Before (Broken)
```
if (_lastInitializedUserId != uid) {
  // Start listener (SKIPPED when same UID)
}
```

### After (Fixed)
```
// Always start listener
Future.delayed(Duration(milliseconds: 500), () {
  // Verify auth, then start listener
});
```

---

## Protection Window Still Active

The 10-second protection window (lines 448-466) is still active and working:

```
Device A Timeline:
0ms:   Listener starts
0-10s: PROTECTION PHASE - skip all logout checks
       (Device B might trigger forceLogout at ~3-4s, but protected)
10s+:  ACTIVE PHASE - check forceLogout, token changes, etc.
       (Now detects Device B's logout signal)
```

---

## Expected Behavior After Fix

### Device B (New Device)
```
1. Enters email/phone and password
2. Clicks "Login"
3. Loading spinner appears
4. Automatic logout function called (waits 2.5s)
5. Sends forceLogout=true to Firestore
6. Device B navigates to main app
```

### Device A (Old Device)
```
1. Using app normally
2. Listener fires with Firestore update
3. Sees forceLogout=true in snapshot
4. ✅ Protection window PASSED (>10 seconds since listener start)
5. Calls _performRemoteLogout()
6. Signs out from Firebase
7. Shows login screen
8. Message: "You've been logged out from another device"
```

---

## Testing Instructions

### Build
```bash
cd c:/Users/csp/Documents/plink-live
flutter clean && flutter pub get
```

### Test Single Device Login (Recommended)

**Terminal 1 - Device A**:
```bash
flutter run -d emulator-5554
# Wait for app to fully load
# Login with email: test@example.com, password: password123
# Wait 30 seconds - see main app screen
```

**Terminal 2 - Device B** (after 30 seconds):
```bash
flutter run -d emulator-5556
# Login with SAME email: test@example.com, password: password123
# Should show loading spinner (no dialog)
# Should NOT logout immediately
# After 2-3 seconds: Shows main app
```

### Expected Results

**Device B** (should see):
```
[LoginScreen] Starting automatic logout of other device...
[LoginScreen] Waiting 2.5 seconds for listener to initialize...
[LoginScreen] Listener initialized, now logging out other device...
[AuthService] Calling logoutFromOtherDevices
[AuthService] STEP 1: Writing forceLogout=true
[AuthService] ✓ STEP 1 succeeded
[LoginScreen] ✓ Other device logout command sent
[LoginScreen] ✓ Navigating Device B to main app...
```

**Device A** (should see):
```
[BUILD] Restarting device session monitoring - checking for new device logins...
[BUILD] Auth verified after delay, starting listener
[BUILD] Subscription AFTER: (subscription info)
[DeviceSession] 🚀 LISTENER STARTED AT: ...
[DeviceSession] ✅ Listener ready - protection window now active
...
[DeviceSession] 🕐 Snapshot received: 10.5s since listener start
[DeviceSession] ✅ PROTECTION PHASE COMPLETE - NOW checking logout signals
[DeviceSession] 📋 forceLogout value: true (type: bool)
[DeviceSession] 📋 forceLogout parsed: true
[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
[RemoteLogout] ========== REMOTE LOGOUT INITIATED ==========
[RemoteLogout] 🔴 Calling signOut()...
[RemoteLogout] ✓ Firebase sign out completed
```

### Success Criteria ✅

- [ ] Device B shows loading spinner (no dialog)
- [ ] Device B does NOT logout immediately
- [ ] Device B navigates to main app
- [ ] Device A receives forceLogout signal
- [ ] Device A shows login screen
- [ ] Device A shows logout message
- [ ] No errors in logs
- [ ] Only Device B is logged in

---

## Verification Checklist

1. **Code compiles**: ✅ `flutter analyze` shows no errors
2. **Listener logic**: ✅ Always executes listener initialization
3. **Protection window**: ✅ 10-second safety period active
4. **forceLogout detection**: ✅ Checks after protection window expires
5. **Remote logout**: ✅ Calls _performRemoteLogout() when detected

---

## Summary

**What Was Fixed**:
- ✅ Removed UID check that prevented listener restart with same account
- ✅ Ensured listener ALWAYS starts when user logs in
- ✅ Added 500ms delay to ensure Firebase auth readiness
- ✅ Verified auth status before starting listener

**Why It Matters**:
- Device A's listener now ALWAYS detects when Device B logs in
- Device A can now receive and process forceLogout signal
- WhatsApp-style automatic logout now works correctly

**Status**: 🚀 **READY FOR TESTING**

---

## Git Commit

```
Fix: Always restart device session listener regardless of UID

When Device B logs in with same account as Device A, the StreamBuilder
was not restarting the Firestore listener because the UID didn't change.
This prevented Device A from detecting the forceLogout signal.

Solution: Remove the UID check and always restart the listener with
a 500ms delay to ensure Firebase auth is ready.

This ensures Device A can detect when Device B logs in and properly
logout automatically (WhatsApp-style single device login).
```

---

**Ready to test!** Build and run on two emulators with same login account. 🚀
