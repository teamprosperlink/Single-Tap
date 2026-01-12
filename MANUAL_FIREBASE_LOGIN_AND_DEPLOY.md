# 🔐 Manual Firebase Login & Deploy (Step-by-Step)

**Issue:** Firebase CLI authentication expired
**Solution:** Re-login and deploy manually
**Time:** 10 minutes

---

## Why This is Needed

The Firestore rules must be deployed to Firebase Cloud for the app to work. The authentication token expired and needs to be refreshed.

---

## STEP 1: Logout (Clean State)

Open a Command Prompt or PowerShell on YOUR MACHINE and run:

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase logout
```

Expected output:
```
+ Logged out
```

---

## STEP 2: Login to Firebase

Run this command:

```bash
npx firebase login
```

**What happens:**
1. A browser window opens automatically
2. Google login screen appears
3. Sign in with your Google account (the one with Firebase access)
4. It asks for permissions - click "Allow"
5. Browser shows a success message
6. Terminal shows "✔ Success!"

**Write down:** The email used to login

---

## STEP 3: Verify Correct Project

Run this to see your projects:

```bash
npx firebase projects:list
```

**Look for:** `suuper2` in the list

If NOT there:
```bash
npx firebase use suuper2
```

---

## STEP 4: Deploy Firestore Rules

Run this:

```bash
npx firebase deploy --only firestore:rules
```

**Wait for:**
```
✔ firestore: rules updated successfully
```

or

```
✔ firestore: no changes
(this is also OK - means rules already deployed from before)
```

---

## STEP 5: Verify Deployment

Run this:

```bash
npx firebase deploy --only firestore:rules
```

Should show one of:
```
✔ firestore: rules updated successfully
```
OR
```
✔ firestore: no changes
```

---

## STEP 6: Rebuild & Test App

Run:

```bash
flutter clean && flutter pub get
flutter run -d emulator-5554
```

**Check logs for:**
```
✅ [DeviceSession] ✅ Starting real-time listener
✅ [DeviceSession] ✅ Local token: xxxxxxxx...
✅ No PERMISSION_DENIED errors
```

If you see this, deployment worked! ✅

---

## All Commands (Copy-Paste)

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase logout
npx firebase login
npx firebase projects:list
npx firebase use suuper2
npx firebase deploy --only firestore:rules
flutter clean && flutter pub get
flutter run -d emulator-5554
```

Run them one at a time, in order. Wait for each to complete.

---

## Troubleshooting

**"Browser didn't open"**
- Try manually: https://accounts.google.com
- Then run: `npx firebase login` again

**"Still getting 401 error"**
- You might be signed into wrong Google account
- Run: `npx firebase logout`
- Then: `npx firebase login` with correct account

**"suuper2 project not found"**
- Check: https://console.firebase.google.com
- Make sure you're signed in with correct account
- Contact project admin if you don't have access

**"Still seeing PERMISSION_DENIED in logs"**
- Rules didn't deploy properly
- Try again: `npx firebase deploy --only firestore:rules`
- Make sure you see: `✔ firestore: rules updated successfully`

---

## What This Does

1. **logout** = Clears old authentication
2. **login** = Signs in with Google (interactive browser login)
3. **projects:list** = Shows your Firebase projects
4. **use suuper2** = Selects the correct Firebase project
5. **deploy** = Uploads Firestore rules to Firebase Cloud
6. **flutter run** = Rebuilds and tests the app

---

## After Successful Deployment

Logs should show:
```
✅ [AuthService] Current token: xxxxxxxx...
✅ [AuthService] Calling Cloud Function: forceLogoutOtherDevices
✅ [AuthService] STEP 1: Writing forceLogout=true
✅ [AuthService] ✓ Fallback write succeeded
✅ [DeviceSession] ⏳ PROTECTION PHASE
✅ [DeviceSession] ✅ PROTECTION PHASE COMPLETE
```

Then test device logout:
```bash
# Terminal 1
flutter run -d emulator-5554

# Terminal 2 (wait 30 seconds)
flutter run -d emulator-5556
```

---

## Expected Results

- Device A: Logged in, main app showing
- Device B: Logs in → stays logged in (doesn't logout) ✅
- Device A: Gets logout signal, shows login page ✅
- No PERMISSION_DENIED errors ✅
- No crashes ✅

---

## DO THIS NOW

On your machine:

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase logout
npx firebase login
```

Then reply: "**Firebase login successful**" and continue with remaining steps!

---

**Each step is quick - you've got this!** 💪
