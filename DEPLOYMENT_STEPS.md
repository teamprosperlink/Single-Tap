# Deployment Steps - Cloud Functions & Firestore Rules

**Status**: Ready to deploy
**Time**: ~5-10 minutes
**Required**: Firebase authentication

---

## Quick Start (Easiest Way)

### On Windows:

1. **Open Command Prompt** in project folder
2. **Double-click** `DEPLOY.bat`
3. **Login** when prompted (browser window opens)
4. **Wait** for deployment to complete
5. **Follow** the test instructions at the end

### On Mac/Linux:

```bash
chmod +x DEPLOY.sh
./DEPLOY.sh
```

---

## Manual Deployment (If Script Doesn't Work)

### Step 1: Open Terminal

```bash
cd c:/Users/csp/Documents/plink-live
```

### Step 2: Login to Firebase

```bash
npx firebase login
```

This opens a browser window. Login with your Firebase account.

**What to look for**:
- Browser shows "Firebase CLI Login"
- You login with Google/email
- Browser shows "✓ Success! Logged in as ..."
- Terminal shows "✓ Logged in as ..."

### Step 3: Deploy Cloud Functions

```bash
npx firebase deploy --only functions
```

**What to expect**:
```
=== Deploying to 'suuper2'...

i  deploying functions
i  functions: clearing previous imports for functions
i  functions: importing functions from lib/
i  functions: importing functions from lib/index.js
✔  functions[forceLogoutOtherDevices]: Successful
✔  functions[checkExistingSession]: Successful
[... other functions ...]

✔  Deploy complete!
```

**Time**: 1-2 minutes

**If successful**: ✅ Cloud Functions deployed
**If failed**: Check error message and troubleshoot below

### Step 4: Deploy Firestore Rules

```bash
npx firebase deploy --only firestore:rules
```

**What to expect**:
```
=== Deploying to 'suuper2'...

i  firestore: checking firestore.rules for compilation errors
✔  firestore: rules updated successfully

✔  Deploy complete!
```

**Time**: 30 seconds

**If successful**: ✅ Firestore Rules deployed
**If failed**: Check error message and troubleshoot below

---

## Verify Deployment

### Check Functions Deployed

```bash
npx firebase functions:list
```

Look for `forceLogoutOtherDevices` in the list:
```
✓ forceLogoutOtherDevices - https://...
```

### Check Rules Deployed

Go to Firebase Console:
1. Open https://console.firebase.google.com
2. Select project `suuper2`
3. Go to Firestore → Rules
4. Check that rules are from `firestore.rules` (should have device logout fields)

---

## Testing After Deployment

### Setup Two Emulators

**Terminal 1 (Device A)**:
```bash
flutter run -d emulator-5554
```

Login:
- Email: `test@example.com`
- Password: `password123`

Wait 30 seconds for app to fully load.

**Terminal 2 (Device B)** - After 30 seconds:
```bash
flutter run -d emulator-5556
```

Login:
- Email: `test@example.com` (SAME as Device A)
- Password: `password123`

### Watch What Happens

**Device B** (New device):
- Shows loading spinner
- NO dialog should appear
- After 2-3 seconds: Navigates to main app
- Ready to use ✓

**Device A** (Old device):
- Was using app normally
- Gets logout signal from Firestore
- Shows login screen
- Message: "You've been logged out from another device"
- Logged out ✓

### Check Logs

**Device B should show**:
```
[LoginScreen] Starting automatic logout of other device...
[LoginScreen] Waiting 2.5 seconds for listener to initialize...
[LoginScreen] Listener initialized, now logging out other device...
[AuthService] Calling Cloud Function: forceLogoutOtherDevices
[AuthService] ✓ Successfully forced logout on other devices - instant like WhatsApp!
[LoginScreen] ✓ Other device logout command sent
[LoginScreen] ✓ Navigating Device B to main app...
```

**Device A should show** (after ~10 seconds):
```
[DeviceSession] ✅ PROTECTION PHASE COMPLETE - NOW checking logout signals
[DeviceSession] 📋 forceLogout value: true (type: bool)
[DeviceSession] 📋 forceLogout parsed: true
[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
[RemoteLogout] ========== REMOTE LOGOUT INITIATED ==========
[RemoteLogout] 🔴 Calling signOut()...
[RemoteLogout] ✓ Firebase sign out completed
```

