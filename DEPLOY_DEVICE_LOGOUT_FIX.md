# Deploy Device Logout Fix

## Overview
This fix ensures that when a new device logs in, the old device is properly logged out - even if it's offline.

## Changes to Deploy

### 1. Flutter App Update
**File:** `lib/services/auth_service.dart`
- Auto-cleanup for stale sessions (>5 minutes)
- Immediate token deletion in `logoutFromOtherDevices()`

### 2. Cloud Function Update
**File:** `functions/index.js`
- Add STEP 0 to delete old device token
- Provides backup deletion for reliability

---

## Deployment Steps

### Step 1: Update Flutter App

**a) Update `lib/services/auth_service.dart`**

In `_checkExistingSession()` method (around line 961):
- ✅ Already updated with auto-cleanup logic
- ✅ Detects stale sessions >5 minutes
- ✅ Auto-deletes old tokens

In `logoutFromOtherDevices()` method (around line 1102):
- ✅ Already updated with STEP 0
- ✅ Immediately deletes old token
- ✅ Called before Cloud Function

**b) Build and Test Locally**
```bash
flutter clean
flutter pub get
flutter run
```

**c) Run Tests**
```bash
flutter test
```

**d) Build for Release**
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

### Step 2: Update Cloud Function

**a) Update `functions/index.js`**

In `forceLogoutOtherDevices` Cloud Function (around line 514):
- ✅ Already updated with STEP 0
- ✅ Deletes old device token immediately
- ✅ Provides backup deletion

**b) Deploy Cloud Function**

```bash
cd functions

# Install dependencies if needed
npm install

# Deploy to Firebase
firebase deploy --only functions:forceLogoutOtherDevices
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

**c) Verify Deployment**

```bash
firebase functions:list
```

You should see:
```
forceLogoutOtherDevices  HTTP(s)  us-central1
```

---

### Step 3: Verify Changes

**a) Check Firestore Rules** (no changes needed)
```bash
firebase firestore:indexes:list
```

**b) Check Logs** (optional)
```bash
firebase functions:log
```

---

## Testing Checklist

### Test 1: Online Device Logout ✅
- [ ] Login on Device A
- [ ] Login on Device B with same account
- [ ] Click "Logout Other Device"
- [ ] Device A should logout within 500ms
- [ ] Watch logs for: "forceLogout signal detected"

### Test 2: Offline Device Logout ✅
- [ ] Login on Device A
- [ ] Force kill app on Device A
- [ ] Login on Device B
- [ ] Click "Logout Other Device"
- [ ] Wait for Device A to reconnect
- [ ] Device A should logout within 2-3 seconds
- [ ] Watch logs for: "TOKEN CLEARED ON SERVER"

### Test 3: Stale Session Auto-Cleanup ✅
- [ ] Login on Device A
- [ ] Force kill app on Device A (no graceful logout)
- [ ] Wait 6+ minutes
- [ ] Try to login on Device B
- [ ] Should NOT show device conflict dialog
- [ ] Device B should login normally
- [ ] Watch logs for: "Session age: X minutes"

### Test 4: Cloud Function Deployment ✅
- [ ] Check Firebase Console → Functions
- [ ] Verify `forceLogoutOtherDevices` is deployed
- [ ] Check logs for successful execution
- [ ] Monitor for errors in first 30 minutes

---

## Rollback Steps

If critical issues occur:

**a) Rollback Flutter App**
```bash
# Revert to previous version
git checkout HEAD~1 -- lib/services/auth_service.dart

# Rebuild and deploy
flutter clean
flutter pub get
flutter run --release
```

**b) Rollback Cloud Function**
```bash
# Check deployed versions
gcloud functions versions list

# If needed, redeploy previous version from git
firebase deploy --only functions:forceLogoutOtherDevices
```

---

## Monitoring

### Key Metrics to Monitor

1. **Login Success Rate**
   - Should remain stable
   - Watch for increases in "Already logged in" errors

2. **Device Logout Rate**
   - Should increase when multiple logins detected
   - Check logs for "forceLogout" signals

3. **Cloud Function Errors**
   - Firebase Console → Functions → Logs
   - Watch for errors in first hour after deployment

### Logs to Watch

**Flutter App:**
```
[AuthService] Old session is STALE - automatically clearing
[AuthService] STEP 0 succeeded - old device token cleared
[DeviceSession] TOKEN CLEARED ON SERVER
[DeviceSession] FORCE LOGOUT SIGNAL DETECTED
```

**Cloud Function:**
```
STEP 0: IMMEDIATELY deleting old device token
Old device token deleted for user [USER_ID]
STEP 1: Setting forceLogout=true for user [USER_ID]
Successfully forced logout on other devices
```

---

## Deployment Timeline

| Step | Time | Notes |
|------|------|-------|
| Update auth_service.dart | 5 min | Code changes |
| Build Flutter app | 10 min | Local testing |
| Test locally | 20 min | All 3 scenarios |
| Deploy app to stores | 2-24 hrs | Normal store delays |
| Update Cloud Function | 5 min | Firebase CLI |
| Test Cloud Function | 10 min | Verify deployment |
| Monitor logs | 30 min | Watch for errors |

**Total Time:** ~1 hour active work + store deployment delays

---

## Success Criteria

✅ Old device logs out when new device logs in (online)
✅ Old device logs out on reconnect (offline)
✅ No duplicate active sessions
✅ No errors in Cloud Function logs
✅ Auto-cleanup works for stale sessions
✅ Device conflict UI still shows (when needed)

---

## Common Issues & Solutions

### Issue 1: "Cloud Function not found" Error
**Solution:**
```bash
firebase deploy --only functions:forceLogoutOtherDevices --force
```

### Issue 2: "Permission denied" in Cloud Function
**Solution:**
- Verify Cloud Function has correct permissions
- Check Firestore security rules
- Ensure authenticated user calling function

### Issue 3: Device not logging out offline
**Solution:**
- Check if listener is properly initialized
- Verify token was deleted from Firestore
- Check device has network connection after reconnect

### Issue 4: Stale session not cleaning up
**Solution:**
- Verify `lastSessionUpdate` timestamp exists
- Check if >5 minute threshold is being used
- Monitor logs for auto-cleanup messages

---

## Post-Deployment

1. Monitor error logs for 2 hours
2. Test on both Android and iOS
3. Test with network interruptions
4. Verify no user complaints about unexpected logouts
5. Keep deployment guide for future reference

---

## Support

If issues occur:
1. Check logs in Firebase Console
2. Review DEVICE_LOGOUT_FIX.md for understanding
3. Review DEVICE_LOGOUT_FLOW.md for troubleshooting
4. Consider rollback if critical issues found
