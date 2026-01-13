# Log Monitoring Guide - Real-Time Test Analysis

**Purpose**: Monitor and interpret logs during test execution
**Duration**: Use throughout all tests
**Output**: Detailed log analysis for each test scenario

---

## Real-Time Log Monitoring Setup

### Step 1: Open Log Stream

Open a dedicated terminal for log monitoring:

```bash
# Terminal dedicated to logs
flutter logs
```

Keep this terminal open throughout all tests.

### Step 2: Filter Logs (Optional)

For cleaner output, filter to only device session logs:

```bash
# Only DeviceSession logs (cleaner)
flutter logs 2>&1 | grep "DeviceSession"

# All logs including errors
flutter logs 2>&1

# Save to file for later analysis
flutter logs > complete_test_logs.txt &
```

### Step 3: Understand Log Timestamps

Each log entry has a format like:
```
I/flutter (12345): [DeviceSession] Message here
│                 │
│                 └─ Component tag
└─ Priority (I=Info, W=Warning, E=Error)
```

---

## Test 1: Single Device Logout - Log Analysis

### Expected Log Sequence for Device A Login

```
T=0:00s
┌─────────────────────────────────────────────────────────────┐
│ Device A logs in successfully                               │
└─────────────────────────────────────────────────────────────┘

I/flutter: [AuthService] Firebase authentication successful
I/flutter: [AuthService] Device token generated: abc123def...
I/flutter: [AuthService] Saving device session...
I/flutter: [AuthService] Device session saved

T=0:01s - T=0:05s
┌─────────────────────────────────────────────────────────────┐
│ Device A listener initializing                              │
└─────────────────────────────────────────────────────────────┘

I/flutter: [DeviceSession] Listener attached to user document
I/flutter: [DeviceSession] Initial snapshot received
I/flutter: [DeviceSession] Snapshot received: 0.15s since listener start (listenerStartTime=SET)
I/flutter: [DeviceSession] EARLY PROTECTION PHASE (2.85s remaining) - only skipping token mismatch checks
I/flutter: [DeviceSession] forceLogout is FALSE - continuing with other checks
I/flutter: [DeviceSession] Skipping token mismatch check (within early protection phase)

✅ GOOD: Listener is active and waiting
```

### Expected Log Sequence When Device B Logs In

```
T=0:06s - T=0:07s
┌─────────────────────────────────────────────────────────────┐
│ Device B shows conflict dialog (Cloud Function triggered)   │
└─────────────────────────────────────────────────────────────┘

D/AnalyticsConnector: App measurement disabled
I/flutter: [AuthService] Existing session detected
I/flutter: [AuthService] Showing device conflict dialog

At this point:
  Cloud Function is executing in background
  Setting forceLogout=true on user document
  Device A's listener will receive update

✅ GOOD: Device conflict detected
```

### Expected Log Sequence When Device A Detects Logout Signal

```
T=0:07s - T=0:08s
┌─────────────────────────────────────────────────────────────┐
│ Device A listener receives forceLogout signal                │
└─────────────────────────────────────────────────────────────┘

I/flutter: [DeviceSession] Snapshot received: 0.06s since listener start
I/flutter: [DeviceSession] EARLY PROTECTION PHASE (2.94s remaining)
I/flutter: [DeviceSession] forceLogout value: true (type: bool)
I/flutter: [DeviceSession] forceLogout parsed: true
I/flutter: [DeviceSession] forceLogout is TRUE - checking if signal is NEW
I/flutter: [DeviceSession] forceLogoutTime: 2026-01-13 14:30:45.123456Z, listenerTime: 2026-01-13 14:30:42.654321Z, isNewSignal: true (margin: 2s)
I/flutter: [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW

✅ CRITICAL: If you see this line, the fix is working!
```

### Expected Log Sequence During Logout

```
T=0:08s - T=0:09s
┌─────────────────────────────────────────────────────────────┐
│ Device A logging out                                         │
└─────────────────────────────────────────────────────────────┘

I/flutter: [DeviceSession] Signing out from Firebase...
I/flutter: [DeviceSession] Firebase sign out successful
I/flutter: [DeviceSession] Clearing local session data...
I/flutter: [DeviceSession] Session cleared
I/flutter: [DeviceSession] Navigating to login screen
I/firebase_auth]: Auth state changed: null (logged out)

✅ GOOD: All logout steps completed
```

### Test 1: Log Interpretation

| Log Message | Meaning | Status |
|-------------|---------|--------|
| `Snapshot received: X.XXs` | Listener is active | ✅ Good |
| `EARLY PROTECTION PHASE` | Protection window active | ✅ Good |
| `forceLogout is TRUE` | Signal received | ✅ Good |
| `isNewSignal: true` | Signal is fresh | ✅ Good |
| `✅ FORCE LOGOUT SIGNAL` | **FIX IS WORKING** | ✅ CRITICAL |
| `Signing out from Firebase` | Logout executing | ✅ Good |
| `isNewSignal: FALSE` | Signal rejected as stale | ❌ Bad |
| `forceLogout is FALSE` | Signal not received | ❌ Bad |
| `Error` | Something failed | ❌ Bad |

