# Troubleshoot: Both Devices Staying Logged In

**Issue**: When Device B logs in, Device A stays logged in instead of logging out
**Status**: Added comprehensive logging to diagnose the issue
**Commit**: 4a7dd49

---

## What Just Changed

I added detailed logging at every step of the device logout process so we can see EXACTLY where it's failing.

---

## How to Diagnose the Issue

### Step 1: Rebuild the App

```bash
cd c:/Users/csp/Documents/plink-live
flutter clean && flutter pub get
```

### Step 2: Run Two Emulators

**Terminal 1 (Device A)**:
```bash
flutter run -d emulator-5554
# Login: test@example.com / password123
# Wait for app to fully load (30 seconds)
```

**Terminal 2 (Device B)** - After 30 seconds:
```bash
flutter run -d emulator-5556
# Login: test@example.com / password123 (SAME account)
```

### Step 3: Watch the Logs

Look for these log patterns:

**From Device B (logs to watch)**:
```
[LoginScreen] ========== AUTO LOGOUT START ==========
[LoginScreen] Pending User ID: [should show a user ID]
[LoginScreen] Current Firebase User: [should show a user ID]
[LoginScreen] Starting automatic logout of other device...
[LoginScreen] Waiting 2.5 seconds for listener to initialize...
[LoginScreen] Listener initialized, now logging out other device...
[LoginScreen] Calling logoutFromOtherDevices()...

[AuthService] ========== LOGOUT OTHER DEVICES START ==========
[AuthService] userId parameter: [should show user ID]
[AuthService] currentUser?.uid: [should show user ID]
[AuthService] Final uid to use: [should show user ID]
[AuthService] Current token: [should show device token]
[AuthService] Calling Cloud Function: forceLogoutOtherDevices
```

---

## What Each Log Means

### 1. Is Auto-Logout Function Called?

**Look for**:
```
[LoginScreen] ========== AUTO LOGOUT START ==========
```

**If you see this**: ✅ Function is being called
**If you DON'T see this**: ❌ Auto-logout function is not being called

→ If not seen: The ALREADY_LOGGED_IN error is not being caught properly

---

### 2. Are User IDs Correct?

**Look for**:
```
[LoginScreen] Pending User ID: abc123...
[LoginScreen] Current Firebase User: abc123...
[AuthService] Final uid to use: abc123...
```

**If both match**: ✅ User ID is correct
**If they don't match or are NULL**: ❌ User ID problem

→ If NULL: The error parsing from ALREADY_LOGGED_IN message failed

---

### 3. Is Cloud Function Called?

**Look for**:
```
[AuthService] Calling Cloud Function: forceLogoutOtherDevices
```

**After this, look for EITHER**:

**Option A - Cloud Function Success** ✅:
```
[AuthService] ✓ Successfully forced logout on other devices - instant like WhatsApp!
```

**Option B - Cloud Function Fails** (shows fallback):
```
[AuthService] Cloud Function error: [error message]
[AuthService] Attempting direct Firestore write as fallback...
[AuthService] STEP 1: Writing forceLogout=true
```

---

### 4. Does Fallback Write Succeed?

**Look for**:
```
[AuthService] ✓ STEP 1 succeeded - forceLogout signal sent
[AuthService] ✓ STEP 2 succeeded - new device set as active
[AuthService] ✓ STEP 3 succeeded - forceLogout flag cleared
[AuthService] ✓ Fallback write succeeded - forced logout completed
```

**If you see these**: ✅ Firestore writes succeeded
**If you see errors**: ❌ Firestore writes failed

---

### 5. Function Completes Successfully?

**Look for**:
```
[LoginScreen] ========== AUTO LOGOUT END SUCCESS ==========
```

OR

```
[AuthService] ========== LOGOUT OTHER DEVICES END SUCCESS ==========
```

**If you see these**: ✅ Function completed without errors
**If you see ERROR instead**: ❌ Function threw an exception

---

## Common Issues & How to Diagnose

### Issue 1: Auto-Logout Never Called

**Symptom**:
- No `[LoginScreen] ========== AUTO LOGOUT START ==========` in logs

**Cause**: ALREADY_LOGGED_IN error not being caught

**To diagnose**:
1. Look for errors in Device B logs
2. Look for `if (errorMsg.contains('ALREADY_LOGGED_IN'))` path
3. Check if Device B shows error message instead

---

### Issue 2: User ID is NULL

**Symptom**:
```
[LoginScreen] Pending User ID: null
[AuthService] Final uid to use: null
```

**Cause**: Error parsing failed to extract user ID from ALREADY_LOGGED_IN message

**To diagnose**:
1. Look at the full error message in logs
2. Check format: `ALREADY_LOGGED_IN:Device Name:userId`
3. Verify parsing logic is working

---

### Issue 3: Cloud Function Fails

**Symptom**:
```
[AuthService] Cloud Function error: [error]
```

**Possible Causes**:
1. Cloud Function not deployed
2. User not authenticated
3. Firebase Project mismatch

**To diagnose**:
1. Check exact error message
2. Run: `npx firebase deploy --only functions`
3. Check Firebase Console → Functions → Logs

---

### Issue 4: Fallback Write Fails

**Symptom**:
```
[AuthService] ❌ Fallback write FAILED: [error]
```

**Common Error**: `PERMISSION_DENIED`
- Firestore Rules not deployed or don't allow update

**To diagnose**:
1. Run: `npx firebase deploy --only firestore:rules`
2. Check Firebase Console → Firestore → Rules
3. Verify rules allow `forceLogout` update

---

### Issue 5: Device A Never Gets Logout Signal

**Symptom**:
- Device B logs show: `✓ Other device logout command sent`
- Device A logs DON'T show: `[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED`

**Cause**: Firestore write succeeded but Device A listener not detecting it

**To diagnose**:
1. Check Device A logs for listener startup messages
2. Verify Device A listener is active
3. Check Firestore console to see if `forceLogout: true` was written

---

## What to Do When You Find the Issue

Once you identify where it's failing, share the logs with:

1. **Full Device B logs** showing:
   - `[LoginScreen] AUTO LOGOUT START` to `END`
   - `[AuthService] LOGOUT OTHER DEVICES START` to `END`

2. **Full error messages** if any appear

3. **Device A logs** showing listener status

---

## Steps to Get Logs

### Run with Verbose Output

```bash
flutter run -v -d emulator-5554
```

This shows more detailed logs.

### Save Logs to File

```bash
flutter run -d emulator-5554 > device_a_logs.txt 2>&1 &
flutter run -d emulator-5556 > device_b_logs.txt 2>&1 &
```

Then share `device_b_logs.txt` for analysis.

---

## What Happens After You Share Logs

Once I see the logs, I can identify exactly which step is failing:

1. ✅ Is auto-logout function called?
2. ✅ Is user ID extracted correctly?
3. ✅ Is Cloud Function called?
4. ✅ Is fallback Firestore write succeeding?
5. ✅ Is Device A listener detecting the signal?

Then we'll have a targeted fix.

---

## Summary

**What Changed**: Added logging at every step
**Why**: To see EXACTLY where the logout process fails
**What To Do**:
  1. Rebuild app
  2. Run test again
  3. Share Device B logs
  4. I'll identify the exact failure point

---

## Next Steps

1. Run: `flutter clean && flutter pub get`
2. Test with two emulators again
3. Copy the logs from Device B
4. Share them so we can diagnose

The logging will show us exactly where the process breaks, and then we can fix it properly.
