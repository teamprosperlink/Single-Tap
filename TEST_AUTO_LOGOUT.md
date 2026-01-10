# 🧪 Auto-Logout Testing Guide

## Quick Test (5 Minutes)

### Setup
- **Device A**: Emulator or Phone
- **Device B**: Real Device or Second Emulator
- **Network**: Both connected to internet

### Test Steps

**Step 1: Device A Login**
```
1. Open emulator app
2. Login with test@example.com / password123
3. See home screen ✓
4. Keep app open
5. Open console to watch logs
```

**Step 2: Device B Conflict**
```
1. Open real device app
2. Try login with test@example.com / password123
3. Get error: "Already logged in on [Device A name]" ✓
4. Device B shows: "This account is already logged in on another device"
5. Device B cannot access app ✓
```

**Step 3: Watch Device A Auto-Logout**
```
Console should show:
[Stream] 📡 Firestore update
[Stream] ❌ TOKEN MISMATCH/DELETED
[Stream] Calling _performRemoteLogout()

[Logout] ========== REMOTE LOGOUT INITIATED ==========
[Logout] ✓ Cancelled all timers
[Logout] ✓ Local device token cleared
[Logout] Step 1: forceLogout() succeeded
[Logout] Step 2: Verification - current user: NULL (GOOD!)
[Logout] ========== LOGOUT PROCESS COMPLETE ==========

Screen should show:
- Red snackbar: "Logged out: Account accessed on another device"
- After 1-2 seconds → LoginScreen appears ✓
```

**Step 4: Device B Can Now Login**
```
1. Device B: Try login again with test@example.com
2. Expected: Login succeeds ✓
3. Device B: See home screen ✓
```

## Expected Results

### ✅ Test Passes If:
- Device A shows red snackbar notification
- LoginScreen appears automatically after snackbar
- Console shows all [Stream] and [Logout] messages
- Device B can login after Device A logout

### ❌ Test Fails If:
- Device A doesn't show snackbar
- LoginScreen doesn't appear
- Console shows [Stream] but no [Logout] messages
- Device B cannot login second time

## Console Messages to Watch

### Success Indicators
```
[Stream] ❌ TOKEN MISMATCH/DELETED   ← Good! Mismatch detected
[Logout] ✓ Step 1: forceLogout() succeeded   ← Good! Firebase logout
[Logout] Step 2: Verification - current user: NULL (GOOD!)   ← Good! User is null
```

### Error Indicators
```
[Logout] ⚠️ Step 1: forceLogout() failed   ← Problem!
[Logout] ❌ Step 2: Force signout failed   ← Problem!
[Logout] ⚠️ Step 2: User still logged in!   ← Problem!
```

## Troubleshooting

### Problem: No [Stream] messages in console
**Solution:**
- Make sure Firestore listener is set up
- Check internet connection on both devices
- Device B logout must delete the token
- Wait 2-3 seconds for Firestore to sync

### Problem: [Stream] message but no [Logout]
**Solution:**
- Check if _performRemoteLogout() is being called
- May be mounted=false issue
- Check if widget is still in tree

### Problem: [Logout] messages but LoginScreen doesn't appear
**Solution:**
- Check if StreamBuilder is listening
- May need to restart app
- Check if Firebase signout actually worked
- Verify currentUser is actually null after logout

### Problem: Red snackbar appears but LoginScreen doesn't change
**Solution:**
- Snackbar appears immediately
- LoginScreen change takes 1-2 seconds
- Give it time to rebuild
- Check state changes in console

## Manual Verification

If automatic test fails, try manually:

```dart
// In console, after logout:
// 1. Check Firebase auth state
final user = FirebaseAuth.instance.currentUser;
print('User: ${user?.uid}');  // Should print: null

// 2. Check local token
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('device_login_token');
print('Token: $token');  // Should print: null
```

## Video Test (Optional)

Record a video of:
1. Device A logged in
2. Device B trying to login
3. Red snackbar appearing on Device A
4. LoginScreen appearing on Device A
5. Device B successfully logging in

This confirms the fix is working.

## Summary

**Good Test Result:**
```
Device A: Auto-logout ✓
Snackbar shown ✓
LoginScreen appears ✓
Device B can login ✓
Console logs complete ✓
```

**Test Ready!** 🚀

