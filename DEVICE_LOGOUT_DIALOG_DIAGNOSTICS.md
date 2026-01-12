# Device Logout Dialog - Enhanced Diagnostics

## Latest Changes
Added comprehensive logging to diagnose why the device logout dialog is not showing.

### Logging Added (All 3 Auth Paths)

#### 1. Phone OTP Verification (`_verifyPhoneOTP()`)
```
[LoginScreen] ===== OTP VERIFICATION ERROR =====
[LoginScreen] Error: <error message>
[LoginScreen] Contains ALREADY_LOGGED_IN: true/false
[LoginScreen] =====================================
[LoginScreen] Device Name: <device name>
[LoginScreen] User ID: <uid>
[LoginScreen] 🔔 Showing device login dialog...
```

#### 2. Email/Password Login (`_handleAuth()`)
```
[LoginScreen] ===== EMAIL/PASSWORD AUTH ERROR =====
[LoginScreen] Error: <error message>
[LoginScreen] Contains ALREADY_LOGGED_IN: true/false
[LoginScreen] ========================================
[LoginScreen] Device Name: <device name>
[LoginScreen] User ID: <uid>
[LoginScreen] 🔔 Showing device login dialog...
```

#### 3. Google Sign-In (`_signInWithGoogle()`)
```
[LoginScreen] ===== GOOGLE SIGN-IN ERROR =====
[LoginScreen] Error: <error message>
[LoginScreen] Contains ALREADY_LOGGED_IN: true/false
[LoginScreen] ======================================
[LoginScreen] Device Name: <device name>
[LoginScreen] User ID: <uid>
[LoginScreen] 🔔 Showing device login dialog...
```

#### 4. Dialog Display Method (`_showDeviceLoginDialog()`)
```
[LoginScreen] 🔴 _showDeviceLoginDialog CALLED
[LoginScreen] 🔴 Device Name: <device name>
[LoginScreen] 🔴 Context mounted: true/false
[LoginScreen] 🔴 About to call showDialog...
[LoginScreen] 🔴 Dialog builder called
```

## Testing Steps

### To Test the Dialog

1. **Setup Two Devices**:
   - Device A: Login and stay logged in
   - Device B: Ready to login

2. **Login on Device B** using one of these methods:
   - Phone OTP
   - Email/Password
   - Google Sign-In

3. **Check Console Output**:
   - Run: `flutter logs` (or check logcat/console in IDE)
   - Look for the messages above

4. **Expected Output**:
   ```
   [LoginScreen] ===== OTP VERIFICATION ERROR =====
   [LoginScreen] Error: Exception: ALREADY_LOGGED_IN:Device Name:userId
   [LoginScreen] Contains ALREADY_LOGGED_IN: true
   [LoginScreen] =====================================
   [LoginScreen] Device Name: Some Device Name
   [LoginScreen] User ID: dBOI4KhSWJU8BimI2CP2
   [LoginScreen] 🔔 Showing device login dialog...
   [LoginScreen] 🔴 _showDeviceLoginDialog CALLED
   [LoginScreen] 🔴 Device Name: Some Device Name
   [LoginScreen] 🔴 Context mounted: true
   [LoginScreen] 🔴 About to call showDialog...
   [LoginScreen] 🔴 Dialog builder called
   ```

## Troubleshooting

### If Dialog Still Doesn't Show

Check console for:

1. **Is error NOT containing "ALREADY_LOGGED_IN"?**
   ```
   [LoginScreen] ❌ Not ALREADY_LOGGED_IN error, showing error snackbar
   ```
   - This means the session check isn't detecting the conflict
   - Issue likely in `_checkExistingSession()` in auth_service.dart

2. **Is `_showDeviceLoginDialog` NOT being called?**
   - Error is caught but dialog method not called
   - Check if the error string parsing is working correctly

3. **Is dialog called but not appearing?**
   - Check: `[LoginScreen] 🔴 Context mounted: <value>`
   - If `false`: Screen may be unmounted before dialog shows
   - If `true` but dialog doesn't appear: Issue in `DeviceLoginDialog` widget

4. **Firestore Permission Errors?**
   - Deploy updated `firestore.rules` to Firebase
   - Current rules allow reading user documents with device fields without auth

## Next Steps

1. Run the app on 2 devices
2. Share the complete console output
3. We'll know exactly where the issue is from the logs
