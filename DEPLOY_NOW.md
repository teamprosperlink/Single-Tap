# 🚀 DEPLOY NOW - 3 Simple Steps

**Status:** Everything is ready. Just need to deploy Firestore rules.

---

## Step 1️⃣: Deploy Firestore Rules (5 minutes)

### Quick Method (Easiest)

1. Open: https://console.firebase.google.com
2. Select your project
3. Click: **Firestore Database** (left sidebar)
4. Click: **Rules** tab (top)
5. Open file: `FIRESTORE_RULES_COPY_PASTE.md` in your project
6. Copy all the code (Ctrl+A, Ctrl+C)
7. Paste into Firebase Console (Ctrl+V)
8. Click **Publish** button
9. Wait for "Rules updated successfully" ✅

### Alternative: Firebase CLI

```bash
cd c:\Users\csp\Documents\plink-live
firebase deploy --only firestore:rules
```

---

## Step 2️⃣: Build APK (3 minutes)

```bash
cd c:\Users\csp\Documents\plink-live
flutter clean
flutter pub get
flutter build apk --release
```

**Output:** `build/app/outputs/apk/release/app-release.apk`

---

## Step 3️⃣: Install and Test (5 minutes)

### Install on 2 devices

```bash
# Device A
adb -s DEVICE_A_SERIAL install -r build/app/outputs/apk/release/app-release.apk

# Device B
adb -s DEVICE_B_SERIAL install -r build/app/outputs/apk/release/app-release.apk
```

### Test

**Device A:**
1. Open app
2. Login with email/password
3. See "Already Logged In" dialog
4. Click "Logout Other Device"

**Device B:**
1. Open app
2. See "Already Logged In" dialog
3. Wait 2-3 seconds...
4. Dialog auto-closes ✅
5. Redirected to login ✅

---

## Expected Result

```
✅ Device A: Logout successful (instant)
✅ Device B: Dialog closes automatically (2-3 seconds)
✅ Device B: Signed out (automatic)
✅ Both devices logged out
✅ Only 1 device per account
✅ WhatsApp-style behavior
```

---

## If It Doesn't Work

### Check 1: Firestore Rules Deployed?

Go to Firebase Console → Firestore → Rules

Should see:
```javascript
allow update: if isOwner(userId) ||
              (request.resource.data.diff(resource.data)
               .affectedKeys().hasOnly(['activeDeviceToken', 'deviceName']));
```

If not → Deploy rules again!

### Check 2: Logs?

**Device A logs should show:**
```
[Button] ✅ Token deleted from Firestore
```

If you see:
```
[Button] ❌ Error: Permission denied
```

→ Rules not deployed! Go back to Step 1.

### Check 3: Device B logs?

**Should see:**
```
[Dialog] 🔍 Token status: NULL ❌
[Dialog] ✅ TOKEN DELETED DETECTED!
```

If not → Timer not working (check uid)

---

## Time Estimate

- Firestore rules: **5 minutes**
- Build APK: **3 minutes**
- Install + Test: **5 minutes**

**Total: ~13 minutes**

---

## You're All Set! 🎉

Everything is committed and ready. Just deploy and test!

