# Test Execution Guide - Multiple Device Login Fix

**Status**: In Progress
**Build**: ✅ Complete
**App**: ✅ Running on Emulator

---

## Test 1: Single Device Logout (Device A → Device B)

### Setup Requirements
- Emulator 1: Running with app (already running)
- Emulator 2 or Chrome: Ready to launch
- Test email: `test@example.com`
- Test password: `Test@1234`

### Step-by-Step Instructions

#### Step 1A: Login on Device A (Emulator)
```
ACTION:
1. Tap on the Email field in the app
2. Enter: test@example.com
3. Tap on Password field
4. Enter: Test@1234
5. Tap "Login" button
6. WAIT 3-5 seconds for listener initialization

WHAT TO WATCH FOR:
Terminal Output:
  [DeviceSession] Snapshot received: 0.XXs since listener start
  [DeviceSession] EARLY PROTECTION PHASE (2.85s remaining)
  [DeviceSession] forceLogout is FALSE - continuing

Device A Screen:
  Should show: Home screen / Chat screen / Discover screen
  Listener is now ACTIVE and waiting for logout signal
```

#### Step 1B: Launch Second Instance (Chrome)
```
COMMAND (in new terminal):
  flutter run -d chrome

WHAT TO EXPECT:
  Chrome window opens
  Same Supper app loads in browser
  Login screen appears
```

#### Step 1C: Login on Device B (Chrome)
```
ACTION:
1. Tap Email field in Chrome
2. Enter: test@example.com (SAME EMAIL AS DEVICE A)
3. Tap Password field
4. Enter: Test@1234
5. Tap "Login" button

WHAT SHOULD HAPPEN:
  "Device Conflict" dialog appears on Device B
  Message: "You are already logged in on another device"
  Options: "Logout Other Device" or "Cancel"

IF DIALOG DOESN'T APPEAR:
  - Check that Device A is still logged in
  - Check Cloud Functions are deployed
  - Check device token generation is working
```

#### Step 1D: Trigger Logout on Device A
```
ACTION (on Device B - Chrome):
  Click button: "Logout Other Device"

EXPECTED SEQUENCE:
T+0s   You click the button
T+0s   Cloud Function called
T+0s   forceLogout signal sent to Device A
T+0.5s Device A listener detects signal
T+0.5s Device A checks: forceLogout == true? YES ✅
T+0.5s Device A checks: isNewSignal? YES ✅
T+0.5s Device A executes _performRemoteLogout()
T+1s   Device A signs out from Firebase
T+1.5s Device A navigates to login screen
T+2s   Device B fully logged in

WHAT YOU SHOULD SEE:
Device A (Emulator):
  Screen changes to Login screen
  Time: Within 3 seconds (ideally <1 second)

Device B (Chrome):
  Shows: Home screen / Chat / Discover
  Status: Successfully logged in

Terminal Output (Device A):
  [DeviceSession] forceLogout is TRUE - checking if signal is NEW
  [DeviceSession] forceLogoutTime: ... isNewSignal: true
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
  I/flutter: Signing out from Firebase...
  I/flutter: Session cleared
```

### Test 1 Success Criteria

✅ **PASS** if ALL of these are true:
- [x] Device conflict dialog appears on Device B
- [x] Device A automatically logs out
- [x] Logout happens within 3 seconds
- [x] Logs show "FORCE LOGOUT SIGNAL"
- [x] Only Device B remains logged in
- [x] No errors in terminal

❌ **FAIL** if ANY of these occur:
- Device doesn't logout after 5+ seconds
- Device conflict dialog doesn't appear
- Logs show "isNewSignal: FALSE"
- Both devices remain logged in

### Test 1 Results
```
Date: ______________
Device A Type: ____________________
Device B Type: ____________________

Logout Time: ______ seconds
FORCE LOGOUT in logs: YES / NO
Device Conflict Dialog: YES / NO
Only Device B Logged In: YES / NO

Status: ✅ PASS / ❌ FAIL
```

---

## Test 2: Multiple Logout Chain (A→B→C→D)

### Purpose
Verify that the fix works consistently across multiple sequential logouts, not just a single one.

### Setup Requirements
- 4 instances available (Emulator + 3 browsers, or 4 emulators)
- Same test email for all logins: `test@example.com`

### Step-by-Step Instructions

#### Step 2A: Device A Login
```
DEVICE: Emulator 1 (already running)

ACTION:
1. Login with test@example.com / Test@1234
2. WAIT 3-5 seconds for listener to initialize

VERIFY:
  Terminal shows: [DeviceSession] Snapshot received: 0.XXs
  Screen shows: Home/Chat/Discover
  Status: ✅ Device A ready (listening for logout signal)
```