### Success Criteria ✅

- [ ] Device B shows loading spinner (no dialog)
- [ ] Device B navigates to main app
- [ ] Device A receives logout signal (check logs)
- [ ] Device A shows login screen
- [ ] Device A shows "logged out" message
- [ ] Only Device B is logged in
- [ ] No errors in logs

---

## Troubleshooting

### Error: "Failed to authenticate"

```
Solution:
  npx firebase logout
  npx firebase login
```

Then try deployment again.

### Error: "Permission denied" or "Error: PERMISSION_DENIED"

This usually means your Firebase account doesn't have permission to deploy to this project.

```
Solution:
  1. Check you have "Editor" or "Owner" role in Firebase project
  2. Go to: https://console.firebase.google.com/project/suuper2/settings/iam
  3. Ask project owner to add you as Editor
```

### Error: "Rules contain syntax errors"

This means `firestore.rules` has a syntax error.

```
Solution:
  1. Check the error message for line number
  2. Open: firestore.rules
  3. Fix the syntax error
  4. Run deployment again
```

Current rules file is clean, so this shouldn't happen unless you edited it.

### Cloud Function Fails After Deployment

Check the error in Firebase Console:
1. Open https://console.firebase.google.com
2. Select project `suuper2`
3. Go to Functions → Logs
4. Look for errors in `forceLogoutOtherDevices`

Common issues:
- Function code has syntax error (unlikely - already tested)
- Missing dependencies (check functions/package.json)
- Timeout (increase timeout in functions/index.js)

### Device A Still Doesn't Logout

If deployment successful but Device A still not logging out:

1. **Check Device B logs** for:
   ```
   [AuthService] Calling Cloud Function: forceLogoutOtherDevices
   [AuthService] ✓ Successfully forced logout
   ```
   If you see "Cloud Function error" → Function not deployed correctly

2. **Check Device A logs** for:
   ```
   [DeviceSession] 📋 forceLogout value: true
   [DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
   ```
   If you don't see this → Listener not detecting signal

3. **Check Firestore** in Firebase Console:
   - Go to Firestore → Data
   - Check `users/{userId}` document
   - Should have `forceLogout: true` field after Device B logs in

4. **Wait longer**:
   - Protection window is 10 seconds
   - Device A won't logout for first 10 seconds
   - Wait until 10+ seconds have passed since Device A logged in

---

## Files Created

- `DEPLOY.bat` - Windows deployment script
- `DEPLOY.sh` - Mac/Linux deployment script
- `DEPLOYMENT_SCRIPT.sh` - Alternative bash script
- `DEPLOYMENT_STEPS.md` - This file (detailed steps)

Use whichever is easiest for your system.

---

## Summary

| Step | Time | Command |
|------|------|---------|
| 1. Login | 1-2 min | `npx firebase login` |
| 2. Deploy Functions | 1-2 min | `npx firebase deploy --only functions` |
| 3. Deploy Rules | 30 sec | `npx firebase deploy --only firestore:rules` |
| 4. Test | 5 min | Run two emulators and test |
| **Total** | **~10 min** | |

---

## Next Steps

1. **Deploy now**:
   - Windows: Double-click `DEPLOY.bat`
   - Mac/Linux: Run `./DEPLOY.sh`
   - Or: Run `npx firebase login && npx firebase deploy`

2. **Wait for completion**

3. **Test with two emulators** (see "Testing After Deployment" section above)

4. **Verify** Device A logs out when Device B logs in

5. **Done!** ✓ WhatsApp-style logout feature is working

---

## Questions?

Check these files for more info:
- [DIAGNOSIS_DEVICE_A_LOGOUT_ISSUE.md](DIAGNOSIS_DEVICE_A_LOGOUT_ISSUE.md) - Why it wasn't working
- [DEPLOY_CLOUD_FUNCTIONS.md](DEPLOY_CLOUD_FUNCTIONS.md) - Detailed technical info
- [QUICK_FIX_DEVICE_LOGOUT.txt](QUICK_FIX_DEVICE_LOGOUT.txt) - Quick reference

Good luck! 🚀