---

## Test 2: Multiple Chain Logout - Log Analysis

### What You Should See for Each Chain Step

#### A→B Sequence

```
Device A Logs In:
  [DeviceSession] Snapshot received: 0.15s
  [DeviceSession] forceLogout is FALSE

Device B Logs In:
  [AuthService] Existing session detected
  [AuthService] Showing device conflict dialog

Device A Detects Signal:
  [DeviceSession] Snapshot received: 6.05s
  [DeviceSession] forceLogout is TRUE
  [DeviceSession] isNewSignal: true ✅
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW ✅

Expected Timeline:
  T=0:00  A logs in
  T=0:05  B logs in
  T=0:06  A detects signal
  T=0:06-T=0:07  A logs out

Time: < 2 seconds ✅
```

#### B→C Sequence

```
Same pattern repeats with B→C:

Device B Logs In:
  [DeviceSession] Snapshot received: 1.05s
  [DeviceSession] forceLogout is FALSE

Device C Logs In:
  [AuthService] Existing session detected

Device B Detects Signal:
  [DeviceSession] Snapshot received: 5.05s
  [DeviceSession] forceLogout is TRUE
  [DeviceSession] isNewSignal: true ✅
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW ✅

Expected: B logs out within 2 seconds
```

#### C→D Sequence

```
Same pattern again:

Device C Logs In:
  [DeviceSession] Snapshot received: 1.05s
  [DeviceSession] forceLogout is FALSE

Device D Logs In:
  [AuthService] Existing session detected

Device C Detects Signal:
  [DeviceSession] forceLogout is TRUE
  [DeviceSession] isNewSignal: true ✅
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW ✅

Expected: C logs out within 2 seconds
```

### Chain Test: Success Indicators

```
✅ CHAIN IS WORKING IF:
  - Each logout shows: ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
  - Each logout happens within 2-3 seconds
  - Pattern repeats consistently for A→B, B→C, C→D
  - No timeout errors
  - No "isNewSignal: FALSE" messages

❌ CHAIN HAS PROBLEMS IF:
  - First logout works but later ones don't
  - Timeouts appear between logouts
  - Logouts get progressively slower
  - "isNewSignal: FALSE" appears in any logout
  - Device remains logged in after logout attempt
```

---

## Test 3: Offline Device Logout - Log Analysis

### Offline Phase (Device A Offline)

```
Device A Goes Offline:
  (No logs appear - device has no connection)

Device B Logs In:
  [AuthService] Existing session detected
  [AuthService] Showing device conflict dialog

Device B Triggers Logout:
  (Cloud Function executes, but Device A doesn't see it yet)
```

### Reconnection Phase (Device A Comes Back Online)

```
Device A Reconnects:
  I/flutter: App resumed
  I/flutter: [DeviceSession] Attempting to reattach listener

Listener Reattaches:
  I/flutter: [DeviceSession] Listener attached to user document
  I/flutter: [DeviceSession] Snapshot received after offline period

Token Deletion Detection:
  I/flutter: [DeviceSession] Snapshot received: 2.15s since listener start
  I/flutter: [DeviceSession] PROTECTION PHASE COMPLETE
  I/flutter: [DeviceSession] activeDeviceToken is EMPTY
  I/flutter: [DeviceSession] localTokenValid: true
  I/flutter: [DeviceSession] TOKEN CLEARED ON SERVER ✅
  I/flutter: [DeviceSession] Performing offline logout
  I/flutter: [DeviceSession] ✅ Logging out due to token deletion

Logout Execution:
  I/flutter: [DeviceSession] Signing out from Firebase...
  I/flutter: [DeviceSession] Navigating to login screen

✅ CRITICAL: Look for "TOKEN CLEARED ON SERVER"
```

### Offline Test: Log Interpretation

| Log Message | Meaning | Status |
|-------------|---------|--------|
| `Listener attached after offline` | Reconnected to Firestore | ✅ Good |
| `TOKEN CLEARED ON SERVER` | **Offline logout detected** | ✅ CRITICAL |
| `Logging out due to token deletion` | Executing offline logout | ✅ Good |
| `Signing out from Firebase` | Logout completing | ✅ Good |
| (No TOKEN CLEARED message) | Token deletion not detected | ❌ Bad |
| (No logout after reconnect) | Offline logout failed | ❌ Bad |

---

## Test 4: Google API Error - Log Analysis

### Checking for DEVELOPER_ERROR