#### Step 2B: Device B Login → A Logout
```
DEVICE: Chrome 1 (new terminal: flutter run -d chrome)

ACTION:
1. Login with test@example.com / Test@1234
2. See device conflict dialog
3. Click "Logout Other Device"

VERIFY Device A:
  ✅ Emulator 1 shows login screen
  ✅ Within 2-3 seconds
  ✅ Terminal shows: [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW

RECORD:
  Time to logout: ______ seconds
  Logs correct: YES / NO
```

#### Step 2C: Device C Login → B Logout
```
DEVICE: Edge/Firefox (new terminal: flutter run -d edge)

ACTION:
1. Login with test@example.com / Test@1234
2. See device conflict dialog
3. Click "Logout Other Device"

VERIFY Device B:
  ✅ Chrome shows login screen
  ✅ Within 2-3 seconds
  ✅ Terminal shows logout signal

RECORD:
  Time to logout: ______ seconds
  Logs correct: YES / NO
```

#### Step 2D: Device D Login → C Logout
```
DEVICE: Another browser instance (new terminal)

ACTION:
1. Login with test@example.com / Test@1234
2. See device conflict dialog
3. Click "Logout Other Device"

VERIFY Device C:
  ✅ Browser shows login screen
  ✅ Within 2-3 seconds
  ✅ Terminal shows logout signal

RECORD:
  Time to logout: ______ seconds
  Logs correct: YES / NO
```

#### Step 2E: Verify Final State
```
EXPECTED RESULT:
  Device A: LOGIN SCREEN ✅
  Device B: LOGIN SCREEN ✅
  Device C: LOGIN SCREEN ✅
  Device D: HOME SCREEN ✅

Only Device D should be logged in
All other devices should show login screen
All logouts should have happened within <3 seconds each
```

### Test 2 Success Criteria

✅ **PASS** if:
- [x] A→B logout: A logs out in <3s
- [x] B→C logout: B logs out in <3s
- [x] C→D logout: C logs out in <3s
- [x] All logouts show FORCE LOGOUT SIGNAL
- [x] Only D remains logged in
- [x] No false logouts

### Test 2 Results
```
═══════════════════════════════════════════════════════════════
Chain Test Results: A→B→C→D
═══════════════════════════════════════════════════════════════

A→B Logout:
  Time: __________ seconds
  Logs FORCE LOGOUT: YES / NO
  Status: ✅ / ❌

B→C Logout:
  Time: __________ seconds
  Logs FORCE LOGOUT: YES / NO
  Status: ✅ / ❌

C→D Logout:
  Time: __________ seconds
  Logs FORCE LOGOUT: YES / NO
  Status: ✅ / ❌

Final State:
  A: LOGIN / HOME
  B: LOGIN / HOME
  C: LOGIN / HOME
  D: LOGIN / HOME ✅

Overall Status: ✅ PASS / ❌ FAIL
```

---

## Test 3: Offline Device Logout

### Purpose
Verify that devices logging out while offline are detected when they reconnect.

### Setup Requirements
- Device A (Emulator 1): Already running with app
- Device B (Chrome or Emulator 2): For logout trigger

### Step-by-Step Instructions

#### Step 3A: Device A Login
```
DEVICE: Emulator 1

ACTION:
1. Login with test@example.com / Test@1234
2. WAIT 3-5 seconds
3. Verify logged in

VERIFY:
  ✅ Screen shows home/chat
  ✅ Terminal shows listener started
```

#### Step 3B: Take Device A Offline
```
METHOD 1: Airplane Mode
  1. Swipe down from top of emulator screen
  2. Tap "Airplane Mode" to enable
  3. All connectivity disabled
  4. App loses network connection

METHOD 2: Kill App Process
  1. Close the app
  2. App will lose connection
  3. Simulate offline state

VERIFY OFFLINE:
  ✅ No network activity
  ✅ App doesn't receive updates
  ✅ Listener can't sync with Firestore
```

#### Step 3C: Device B Logs In & Triggers Logout
```
DEVICE: Chrome (or Emulator 2)

ACTION:
1. Login with test@example.com / Test@1234
2. See device conflict dialog
3. Click "Logout Other Device"

WHAT HAPPENS:
  Cloud Function executes
  Sets forceLogout=true on user document
  Deletes activeDeviceToken
  Device A (offline) doesn't receive this yet
```

#### Step 3D: Device A Comes Back Online
```
METHOD 1: Disable Airplane Mode
  1. Swipe down from top of emulator
  2. Tap "Airplane Mode" to disable
  3. Network reconnected
  4. App reconnects to Firebase

METHOD 2: Reopen App
  1. Tap app icon
  2. App reconnects to Firebase
  3. Listener reattaches

ACTION:
  Wait 5-10 seconds for app to fully reconnect

MONITOR:
  Terminal output
  App network activity
  Listener reconnection
```

