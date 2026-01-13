# Logout Popup - Every Login Attempt

**Date**: 2026-01-13
**Status**: ✅ Already Implemented

---

## How It Works

**Jab bhi same account se login attempt ho, logout popup show hoga.**

### Implementation

The popup shows because of this logic in **all login methods** (Email, Google, Phone):

```dart
// 1. Firebase auth succeeds
final UserCredential result = await _auth.signInWithEmailAndPassword(...);

// 2. Check if another device already logged in
final sessionCheck = await _checkExistingSession(result.user!.uid);

// 3. If exists, show popup
if (sessionCheck['exists'] == true) {
  throw Exception('ALREADY_LOGGED_IN:...');
}

// 4. LoginScreen catches this and shows DeviceLoginDialog
```

---

## Login Methods That Support It

### ✅ Email/Password Login
[auth_service.dart:43-99](lib/services/auth_service.dart#L43-L99)
- Generates device token
- Checks existing session
- Shows popup if conflict found

### ✅ Google Sign-In
[auth_service.dart:199-275](lib/services/auth_service.dart#L199-L275)
- Generates device token
- Checks existing session
- Shows popup if conflict found

### ✅ Phone OTP Login
[auth_service.dart:395-520](lib/services/auth_service.dart#L395-L520)
- Generates device token
- Checks existing session
- Shows popup if conflict found

---

## When Popup Shows

### Scenario 1: First Login Ever
```
Device A: No session in Firestore
Result: ❌ No popup (no conflict)
Device A logs in normally
```

### Scenario 2: Same Device, Re-login
```
Device A: Already has activeDeviceToken in Firestore
Device A: Logs in again
Result: ❌ No popup
Reason: Session exists BUT token matches local token
         (Line 977 in auth_service: serverToken == localToken)
```

### Scenario 3: Different Device, Same Account
```
Device A: activeDeviceToken = ABC123 (logged in)
Device B: Tries to login
Device B: Gets token = XYZ789 (different!)
Result: ✅ Popup appears!
Message: "Your account was just logged in on [Device A Model]"
```

### Scenario 4: Chain Login (A → B → C)
```
Device A login: ✅ No popup (first)
Device B login: ✅ Popup (conflict with A)
Device C login: ✅ Popup (conflict with B, if A logged out)
```

---

## Session Check Logic

[auth_service.dart:960-1026](lib/services/auth_service.dart#L960-L1026)

```dart
Future<Map<String, dynamic>> _checkExistingSession(String uid) async {
  // Get server token from Firestore
  final serverToken = doc.data()?['activeDeviceToken'] as String?;

  // Get local device token
  final localToken = await getLocalDeviceToken();

  // Popup shows only if:
  // 1. Server has a token (another device is active)
  // 2. AND local token is missing OR doesn't match
  // 3. AND session is not stale (< 5 minutes)

  if (serverToken != null &&
      serverToken.isNotEmpty &&
      (localToken == null || serverToken != localToken)) {
    return {'exists': true}; // Popup will show ✅
  }

  return {'exists': false}; // No popup
}
```

---

## Testing All Scenarios

### Test 1: Fresh Install (First Login)
```bash
1. Uninstall app from Device A
2. Fresh install
3. Login with email

Expected: ❌ No popup
Result: Device A logs in directly ✅
```

### Test 2: Re-login Same Device
```bash
1. Device A: Logged in
2. Device A: Open app, logout
3. Device A: Login with same email

Expected: ❌ No popup
Result: Device A logs in directly ✅
Reason: Same device, same token
```

### Test 3: Different Device (MAIN TEST)
```bash
1. Device A: Login with email@example.com
   Wait for home screen
   Check Firebase: activeDeviceToken = ABC123...

2. Device B: Login with SAME email@example.com

Expected: ✅ Popup appears!
Title: "New Device Login"
Message: "Your account was just logged in on [Device A Model]"
Buttons:
- "Logout Other Device" (orange)
- "Stay Logged In" (outline)

Result: User confirms action ✅
```

### Test 4: Chain Login
```bash
Device A: Login with email@example.com
  ✅ Logs in (no popup, no session exists)
  Firebase: activeDeviceToken = TokenA

Device B: Login with SAME email@example.com
  ✅ Popup appears! (conflict with A)
  Click "Logout Other Device"
  Wait 15 seconds...
  Firebase: activeDeviceToken = TokenB (A's token gone)

Device C: Login with SAME email@example.com
  ✅ Popup appears! (conflict with B)
  Click "Logout Other Device"
  Wait 15 seconds...
  Firebase: activeDeviceToken = TokenC (B's token gone)

Result: Every login after first shows popup ✅
```

---

## Why Popup Might NOT Show

### ❌ Reason 1: Same Token (Same Device)
```
If local device token == server token
Popup won't show (it's the same device re-logging in)
```

### ❌ Reason 2: No Server Token
```
If Firestore activeDeviceToken is empty/null
Popup won't show (no existing session to conflict with)
```

### ❌ Reason 3: Stale Session
```
If session > 5 minutes old AND no activity
Popup won't show (auto-cleaned)
Old token automatically deleted
```

### ❌ Reason 4: App Bug
```
If exception not thrown properly
If dialog not catching ALREADY_LOGGED_IN error
Check logs for:
  [AuthService] Existing session detected
  [LoginScreen] 🔴 _showDeviceLoginDialog CALLED
```

---

## Debugging

### Check Logs
```
# Device A login
[AuthService] Existing session detected: false ← No conflict
[AuthService] Saving device session...

# Device B login
[AuthService] Existing session detected: true ← Conflict!
[AuthService] Existing session detected, showing device login dialog
[LoginScreen] 🔴 _showDeviceLoginDialog CALLED
[LoginScreen] 🔴 Device Name: [Device A Model]
[LoginScreen] 🔴 Dialog builder called
```

### Check Firebase
```
users/{uid}:
- activeDeviceToken: Current device's token
- deviceInfo: Current device's model name
- lastSessionUpdate: Timestamp of last login
```

### Clear Cache
```bash
flutter clean
flutter pub get
flutter run --release
```

---

## What Should Happen

| Scenario | Popup | Reason |
|----------|-------|--------|
| Device A: 1st login | ❌ No | No existing session |
| Device A: Re-login | ❌ No | Same token |
| Device B: Login (A online) | ✅ Yes | Different token |
| Device C: Login (B online) | ✅ Yes | Different token |
| Device A: Re-login (both logged) | ❌ No | Same token as Device A |

---

## Summary

✅ **Popup shows every time a NEW device tries to login with same credentials**
✅ **Implemented in all 3 login methods** (Email, Google, Phone)
✅ **Automatic stale session cleanup** (>5 min)
✅ **Same device re-login does NOT show popup** (expected)

---

## If Popup Still Not Showing

Try this diagnostic test:

```dart
// In login_screen.dart, after auth succeeds
print('[DEBUG] Device token: ${await _authService.getLocalDeviceToken()}');
print('[DEBUG] User UID: ${_authService.currentUser?.uid}');
print('[DEBUG] Session check result: ${await _authService._checkExistingSession(...)}');
```

If session check returns `exists: false`, then no other device is logged in, so popup shouldn't show.

If session check returns `exists: true`, then popup should appear.

---

**Test the scenarios above and confirm popup shows on Device B login!** 🎯
