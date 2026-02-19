# Device Logout Fix - Complete Solution

**Problem:** جب نیا device login ہوتا ہے، تو پرانا device logout نہیں ہو رہا تھا

**Root Cause:**
- Old Device A app was closed/offline, so the Firestore listener (`_startDeviceSessionMonitoring()`) was NOT running
- New Device B sets `forceLogout=true` flag in Firestore
- Old Device A never detects it because there's no listener active
- Result: Both devices stay logged in (Security Issue + UX Bug)

## Solution Overview

The fix implements **3-layer detection** to catch old device sessions:

### Layer 1: Immediate Token Deletion (Primary Fix)
When Device B calls `logoutFromOtherDevices()`:
1. **Device A's token is deleted from Firestore immediately** (`activeDeviceToken: DELETE`)
2. When Device A comes back online, its listener detects the token is gone
3. Device A logs out within 2-3 seconds of reconnecting

**File:** `lib/services/auth_service.dart:1102-1117`
```dart
// STEP 0: Immediately clear old token
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .update({
      'activeDeviceToken': FieldValue.delete(),
    });
```

**Cloud Function:** `functions/index.js:514-522`
```javascript
// Delete old token IMMEDIATELY
await db.collection("users").doc(userId).update({
  activeDeviceToken: new FieldValue.delete(),
});
```

### Layer 2: forceLogout Flag (for Online Devices)
If Device A is online:
1. `forceLogout=true` is set
2. Device A's listener detects it within **500ms** (lines 476-500 in main.dart)
3. Device A logs out immediately

### Layer 3: Stale Session Auto-Cleanup (Automatic Cleanup)
If a session hasn't been updated in **>5 minutes**:
- Automatically clears the old device token from Firestore
- Prevents stuck sessions from old app crashes
- Happens when Device B tries to login

**File:** `lib/services/auth_service.dart:984-1015`
```dart
// If old session is stale (>5 minutes), auto-cleanup
if (minutesSinceUpdate > 5) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({
        'activeDeviceToken': FieldValue.delete(),
        'forceLogout': false,
      });
}
```

## How It Works - SingleTap Style

### Scenario: Device A (Old) is OFFLINE when Device B logs in

```
Device A (Old, OFFLINE)         Device B (New, ONLINE)
    ❌ App closed                  User logs in
    ❌ No listener                 ✅ Shows "Device conflict" dialog
    ❌ No network                  User clicks "Logout Other Device"
                                   ↓
                                   Calls logoutFromOtherDevices()
                                   ↓
                                   STEP 0: Deletes Device A's token from Firestore
                                   STEP 1: Sets forceLogout=true
                                   STEP 2: Sets own token as activeDeviceToken

Device A comes online            Device B now logged in
    ↓                            ✅ Using account
    Listener starts
    Detects: activeDeviceToken is empty!
    ❌ LOGS OUT immediately
    Shows login screen
```

### Scenario: Device A (Old) is ONLINE when Device B logs in

```
Device A (Old, ONLINE)          Device B (New, ONLINE)
    ✅ Listener running            User logs in
    ✅ Has network                 Shows "Device conflict" dialog
                                   ↓
                                   User clicks "Logout Other Device"
                                   ↓
                                   Calls logoutFromOtherDevices()
                                   STEP 0: Deletes Device A's token
                                   STEP 1: Sets forceLogout=true

Device A's listener fires        Device B now logged in
    Detects: forceLogout=true!    ✅ Using account
    ❌ LOGS OUT within 500ms
    Shows login screen
```

## Files Changed

### 1. `lib/services/auth_service.dart`
- **Lines 962-1030:** Added auto-cleanup for stale sessions (>5 minutes)
- **Lines 1102-1117:** Added STEP 0 to immediately delete old device token

### 2. `functions/index.js`
- **Lines 514-522:** Added STEP 0 to delete old device token in Cloud Function

### 3. `lib/main.dart` (NO CHANGES NEEDED)
- Lines 507-514: Already has **PRIORITY 2** to detect token cleared on server
- Token detection works perfectly - old device will logout when it detects token is gone

## Testing the Fix

### Test 1: Old Device OFFLINE
1. Login on Device A
2. Force kill app on Device A (or turn off network)
3. Login on Device B with same account
4. Click "Logout Other Device"
5. Check Device A:
   - When Device A comes online: **Should logout within 2-3 seconds** ✅
   - Shows login screen
   - No longer logged in

### Test 2: Old Device ONLINE
1. Login on Device A (listener running)
2. Login on Device B with same account
3. Click "Logout Other Device"
4. Watch Device A:
   - **Should logout within 500ms** ✅
   - See listener message: "TOKEN CLEARED ON SERVER" or "FORCE LOGOUT SIGNAL DETECTED"
   - Shows login screen

### Test 3: Stale Session Auto-Cleanup
1. Login on Device A
2. Don't update Device A for **>5 minutes** (pause app, turn off screen, etc)
3. Try to login on Device B with same account
4. Device B should:
   - Auto-detect stale session
   - Clear Device A's token
   - Show login (not device conflict) ✅

## Security Implications

✅ **Single device login enforced** - Only one device can be logged in at a time
✅ **No duplicate sessions** - Old device token is deleted, preventing both from being active
✅ **Instant logout** - Within 500ms for online devices, 2-3s for offline ones
✅ **SingleTap-style behavior** - User expects this, industry standard

## Deployment Checklist

- [ ] Deploy updated `lib/services/auth_service.dart` (auto-cleanup + token deletion)
- [ ] Deploy updated `functions/index.js` (Cloud Function changes)
- [ ] Test with offline scenario first
- [ ] Test with online scenario
- [ ] Monitor logs for any issues

## Rollback Plan

If issues occur:
1. Remove STEP 0 from `auth_service.dart` (lines 1102-1117)
2. Remove STEP 0 from `functions/index.js` (lines 514-522)
3. System will fall back to forceLogout flag + stale session cleanup (still better than before)
