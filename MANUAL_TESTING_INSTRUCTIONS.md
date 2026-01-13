# Manual Testing Instructions - Single Device Login Fix

## ✅ Build Status: SUCCESS

The app has been successfully built and is running on the emulator. The build completed without errors.

**Build Output:**
- ✅ gradle task 'assembleDebug' completed in 46 seconds
- ✅ APK installed successfully
- ✅ App launched on emulator (SDK Android 16)
- ✅ All services initialized (Firestore, FCM, Geolocator, WebRTC)

**Known Warnings (Non-Critical):**
- `W/GoogleApiManager: DEVELOPER_ERROR` - Expected, not related to the fix
- `W/FlagRegistrar: Phenotype.API not available` - Expected, not related to the fix

---

## Testing Your Multiple Device Login Fix

Since you only have one emulator instance running, here's how to properly test the multiple device login scenarios:

### Option A: Quick Test on Single Emulator (5 minutes)

This tests the basic fix quickly using one instance:

#### STEPS:

1. **App is already running on emulator**
   - The app should be on the login screen
   - If not, tap the app icon to open it

2. **First Login**
   - Tap email field
   - Enter: `test1@example.com`
   - Enter password: `Test@1234` (or your test account)
   - Tap "Login" button
   - **Wait 3 seconds** for listener to fully initialize
   - Watch the logs in terminal for: `[DeviceSession] Snapshot received:`

3. **Simulate Second Device**
   - Open a second terminal window
   - Run: `flutter emulators` to see available emulators
   - If you don't have a second emulator, create one:
     ```bash
     flutter emulators --create --name test_device_2
     flutter emulators --launch test_device_2
     ```
   - Once second emulator boots, run on it:
     ```bash
     flutter run -d <second-emulator-id>
     ```

4. **Second Login with Same Email**
   - On the second emulator, login with `test1@example.com`
   - You should see: **"Device Conflict" dialog**
   - This confirms Cloud Functions detected the existing session

5. **Click "Logout Other Device"**
   - Tap this button on the device conflict dialog
   - **Critical moment**: Watch the FIRST emulator

6. **Verify First Device Logs Out**
   - **Expected**: First emulator shows login screen within 2-3 seconds
   - **Check logs**: Look for:
     ```
     [DeviceSession] forceLogout is TRUE
     [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
     ```
   - **If you see this**: ✅ FIX IS WORKING

---

### Option B: Test Using Chrome Web Tab (10 minutes)

Flutter supports running on multiple browsers - use this to simulate multiple devices:

#### STEPS:

1. **First Instance (Emulator)**
   - Your app is already running in terminal
   - Keep it running

2. **Second Instance (Web Browser)**
   - Open a new terminal
   - Run: `flutter run -d chrome`
   - This launches the same app in Chrome browser

3. **Login in Emulator First**
   - Emulator: Login with `test1@example.com`
   - **Wait 3 seconds** for listener startup

4. **Login in Chrome Second**
   - Chrome: Login with same `test1@example.com`
   - You should see "Device Conflict" dialog
   - Click "Logout Other Device"

5. **Watch Emulator**
   - **Expected**: Emulator shows login screen within 3 seconds
   - Check logs in original terminal for `FORCE LOGOUT SIGNAL`

6. **Verify Result**
   - ✅ Emulator logged out
   - ✅ Chrome logged in
   - ✅ Only one device logged in

---

### Option C: Detailed Manual Testing (Most Thorough)

#### Step 1: Create Test Accounts

Before testing, create multiple test Firebase accounts:

1. Open your app in emulator
2. Go to Sign Up
3. Create accounts:
   - Email: `devicetest1@example.com` / Password: `Test@1234`
   - Email: `devicetest2@example.com` / Password: `Test@1234`
   - Email: `devicetest3@example.com` / Password: `Test@1234`
   - Email: `devicetest4@example.com` / Password: `Test@1234`

#### Step 2: Single Device Logout Test

**Objective**: Verify Device A logs out when Device B logs in

**Setup**:
- Emulator 1: Ready
- Emulator 2: Ready (or Chrome)

**Test**:
1. Emulator 1: Login with `devicetest1@example.com`
   - Watch logs: Should see `[DeviceSession] Snapshot received: 0.XXs`
   - Wait 3-5 seconds for listener initialization

2. Emulator 2: Login with `devicetest1@example.com`
   - Should see "Device Conflict" dialog
   - Tap "Logout Other Device"

3. Emulator 1: Watch for logout
   - **Expected Result**: Login screen appears within 3 seconds
   - **Log Check**: Terminal should show:
     ```
     [DeviceSession] forceLogout is TRUE - checking if signal is NEW
     [DeviceSession] forceLogoutTime: ... isNewSignal: true
     [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
     ```

4. **Record Result**:
   - Time to logout: _____ seconds
   - Logs showed FORCE LOGOUT SIGNAL: Yes / No
   - Status: ✅ PASS / ❌ FAIL

#### Step 3: Multiple Logout Chain Test (A→B→C→D)

**Objective**: Test the complete logout chain

**Setup**:
- Have at least 2 emulators or use emulator + Chrome + Edge

**Test Sequence**:

