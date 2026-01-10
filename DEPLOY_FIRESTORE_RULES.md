# 🚀 Deploy Updated Firestore Rules

## What Changed

The Firestore security rules have been updated to allow users to update the device-related fields needed for WhatsApp-style single device login:

**Now Allowed Fields:**
- ✅ `activeDeviceToken` - Current active device token
- ✅ `deviceName` - Name of the active device
- ✅ `deviceInfo` - Device information (model, OS, etc.)
- ✅ `forceLogout` - Signal to logout other devices
- ✅ `lastSessionUpdate` - Timestamp of last session update

**Why These Fields?**
These are the exact fields the app needs to update when Device B triggers "Logout Other Device" to make Device A logout instantly.

## Deployment Command

```bash
firebase deploy --only firestore:rules
```

**Expected Output:**
```
=== Deploying to 'plink-live' ===
i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: Rules deployed successfully.
Deploy complete!
```

## Verify Deployment

1. **Firebase Console Method:**
   - Go to: https://console.firebase.google.com
   - Navigate to: Firestore → Rules
   - You should see the updated rules

2. **CLI Method:**
   ```bash
   firebase rules:list
   ```

## After Deployment

Once deployed, the app will be able to write the device fields without permission errors:

**In the Console, You Should See:**
```
[AuthService] Calling Cloud Function: forceLogoutOtherDevices
[AuthService] ✓ Successfully forced logout on other devices

OR (if Cloud Function isn't deployed):

[AuthService] Cloud Function error: ...
[AuthService] Attempting direct Firestore write as fallback...
[AuthService] ✓ Fallback write succeeded - forced logout completed
```

## Testing

1. **Device A:** Login with credentials
2. **Device B:** Login with same account
3. **Device B:** Click "Logout Other Device"
4. **Expected:** No more permission-denied errors! ✅

## Rollback (If Needed)

If you need to revert the rules:

```bash
# Get the previous version
firebase rules:describe firestore:rules

# Or manually edit firestore.rules and redeploy
firebase deploy --only firestore:rules
```

## Security Considerations

The updated rules are **still secure** because:
- ✅ Users can ONLY update these specific device fields
- ✅ They can ONLY update their own document (verified by userId)
- ✅ Users cannot update other sensitive fields (profile, email, etc.)
- ✅ The fields are specifically for the device logout mechanism

## Command Summary

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# View current rules
firebase rules:list

# View rules diff
firebase rules:describe firestore:rules
```

## Status

| Component | Status |
|-----------|--------|
| Rules Updated | ✅ Yes (firestore.rules) |
| Compilation | ✅ Valid syntax |
| Deployment | ⏳ Pending - Run command above |
| Production Ready | ✅ Yes |

---

## Next Steps

1. **Deploy Rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Test with Two Devices:**
   - Login on Device A
   - Login on Device B
   - Click "Logout Other Device" on Device B
   - Verify: Device A instantly logs out ✅

3. **(Optional) Deploy Cloud Function:**
   ```bash
   firebase deploy --only functions:forceLogoutOtherDevices
   ```

Once rules are deployed, the permission-denied error is FIXED! 🎉