```bash
# Search for error
flutter logs 2>&1 | grep -i "developer_error"

# Or look for GoogleApiManager
flutter logs 2>&1 | grep -i "googleapi"
```

### Expected Output

#### BEFORE Fix (Would Have Had Multiple)
```
W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR...}
W/GoogleApiManager: ConnectionResult{statusCode=DEVELOPER_ERROR...}
(Multiple times during startup)
```

#### AFTER Fix (Current Expected)
```
Option A: No warnings at all ✅
Option B: Single warning at startup ✅
Option C: Warning appears but app functions normally ✅
```

### Verification Steps

```
1. Check if DEVELOPER_ERROR appears:
   flutter logs | grep "DEVELOPER_ERROR"

   If YES: How many times? Expected: 0-1

2. Verify app functionality works despite warning:
   ✓ Can login
   ✓ Firestore listener connects
   ✓ Cloud Functions execute
   ✓ All tests pass

   If all work: Error is NON-CRITICAL ✅

3. Check for blocking errors:
   flutter logs | grep -i "error"
   flutter logs | grep -i "failed"

   Should only see non-critical warnings
```

### Google API Error: Conclusion

```
If DEVELOPER_ERROR appears but:
  ✅ App works normally
  ✅ All other tests pass
  ✅ No functional impact

Then: Status = ✅ ACCEPTABLE (non-critical)

If DEVELOPER_ERROR appears AND:
  ❌ App crashes
  ❌ Login fails
  ❌ Tests fail

Then: Status = ❌ CRITICAL (needs investigation)
```

---

## Test 5: Timeout Monitoring - Live Analysis

### Setting Up Performance Monitoring

```bash
# Save complete logs with timestamps
flutter logs --verbose > performance_logs.txt &

# Monitor in real-time
flutter logs
```

### What to Track

#### Listener Startup Time (T1)

```
LOOK FOR:
  [DeviceSession] Listener attached
  to
  [DeviceSession] Snapshot received: X.XXs

Time difference = Startup delay
Expected: < 1 second
Tolerance: < 2 seconds

Example:
  14:30:42.100 [DeviceSession] Listener attached
  14:30:42.250 [DeviceSession] Snapshot received: 0.15s
  Startup time = 150ms ✅
```

#### Signal Detection Time (T2)

```
LOOK FOR:
  Cloud Function sends forceLogout (approximately T+0s)
  to
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW

Time difference = Detection delay
Expected: < 500ms
Tolerance: < 1 second

Example:
  14:30:45.000 [Cloud Function] Sets forceLogout=true
  14:30:45.300 [DeviceSession] ✅ FORCE LOGOUT SIGNAL
  Detection time = 300ms ✅
```

#### Logout Execution Time (T3)

```
LOOK FOR:
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
  to
  [DeviceSession] Signing out from Firebase...
  to
  [firebase_auth] Auth state changed: null (logged out)

Time difference = Execution delay
Expected: < 500ms
Tolerance: < 1 second
```

### Performance Log Template

```
═══════════════════════════════════════════════════════════════

TEST 1: Single Logout (A→B)

Event Timeline:
  T=0:00  Device A login complete
  T=0:01  [DeviceSession] Snapshot received: 0.15s (Listener OK ✅)
  T=0:05  Device B login starts
  T=0:06  [AuthService] Conflict detected
  T=0:06  Cloud Function sends forceLogout=true
  T=0:06.5 [DeviceSession] ✅ FORCE LOGOUT SIGNAL
  T=0:07  [DeviceSession] Signing out...
  T=0:08  Login screen appears

Measurements:
  Listener startup time: __________ ms (expected <1000ms)
  Signal detection time: __________ ms (expected <500ms)
  Logout execution time: __________ ms (expected <500ms)
  TOTAL TIME: __________ seconds (expected <3s)

Status: ✅ GOOD / ⚠️ ACCEPTABLE / ❌ SLOW
```

### Timeout Detection

```
LOOK FOR THESE ERROR PATTERNS:

1. Listener timeout:
   [DeviceSession] Listener timeout waiting for snapshot
   [DeviceSession] Reattaching listener

   Indicates: Firestore connection issue
   Action: Check network, Firestore quota

2. Signal timeout:
   [DeviceSession] Timeout waiting for forceLogout signal

   Indicates: Cloud Function not executing
   Action: Check Cloud Functions logs

3. Logout timeout:
   [DeviceSession] Logout timeout
   [DeviceSession] Force logout after 5 seconds

   Indicates: Logout process stalled
   Action: Check for Firebase errors

4. General timeout:
   [DeviceSession] Operation timeout after X seconds

   Indicates: General performance issue
   Action: Check app logs for errors
```

---

## Real-Time Log Dashboard (Manual)

Create a quick reference while monitoring:

