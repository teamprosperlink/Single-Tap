# Simple Firebase Deploy (Copy & Paste)

**Goal:** Deploy Firestore rules to fix PERMISSION_DENIED errors
**Time:** 5 minutes
**Commands:** Just copy and paste below

---

## Step 1: Open Terminal

Open any terminal in your project directory:
```bash
cd c:/Users/csp/Documents/plink-live
```

---

## Step 2: Login to Firebase (First Time Only)

Copy and paste this:
```bash
npx firebase login
```

**What happens:**
- Browser window opens
- Click "Sign in"
- Select your Google account
- Click "Allow" when asked for permissions
- Close browser when done
- Terminal shows "Success"

**If browser doesn't open:**
Try this instead:
```bash
npx firebase login:ci
```

Then:
- Copy the URL from terminal
- Paste in browser
- Sign in
- Copy the token
- Paste back in terminal

---

## Step 3: Deploy Firestore Rules

Copy and paste this:
```bash
npx firebase deploy --only firestore:rules
```

**Wait for:**
```
✔ firestore: rules updated successfully
```

If you see this, it worked! ✅

---

## Step 4: Rebuild App

Copy and paste this:
```bash
flutter run -d emulator-5554
```

**Check logs for:**
```
✅ [DeviceSession] ✅ Starting real-time listener
✅ No PERMISSION_DENIED errors
```

If you see this, rules deployed successfully! ✅

---

## All Commands (Quick Reference)

```bash
cd c:/Users/csp/Documents/plink-live
npx firebase login
npx firebase deploy --only firestore:rules
flutter run -d emulator-5554
```

Just copy and paste each one, wait for it to finish, then move to next.

---

## Troubleshooting

**"firebase: command not found"**
- Make sure you're in the right directory: `cd c:/Users/csp/Documents/plink-live`
- Try: `npx firebase login` (with npx)

**"401 Unauthorized"**
- You're not logged in
- Run: `npx firebase login`

**"No Firebase project found"**
- Try: `npx firebase use suuper2`
- Then: `npx firebase deploy --only firestore:rules`

**Still getting PERMISSION_DENIED in logs**
- Rules deployed but something else is wrong
- Try rebuilding: `flutter clean && flutter pub get && flutter run`

---

## What This Does

- **firestore.rules file** = Rules for Firestore security
- **npx firebase deploy** = Uploads rules to Firebase Cloud
- **Rules allow** authenticated users to read/write
- **Without rules deployed** = PERMISSION_DENIED errors

---

## Done!

After rules deployed, your app will:
- ✅ Allow authenticated users to access Firestore
- ✅ Device session listener will start
- ✅ Device logout mechanism will work
- ✅ Device B will stay logged in
- ✅ Device A will logout properly

---

**GO TO STEP 1 AND START:**
```bash
npx firebase login
```

Reply when rules are deployed! ✅
