# URGENT: Deploy Firestore Rules Now ⚠️

**Status:** Logout system will NOT work until Firestore rules are updated!

---

## Quick Steps

### Option 1: Firebase Console (Easiest)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Replace all content with this:

**Copy the updated firestore.rules file from the project:**
```bash
# Windows
type firestore.rules
# Copy entire content
```

5. Paste into Firebase Console
6. Click **Publish** button
7. Wait for "Rules updated successfully"

### Option 2: Firebase CLI

```bash
# Make sure you're in project directory
cd c:\Users\csp\Documents\plink-live

# Deploy rules only
firebase deploy --only firestore:rules

# Or deploy everything
firebase deploy
```

---

## What Changed

**One line in security rules (lines 46-50):**

**OLD:**
```javascript
allow update: if isOwner(userId);
```

**NEW:**
```javascript
allow update: if isOwner(userId) ||
              // Allow updating activeDeviceToken and deviceName (for logout mechanism)
              (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['activeDeviceToken', 'deviceName']));
```

---

## Verify Deploy

After publishing, test with:

1. **Device A:** Open app → Try to login
2. **See "Already Logged In" dialog**
3. **Click "Logout Other Device" button**
4. **Check logs:**

**Should see:**
```
[Button] ✅ Token deleted from Firestore
```

**If you see an error:**
```
[Button] ❌ Error: Permission denied
```

Then Firestore rules were NOT deployed!

---

## Why This is Critical

Without this rule change:
- Device A tries to delete token
- Firestore rejects the update (permission denied)
- Device B never detects logout
- Logout system doesn't work

With this rule change:
- Device A deletes token successfully
- Device B detects deletion
- Device B auto-logouts ✓
- WhatsApp-style logout works ✓

---

## Next Steps

1. ✅ Deploy rules
2. Build APK
3. Test on real devices
4. Device B should logout within 2-3 seconds

**DO NOT skip the rules deployment - logout won't work without it!**

