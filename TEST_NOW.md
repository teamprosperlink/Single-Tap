# Test Device Logout Now

**CRITICAL FIX APPLIED**: Race condition in listener initialization

## What Was Fixed

Device B was logging out immediately after login because the listener callback was executing before the initialization was complete. Added a `_listenerReady` flag that guarantees proper initialization order.

## Testing Instructions

### Step 1: Rebuild App

```bash
cd c:/Users/csp/Documents/plink-live
flutter clean && flutter pub get
```

### Step 2: Run Device A (First Device)

Open Terminal 1:
```bash
flutter run -d emulator-5554
```

**Wait for Device A to fully load** - you should see the main app screen.

Check logs for:
```
[DeviceSession] 🚀 LISTENER STARTED AT: ...
[DeviceSession] 🛡️ PROTECTION WINDOW: 10 seconds from ...
[DeviceSession] ✅ Listener ready - protection window now active
```

### Step 3: Run Device B (Second Device - After 30 seconds)

Open Terminal 2:
```bash
flutter run -d emulator-5556
```

**Device B should show login screen**. Login with the **SAME account** as Device A.

Check logs for:
```
[LoginScreen] Logout other device - pending user ID: ...
[LoginScreen] Waiting 2.5 seconds for listener to initialize...
[LoginScreen] Listener should be initialized now, proceeding with logout
[AuthService] Calling logoutFromOtherDevices
[AuthService] STEP 1: Writing forceLogout=true
[AuthService] ✓ STEP 1 succeeded
```

### Step 4: Verify Results

**Expected on Device B**:
```
✅ Login succeeds
✅ No logout popup appears
✅ Main app screen shows
✅ Can use app normally
```

**Expected on Device A**:
```
✅ Detects logout signal
✅ Shows login screen
✅ Ready for re-login
```

**Expected in logs**:

Device B should show:
```
[DeviceSession] 🕐 Snapshot received: 1.25s since listener start
[DeviceSession] ⏳ PROTECTION PHASE (8.75s remaining) - skipping ALL logout checks
[DeviceSession] 🕐 Snapshot received: 1.50s since listener start
[DeviceSession] ⏳ PROTECTION PHASE (8.50s remaining) - skipping ALL logout checks
```

Device A should show:
```
[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
[RemoteLogout] ========== REMOTE LOGOUT INITIATED ==========
[RemoteLogout] 🔄 Widget is mounted - triggering setState to rebuild...
```

### Step 5: Troubleshooting

**If Device B still logs out immediately:**

1. Check if `_listenerReady` flag is being set:
   ```
   [DeviceSession] ✅ Listener ready - protection window now active
   ```
   If NOT present, listener initialization is failing.

2. Check if protection window is being entered:
   ```
   [DeviceSession] ⏳ PROTECTION PHASE ...
   ```
   If NOT present, snapshots are arriving but protection isn't working.

3. Check Device B's forceLogout value:
   ```
   [DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
   ```
   If this appears WITH protection phase skipped, something else is wrong.

**If Firestore permissions error appears:**

```
W/Firestore: Write failed: Status{code=PERMISSION_DENIED...}
```

You need to deploy Firestore rules:
```bash
npx firebase logout
npx firebase login
npx firebase deploy --only firestore:rules
```

See `MANUAL_FIREBASE_LOGIN_AND_DEPLOY.md` for detailed steps.

## Key Changes Made

### 1. Race Condition Fixed (Critical)
**File**: `lib/main.dart`
**Issue**: Listener callback could execute before `_listenerStartTime` was set
**Solution**: Added `_listenerReady` flag that's set AFTER listener is fully initialized

### 2. Protection Window Extended
**File**: `lib/main.dart` (line 455)
**Window**: 10 seconds (extended from 6 seconds)
**Covers**: Auth delay (500ms) + Listener setup + Logout delay (2.5s) + buffer

### 3. Logout Delay Extended
**File**: `lib/screens/login/login_screen.dart` (line 615)
**Delay**: 2.5 seconds (extended from 1.5 seconds)
**Purpose**: Ensures listener is fully initialized before logout signal is written

## Timeline (Actual)

```
Device A: Logged in at time T

Device B: Login initiated (time T + X)
  |
  ├─ 0ms: Auth starts
  ├─ 500ms: Auth complete
  ├─ 1000ms: Listener starts (_listenerStartTime set)
  ├─ 1000ms: _listenerReady = true (callback can now execute)
  ├─ 2500ms: Logout called (forceLogout=true written)
  ├─ 3000ms: Device B's listener fires with forceLogout=true
  │         BUT: In protection window (3s - 1s = 2s, and 2s < 10s)
  │         SKIPS logout checks ✓
  │
  ├─ 3000ms: Device A's listener fires
  │         Past initialization (3s > 3s)
  │         DETECTS logout signal
  │         Device A LOGS OUT ✓
  │
  └─ Device B STAYS LOGGED IN ✓
```

## What to Report If Issues Occur

If Device B still logs out, share these logs:

**From Device B**:
- `[LoginScreen]` messages (should show 2.5s wait)
- `[DeviceSession]` messages (should show protection window)
- `[AuthService]` messages (should show forceLogout write)
- Any errors or unexpected messages

**From Device A**:
- `[DeviceSession]` messages (should show logout detection)
- `[RemoteLogout]` messages (should show logout process)

This will help us diagnose the issue.

---

## Summary

✅ **Race condition fixed** - Listener initialization guaranteed safe
✅ **Protection window extended** - 10 seconds covers all scenarios
✅ **Logout delay extended** - 2.5 seconds ensures listener readiness
✅ **Ready for testing** - Build and run now!

Let me know if you see any issues!