```
═══════════════════════════════════════════════════════════════
REAL-TIME TEST MONITORING DASHBOARD
═══════════════════════════════════════════════════════════════

TEST STATUS:                        MONITORING LOGS FOR:
[ ] Test 1 In Progress              [ ] Listener startup
[ ] Test 2 In Progress              [ ] Signal detection
[ ] Test 3 In Progress              [ ] Logout execution
[ ] Test 4 In Progress              [ ] Timeout errors
[ ] Test 5 In Progress              [ ] FORCE LOGOUT signal

CURRENT TIME: ____________          DEVICE A LOGS:
ELAPSED: ____:____                  Last message: ________________
                                    Status: ✅/❌

PERFORMANCE METRICS (Current Test):
  Listener startup: __________ ms
  Signal detection: __________ ms
  Logout time: __________ ms
  Total time: __________ ms

ERRORS DETECTED: __________
WARNINGS: __________

═══════════════════════════════════════════════════════════════
```

---

## Quick Log Analysis Checklist

Use this during testing to verify logs are correct:

```
TEST 1: Single Logout (A→B)
  [ ] Listener started ([DeviceSession] Snapshot received)
  [ ] forceLogout is TRUE (logs show true value)
  [ ] isNewSignal is TRUE (signal validation passed)
  [ ] ✅ FORCE LOGOUT SIGNAL (critical message)
  [ ] Logout within 3 seconds
  [ ] No timeout errors
  [ ] No "Error" messages related to logout

Result: ✅ PASS / ❌ FAIL

TEST 2: Multiple Chain (A→B→C→D)
  [ ] Each step shows: ✅ FORCE LOGOUT SIGNAL
  [ ] Each logout: <3 seconds
  [ ] A→B: No issues
  [ ] B→C: No issues
  [ ] C→D: No issues
  [ ] Pattern consistent

Result: ✅ PASS / ❌ FAIL

TEST 3: Offline Logout
  [ ] Device A goes offline (no logs)
  [ ] Device B logs in successfully
  [ ] Device A reconnects
  [ ] TOKEN CLEARED ON SERVER (critical message)
  [ ] Device A logs out after reconnect
  [ ] Logout within 3 seconds

Result: ✅ PASS / ❌ FAIL

TEST 4: Google API Error
  [ ] App starts normally
  [ ] No blocking errors
  [ ] DEVELOPER_ERROR: 0-1 occurrence (acceptable)
  [ ] All functionality works

Result: ✅ OK / ⚠️ WARNING / ❌ CRITICAL

TEST 5: Timeout Monitoring
  [ ] No timeout errors found
  [ ] Performance within tolerance
  [ ] All operations complete within 3 seconds
  [ ] No anomalies detected

Result: ✅ PASS / ⚠️ SLOWNESS / ❌ TIMEOUTS
```

---

## Saving and Analyzing Logs

### Save Complete Logs

```bash
# Save to file
flutter logs > test_logs_$(date +%Y%m%d_%H%M%S).txt

# Save and continue monitoring
flutter logs | tee test_logs.txt
```

### Analyze Saved Logs

```bash
# Count FORCE LOGOUT signals
grep -c "FORCE LOGOUT SIGNAL" test_logs.txt

# Find all errors
grep -i "error\|exception" test_logs.txt

# Find timeouts
grep -i "timeout" test_logs.txt

# Extract timings
grep "Snapshot received\|FORCE LOGOUT\|Signing out" test_logs.txt

# Get unique messages
grep "DeviceSession" test_logs.txt | sort | uniq
```

---

## Final Log Summary

After all tests, create a summary:

```
═══════════════════════════════════════════════════════════════
FINAL LOG ANALYSIS SUMMARY
═══════════════════════════════════════════════════════════════

Total Test Duration: __________ minutes
Total Logout Signals Detected: __________
Total Timeout Errors: __________
Total Exceptions: __________

Log File Size: __________ KB
Unique Error Messages: __________

Critical Logs Found:
  ✅ FORCE LOGOUT SIGNAL: __________ occurrences
  ✅ TOKEN CLEARED: __________ occurrences
  ❌ Timeout errors: __________ occurrences
  ❌ isNewSignal: FALSE: __________ occurrences

Performance Summary:
  Avg Listener Startup: __________ ms
  Avg Signal Detection: __________ ms
  Avg Logout Time: __________ ms
  Avg Total Time: __________ ms

Conclusion:
  ✅ All tests passed with good performance
  ⚠️ Tests passed but with some slowness
  ❌ Tests had failures or timeouts

Overall Status: ✅ OK / ⚠️ ISSUES / ❌ CRITICAL
```

---

This guide provides everything needed to monitor and interpret logs during test execution. Keep this open alongside the TEST_EXECUTION_GUIDE.md while running tests.