#### Step 3E: Verify Offline Logout Detection
```
EXPECTED SEQUENCE:
T+0s   Device A comes online
T+2s   Firestore listener reconnects
T+2s   Listener queries user document
T+2s   Checks: Does activeDeviceToken exist?
T+2s   Answer: NO (was deleted by Cloud Function)
T+2s   Executes token deletion logout path
T+3s   Device A logs out
T+3s   Device A shows login screen

WHAT YOU SHOULD SEE:

Terminal Output:
  [DeviceSession] Snapshot received after reconnect
  [DeviceSession] TOKEN CLEARED ON SERVER ✅
  [DeviceSession] Performing logout for offline device
  I/flutter: Signing out from Firebase...

Device A Screen:
  Changes from home/chat to login screen
  Happens within 3-5 seconds of reconnect
```

### Test 3 Success Criteria

✅ **PASS** if:
- [x] Device B successfully logs in while A is offline
- [x] Device A reconnects
- [x] Device A detects token deletion
- [x] Logs show "TOKEN CLEARED ON SERVER"
- [x] Device A logs out within 3 seconds of reconnect
- [x] Only Device B remains logged in

### Test 3 Results
```
═══════════════════════════════════════════════════════════════
Offline Device Logout Test Results
═══════════════════════════════════════════════════════════════

Device A Offline Method: AIRPLANE MODE / CLOSE APP
Device B Login Time: T + __________ seconds
Device A Reconnect Time: T + __________ seconds
Time Until Logout After Reconnect: __________ seconds

Logs showed TOKEN CLEARED: YES / NO
Device A Logged Out: YES / NO
Time to logout: __________ seconds (expected <3s)

Status: ✅ PASS / ❌ FAIL
```

---

## Test 4: Verify Google API Error Resolution

### Purpose
Confirm that the Google API DEVELOPER_ERROR warning has been resolved or is non-critical.

### Expected Behavior

#### Checking Logs
```
RUN COMMAND:
  flutter logs 2>&1 | grep -i "google\|developer"

BEFORE FIX (OLD):
  W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR...}
  W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR...}
  (Multiple occurrences during startup)

AFTER FIX (EXPECTED):
  Option A: No DEVELOPER_ERROR warnings at all ✅
  Option B: Single warning on startup (non-critical) ✅
  Option C: Warning appears but app functions normally ✅
```

#### App Functionality Check
```
VERIFY:
  ✅ App starts without crashes
  ✅ Login screen loads
  ✅ Email/password login works
  ✅ Firebase authentication responds
  ✅ Firestore listener connects
  ✅ Cloud Functions execute
  ✅ Logout signals detected

If all of above work: GOOGLE API ERROR IS NOT BLOCKING ✅
```

### Test 4 Results
```
═══════════════════════════════════════════════════════════════
Google API Error Verification
═══════════════════════════════════════════════════════════════

DEVELOPER_ERROR warnings appeared: YES / NO

If YES:
  Count: __________ occurrences
  Frequency: ON STARTUP / CONTINUOUS / INTERMITTENT
  Impact on functionality: NONE / MINOR / BLOCKING
  App still works: YES / NO

If NO:
  Status: ✅ DEVELOPER_ERROR resolved!

Certificate Hash Status:
  Checked: YES / NO
  Value: 738cb209a9f1fdf76dd7867865f3ff8b5867f890
  Correct: YES / NO

Overall Assessment: ✅ OK / ⚠️ WARNING / ❌ CRITICAL
```

---

## Test 5: Monitor Logs for Timeout Issues

### Purpose
Verify that there are no timeout issues during logout signal detection.

### What to Monitor

#### Critical Log Messages
```
SHOULD SEE (Good):
  [DeviceSession] Snapshot received: 0.XXs
  [DeviceSession] EARLY PROTECTION PHASE
  [DeviceSession] forceLogout is TRUE
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
  (Within 1 second of logout trigger)

SHOULD NOT SEE (Bad):
  [DeviceSession] Timeout waiting for signal
  [DeviceSession] Listener timeout
  [DeviceSession] Error: Timeout
  (These would indicate timeout issues)
```

#### Timing Analysis
```
MEASURE THESE TIMINGS:

1. Listener Startup (T1)
   From: Login complete
   To: [DeviceSession] Snapshot received
   Expected: <1 second
   Tolerance: <2 seconds

2. Signal Detection (T2)
   From: Cloud Function sends forceLogout
   To: [DeviceSession] ✅ FORCE LOGOUT SIGNAL
   Expected: <500ms
   Tolerance: <1 second

3. Logout Execution (T3)
   From: FORCE LOGOUT detection
   To: Login screen appears
   Expected: <500ms
   Tolerance: <1 second

TOTAL TIME (T1 + T2 + T3):
   Expected: <2 seconds
   Tolerance: <3 seconds
```

