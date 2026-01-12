# Deploy Cloud Functions & Firestore Rules

**Status**: 🔴 **REQUIRED FOR LOGOUT TO WORK**
**Date**: January 12, 2026
**Issue**: Device A is not logging out because Cloud Function is not deployed

---

## Why Deployment is Needed

The automatic logout feature depends on two things:

1. **Cloud Function `forceLogoutOtherDevices`** (Admin privileges)
   - Runs with admin rights, bypassing Firestore security rules
   - Instantly writes logout signals to Firestore
   - Handles race conditions and atomic operations

2. **Firestore Security Rules**
   - Control which devices can update logout-related fields
   - Allow authenticated users to update device fields
   - Protect against unauthorized access

**Current Status**:
- ❓ Cloud Function: UNKNOWN (probably not deployed)
- ❓ Firestore Rules: UNKNOWN (probably not deployed)

**Result**: Without these, the logout signal is blocked or not sent, so Device A never logs out.

---

## Quick Diagnosis

When Device B logs in and calls `logoutFromOtherDevices()`:

```
1. Tries to call Cloud Function 'forceLogoutOtherDevices'
2. If Cloud Function fails or doesn't exist → Falls back to direct Firestore write
3. Firestore write writes: forceLogout=true, activeDeviceToken update
4. Check: Are Firestore rules deployed? If not → PERMISSION_DENIED error
5. Catch error silently and continue
6. Result: forceLogout never set to true → Device A never logs out
```

---

## Deployment Steps

### Step 1: Authenticate with Firebase

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase login
```

This will open a browser window to authenticate.

---

### Step 2: Deploy Cloud Functions

```bash
npx firebase deploy --only functions
```

**Expected Output**:
```
=== Deploying to 'plink-live'...

i  deploying functions
i  functions: clearing previous imports for functions
i  functions: importing functions from lib/
i  functions: importing functions from lib/index.js
✔  functions[forceLogoutOtherDevices]: Successful
✔  functions[checkExistingSession]: Successful
... (other functions)

✔  Deploy complete!
```

**What This Does**:
- Deploys `forceLogoutOtherDevices` function to Firebase
- Function now has admin privileges (can bypass Firestore rules)
- Logout signals will now be instantly set in Firestore

---

### Step 3: Deploy Firestore Security Rules

```bash
npx firebase deploy --only firestore:rules
```

**Expected Output**:
```
=== Deploying to 'plink-live'...

i  firestore: checking firestore.rules for compilation errors
✔  firestore: rules updated successfully

✔  Deploy complete!
```

**What This Does**:
- Deploys the security rules from `firestore.rules` file
- Allows authenticated users to update device-related fields
- Protects against unauthorized access to sensitive data

---

### Step 4: Verify Deployment

Check that both are deployed:

```bash
npx firebase functions:list
npx firebase firestore:indexes
```

---

## Complete Deployment (All-in-One)

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase login
npx firebase deploy
```

This deploys everything (functions, rules, storage, etc.)

---

## Troubleshooting Deployment

### Error: "Failed to authenticate"
```
Solution:
  npx firebase logout
  npx firebase login
```

### Error: "Permission denied"
```
Solution:
  - Check you have editor access to the Firebase project
  - Use: npx firebase projects:list
  - Make sure you're in the right project
```

### Error: "Rules contain syntax errors"
```
Solution:
  - This means firestore.rules has an error
  - Fix the file and redeploy
  - Current rules are at: c:/Users/csp/Documents/plink-live/firestore.rules
```

### Cloud Function fails after deployment
```
Solution:
  1. Check function logs in Firebase Console
  2. Function must be deployed before it can be called
  3. Wait 2-3 minutes after deployment for changes to propagate
```

---

## Verifying Logout Works After Deployment

### Test 1: Check Cloud Function is Called

**Device B logs should show**:
```
[AuthService] Calling Cloud Function: forceLogoutOtherDevices
[AuthService] ✓ Successfully forced logout on other devices - instant like WhatsApp!
```

If you see "Cloud Function error" instead, check:
1. Is Cloud Function deployed?
2. Is the app authenticated with Firebase?
3. Are you using correct Firebase project?

### Test 2: Check Firestore Rules Allow Update

**Device A logs should show**:
```
[DeviceSession] 📋 forceLogout value: true (type: bool)
[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
[RemoteLogout] 🔴 Calling signOut()...
```

If you see PERMISSION_DENIED errors:
1. Are Firestore rules deployed?
2. Check Firebase Console → Firestore → Rules
3. Rules should be from firestore.rules file

### Test 3: Full Logout Flow

```bash
# Terminal 1: Device A
flutter run -d emulator-5554
[Login with test@example.com / password123]

# Terminal 2: Device B (after 30 seconds)
flutter run -d emulator-5556
[Login with SAME account]
```

**Expected**:
- Device B: Shows loading spinner, then main app
- Device A: Shows login screen ("You've been logged out")
- Logs show forceLogout signal being sent and detected

---

## What Gets Deployed

### Cloud Functions (functions/index.js)
- `forceLogoutOtherDevices` - Main logout function (CRITICAL)
- `checkExistingSession` - Check if user logged in elsewhere
- Other helper functions

### Firestore Rules (firestore.rules)
- User collection rules
- Device logout fields (forceLogout, activeDeviceToken)
- Post collection rules
- Chat/conversation rules
- All other collections

---

## After Deployment

Once deployed:

1. **Cloud Function Behavior**:
   - Device B's `logoutFromOtherDevices()` call will use Cloud Function
   - Cloud Function instantly writes forceLogout signal
   - No fallback Firestore write needed

2. **Security Rules Behavior**:
   - Firestore allows authenticated users to update device fields
   - Blocks unauthorized updates
   - Enables instant device switching

3. **Logout Flow**:
   - Device B logs in → Cloud Function called
   - Cloud Function writes forceLogout=true
   - Device A listener detects signal after 10-second protection window
   - Device A logs out automatically ✓

---

## Testing Checklist

After deployment, verify:

- [ ] `npx firebase functions:list` shows `forceLogoutOtherDevices`
- [ ] Firebase Console shows Cloud Functions deployed
- [ ] Firebase Console shows latest Firestore Rules
- [ ] Device A and Device B login with same account
- [ ] Device A receives logout signal (check logs)
- [ ] Device A shows login screen
- [ ] No PERMISSION_DENIED errors in console
- [ ] No Cloud Function errors in logs

---

## Git Info

**Files Modified**: None (deploying existing code)
**Cloud Function File**: `functions/index.js` (lines 490-562)
**Firestore Rules File**: `firestore.rules` (entire file)

---

## One-Command Deployment

```bash
cd c:/Users/csp/Documents/plink-live && npx firebase login && npx firebase deploy
```

This logs in and deploys everything in one command.

---

## Summary

**What's Missing**:
- Cloud Function `forceLogoutOtherDevices` - not deployed
- Firestore Rules - not deployed (or outdated)

**Result**:
- Device B cannot send logout signal to Device A
- Device A never logs out
- Both devices stay logged in

**Solution**:
- Deploy Cloud Functions
- Deploy Firestore Rules
- Test logout flow

**Expected Time**: ~2-3 minutes

---

## Support

If deployment fails:
1. Check error message carefully
2. Make sure you're logged in: `npx firebase login`
3. Check Firebase Console for more details
4. Review functions/index.js and firestore.rules for syntax
5. Try deploying just functions first: `npx firebase deploy --only functions`

---

**Status**: 🚀 Ready to deploy

Execute the commands above to enable the WhatsApp-style logout feature!