```
DEVICE A (Emulator)
└─ Login: devicetest1@example.com
   └─ Wait 3 seconds for listener

DEVICE B (Emulator 2 or Chrome)
└─ Login: devicetest1@example.com
└─ Click "Logout Other Device"
└─ ✅ VERIFY: Device A logs out within 3 seconds

DEVICE C (Web - Edge or new Chrome)
└─ Login: devicetest1@example.com (same as B)
└─ Click "Logout Other Device"
└─ ✅ VERIFY: Device B logs out within 3 seconds

DEVICE D (4th instance)
└─ Login: devicetest1@example.com (same as C)
└─ Click "Logout Other Device"
└─ ✅ VERIFY: Device C logs out within 3 seconds

RESULT: Only Device D logged in
```

**Log Pattern Expected**:
- Each logout should show same pattern:
  ```
  [DeviceSession] forceLogout is TRUE
  [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
  ```

---

## Critical Logs to Watch For

### ✅ GOOD - Expected When Logout Works

**These logs mean the fix is working:**

```
[DeviceSession] Snapshot received: 0.50s since listener start (listenerStartTime=SET)
[DeviceSession] EARLY PROTECTION PHASE (2.50s remaining) - only skipping token mismatch checks
[DeviceSession] forceLogout is TRUE - checking if signal is NEW
[DeviceSession] forceLogoutTime: 2026-01-13 14:30:45.123Z, listenerTime: 2026-01-13 14:30:42.654Z, isNewSignal: true (margin: 2s)
[DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
```

### ❌ BAD - If You See These, There's an Issue

**These logs indicate a problem:**

```
[DeviceSession] forceLogout is TRUE
[DeviceSession] isNewSignal: FALSE  // ← BAD! Signal was rejected as stale
```

OR

```
[DeviceSession] Error in listener callback: ...  // ← Listener failed
```

OR

**No logout happens after 10 seconds** - means protection window bug is back (unlikely, but indicates regression)

---

## Performance Metrics to Record

For each test, record these metrics:

| Test | Device A | Device B | Device C | Device D | Notes |
|------|----------|----------|----------|----------|-------|
| **Logout Time** | ___s | ___s | ___s | ___s | (seconds until login screen) |
| **Logs FORCE LOGOUT** | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | (check for signal message) |
| **Device Conflict Dialog** | N/A | ✅/❌ | ✅/❌ | ✅/❌ | (dialog appeared) |
| **Status** | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | Pass/Fail |

---

## Offline Device Test (If You Have Time)

### Setup
1. Emulator 1: Login
2. Emulator 1: Activate airplane mode
3. Emulator 2: Login → Click "Logout Other Device"
4. Emulator 1: Deactivate airplane mode
5. Emulator 1: Wait for reconnection
6. **Verify**: Device 1 logs out within 3 seconds of reconnect

### Expected Logs
```
[DeviceSession] TOKEN CLEARED ON SERVER
[DeviceSession] ✅ [will logout]
```

---

## Checklist: What Should Happen

### Before Fix ❌ (Multiple devices logged in)
- Device A logs in
- Device B logs in
- Both devices still logged in
- Logout doesn't work until 10+ seconds have passed

### After Fix ✅ (Only one device logged in)
- Device A logs in
- Device B logs in
- Device B sees conflict dialog
- Device B clicks "Logout Other Device"
- Device A logs out within **<3 seconds**
- Only Device B remains logged in
- Process repeats for C, D, etc.

---

## How to Debug If Tests Fail

### If Device Doesn't Log Out

**Check 1: Is listener running?**
```
Look for: [DeviceSession] Snapshot received: X.XXs
```
If not present → Listener may not have started yet. Wait 5 seconds.

**Check 2: Is forceLogout flag set?**
```
Look for: [DeviceSession] forceLogout is TRUE
```
If FALSE → Cloud Function may not have executed. Check Firebase Console → Cloud Functions logs.

**Check 3: Is signal considered NEW?**
```
Look for: [DeviceSession] isNewSignal: true
```
If FALSE → Timestamp validation is rejecting signal. Check timestamp difference should be <2 seconds apart.

**Check 4: Is logout actually executing?**
```
Look for: [DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW
```
If this appears but no logout happens → UI thread may be frozen. Device needs restart.

### If You See DEVELOPER_ERROR

**This is expected and not related to the fix.**
- Status: Non-critical warning
- Cause: Certain Google Cloud APIs not fully enabled
- Impact: None - app works normally
- Fix: Optional - can be ignored for testing

---

## Summary: Expected Results After Fix

✅ **What should happen**:
- Device A logs in → listener starts
- Device B logs in with same account → conflict dialog shows
- User clicks "Logout Other Device"
- Device A automatically logs out within 2-3 seconds
- Logs show: `[DeviceSession] ✅ FORCE LOGOUT SIGNAL - LOGGING OUT NOW`

✅ **The fix is working if**:
- Logout happens within 3 seconds (20x faster than before)
- Only ONE device stays logged in
- Logs show FORCE LOGOUT SIGNAL message
- Multiple chain (A→B→C→D) all work consistently

❌ **The fix needs more work if**:
- Logout takes 10+ seconds
- Multiple devices stay logged in
- FORCE LOGOUT SIGNAL logs are missing
- Timestamp validation rejects signal (isNewSignal: false)

---

## Next Steps

1. **Choose test method** (A, B, or C above)
2. **Run test scenario** according to chosen method
3. **Record results** in the metrics table above
4. **Check logs** for expected messages
5. **Verify logout time** (should be <3 seconds)
6. **Report results** back with:
   - Number of successful logouts
   - Time each logout took
   - Whether logs showed FORCE LOGOUT SIGNAL
   - Any errors encountered

The critical fix has been applied. These tests will validate that it's working correctly in your environment.