#### Log Analysis
```
RUN COMMAND:
  flutter logs > device_logs.txt

Then search for these patterns:
  - "Snapshot received" (how many times? should be regular)
  - "FORCE LOGOUT SIGNAL" (should appear once per logout)
  - "Error" (should be minimal)
  - "Timeout" (should be ZERO)
  - "WARNING" (check for concerning warnings)
```

### Test 5 Monitoring Checklist

```
═══════════════════════════════════════════════════════════════
Timeout & Performance Monitoring
═══════════════════════════════════════════════════════════════

Listener Startup Time:
  Test 1: __________ seconds
  Test 2: __________ seconds
  Test 3: __________ seconds
  Average: __________ seconds
  Status: <2s ✅ / >2s ⚠️

Signal Detection Time:
  Test 1: __________ seconds
  Test 2: __________ seconds
  Test 3: __________ seconds
  Average: __________ seconds
  Status: <1s ✅ / 1-3s ⚠️ / >3s ❌

Total Logout Time:
  Test 1: __________ seconds
  Test 2: __________ seconds
  Test 3: __________ seconds
  Average: __________ seconds
  Status: <3s ✅ / 3-5s ⚠️ / >5s ❌

Timeout Errors Found: NONE ✅ / YES ❌
If YES, count: __________

Performance Status: ✅ EXCELLENT / ⚠️ ACCEPTABLE / ❌ PROBLEMATIC
```

---

## Summary Log Template

```
═══════════════════════════════════════════════════════════════
COMPLETE TEST EXECUTION SUMMARY
═══════════════════════════════════════════════════════════════

DATE: ______________
TESTER: ______________

TEST 1: Single Device Logout (A→B)
  Status: ✅ PASS / ❌ FAIL
  Time to logout: __________ seconds
  FORCE LOGOUT detected: YES / NO
  Issues: __________________________________

TEST 2: Multiple Chain (A→B→C→D)
  Status: ✅ PASS / ❌ FAIL
  A→B time: __________ seconds
  B→C time: __________ seconds
  C→D time: __________ seconds
  Issues: __________________________________

TEST 3: Offline Logout
  Status: ✅ PASS / ❌ FAIL
  Time to logout after reconnect: __________ seconds
  TOKEN CLEARED detected: YES / NO
  Issues: __________________________________

TEST 4: Google API Error
  Status: ✅ OK / ⚠️ WARNING / ❌ CRITICAL
  DEVELOPER_ERROR appeared: YES / NO
  App functionality: NORMAL / DEGRADED / BROKEN
  Issues: __________________________________

TEST 5: Timeout Monitoring
  Status: ✅ NO TIMEOUTS / ⚠️ MINOR / ❌ CRITICAL
  Performance: __________ seconds average
  Anomalies: __________________________________

═══════════════════════════════════════════════════════════════

OVERALL RESULT: ✅ ALL PASS / ⚠️ MIXED / ❌ FAILURES

FIX VERDICT: ✅ WORKING / 🟡 NEEDS INVESTIGATION / ❌ BROKEN

NOTES:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

## Commands Reference

```bash
# Monitor logs
flutter logs

# Get specific logs
flutter logs 2>&1 | grep "DeviceSession"

# Save logs to file
flutter logs > test_logs.txt

# Filter for errors
flutter logs 2>&1 | grep -i "error"

# Filter for timeouts
flutter logs 2>&1 | grep -i "timeout"

# Run app on Chrome
flutter run -d chrome

# Run app on Edge
flutter run -d edge

# List available devices
flutter devices
```

---

## What to Do If Tests Fail

### Single Logout (Test 1) Fails
1. Check device conflict dialog appears (Cloud Functions working?)
2. Check Device A listener is active (logs show "Snapshot received"?)
3. Check forceLogout is TRUE in logs
4. Check isNewSignal validation (should be TRUE)
5. If all above work but logout doesn't happen, check Firestore data directly

### Multiple Chain (Test 2) Fails
1. First logout works but later ones don't? → Listener may not reinitialize
2. Each logout gets slower? → Performance degradation, check for leaks
3. Some logouts work, some don't? → Timestamp validation issue

### Offline Test (Test 3) Fails
1. Device doesn't logout on reconnect? → Check token deletion detection
2. Logs don't show "TOKEN CLEARED"? → Cloud Function may not be deleting token
3. Device reconnects but nothing happens? → Listener may not reattach

### Google API Error (Test 4) Shows
1. This is expected and non-critical
2. If blocking functionality, check Firebase console
3. Otherwise safe to ignore for this testing

### Timeouts Detected (Test 5)
1. Check app performance and memory usage
2. Verify Firestore quota not exceeded
3. Check network latency
4. Review logs for actual errors

---

This guide provides all instructions needed to execute the complete test suite for the multiple device login fix.

