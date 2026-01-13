# Fix: Google API DEVELOPER_ERROR

## Problem

You're seeing this error:
```
W/GoogleApiManager: Not showing notification since connectionResult is not user-facing:
ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null}
```

This error occurs when the **SHA-1 certificate fingerprint** of your app doesn't match the one configured in Google Cloud Console/Firebase.

---

## Root Cause

The `google-services.json` file contains OAuth client IDs configured with specific certificate hashes. When your app is signed with a DIFFERENT certificate (debug vs release, or different keystore), Google APIs reject it.

**Current Hashes in google-services.json:**
- `8b619d1dc26608ef5197001c2e8790fa114e0d15` (one hash)
- `738cb209a9f1fdf76dd7867865f3ff8b5867f890` (different hash)

**Your App's Signing Hash:** (currently unknown - needs to be checked)

If they don't match → DEVELOPER_ERROR

---

## Solution: Update Certificate Hash

### Step 1: Get Your Current App's SHA-1 Hash

**For Debug/Development:**
```bash
# Windows
cd c:\Users\csp\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android | findstr "SHA1"

# Alternative (all platforms)
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**For Release:**
```bash
# Windows - if you have a release keystore
cd c:\path\to\your\keystore
keytool -list -v -keystore release.keystore -alias key -storepass password -keypass password | findstr "SHA1"
```

Copy the **SHA-1** hash (looks like: `AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01`)

**Remove the colons:**
`ABCDEF0123456789ABCDEF0123456789ABCDEF01`

### Step 2: Update Google Cloud Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **suuper2**
3. Go to **Project Settings** (gear icon)
4. Click **Service Accounts** tab
5. Download new `google-services.json` file with your certificate hash

**OR manually update:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **suuper2**
3. Go to **APIs & Services** → **Credentials**
4. Find your OAuth 2.0 Client ID (Android)
5. Click edit
6. Add your SHA-1 certificate fingerprint
7. Save

### Step 3: Replace google-services.json

**Easy Option: Download from Firebase Console**
1. Firebase Console → Project Settings → Download `google-services.json`
2. Replace: `android/app/google-services.json`
3. Clean and rebuild: `flutter clean && flutter pub get`

**Manual Option: Edit the file**
```json
{
  "client": [
    {
      "oauth_client": [
        {
          "client_id": "...",
          "client_type": 1,
          "android_info": {
            "package_name": "com.plink.supper",
            "certificate_hash": "YOUR_SHA1_HERE"  // Add your SHA-1 hash
          }
        }
      ]
    }
  ]
}
```

### Step 4: Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

---

## Quick Diagnosis: Check Current Hash

Run this to see your app's current signing hash:

```bash
# Get debug keystore hash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

**Expected output:**
```
SHA1: AB:CD:EF:01:23:45:67:89:...
```

Remove colons to get: `ABCDEF01234567...`

---

## Detailed Steps (Windows)

### Find Debug Keystore Hash

**Step 1: Open Command Prompt as Administrator**

**Step 2: Navigate to Android directory**
```bash
cd C:\Users\%USERNAME%\.android
```

**Step 3: Get SHA-1 hash**
```bash
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Step 4: Copy the SHA1 line**
```
SHA1: 8B:61:9D:1D:C2:66:08:EF:51:97:00:1C:2E:87:90:FA:11:4E:0D:15
```

**Step 5: Remove colons**
```
8B619D1DC26608EF5197001C2E8790FA114E0D15
```

### Update Firebase Console

**Step 1: Go to Firebase Console**
- https://console.firebase.google.com/

**Step 2: Select "suuper2" project**

**Step 3: Click Settings (⚙️) → Project Settings**

**Step 4: Scroll to "Your apps" section**

**Step 5: Find "Android" app**
- Package name: `com.plink.supper`

**Step 6: Add your SHA-1 hash**
- If field exists, update it
- If field missing, click "Add fingerprint"
- Paste your SHA-1 hash

**Step 7: Download google-services.json**
- Click "Download google-services.json"
- Replace file at: `android/app/google-services.json`

### Rebuild App

```bash
cd c:\Users\csp\Documents\plink-live
flutter clean
flutter pub get
flutter run
```

---

## What If You Don't Have a Release Keystore?

If you're building a release APK but don't have the signing keystore, create one:

```bash
# Create a new release keystore
keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias key

# Check the SHA-1
keytool -list -v -keystore release.keystore -alias key
```

Then update `android/app/build.gradle`:
```gradle
signingConfigs {
    release {
        keyAlias 'key'
        keyPassword 'your_password'
        storeFile file('path/to/release.keystore')
        storePassword 'your_password'
    }
}
```

---

## Testing After Fix

### Build and test:
```bash
flutter clean
flutter pub get
flutter run
```

### Watch for this message (GOOD):
```
✓ App started successfully
✓ Google Sign-In ready
✓ Firebase authentication ready
```

### Watch for this error (BAD):
```
✗ ConnectionResult{statusCode=DEVELOPER_ERROR...
```

If you still see DEVELOPER_ERROR:
1. Verify you copied SHA-1 correctly (no spaces or colons)
2. Check that SHA-1 is added to Firebase Console (not just google-services.json)
3. Wait 5-10 minutes for changes to propagate
4. Try `flutter clean` again

---

## Alternative: Disable Specific Google APIs Temporarily

If the issue is blocking your testing, you can temporarily disable Google Sign-In:

**In lib/services/auth_service.dart:**
```dart
Future<UserCredential?> signInWithGoogle() async {
  try {
    print('[AuthService] Skipping Google Sign-In (debugging)');
    return null; // Temporarily return null to skip Google auth

    // Comment out the real code temporarily:
    /*
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    ...rest of code...
    */
  } catch (e) {
    print('[AuthService] Google Sign-In error: $e');
    return null;
  }
}
```

But this is NOT a permanent solution - you need to fix the certificate hash.

---

## Detailed Check: Google Cloud Console

### Verify in Google Cloud:

1. Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Select project: **suuper2**
3. Left menu → **APIs & Services** → **Credentials**
4. Find **OAuth 2.0 Client IDs** (type: Android)
5. Click the client ID
6. Under **Authorized JavaScript origins**, you should see:
   - Package name: `com.plink.supper`
   - SHA-1 fingerprints: (list of your registered hashes)
7. If your app's SHA-1 is NOT in the list → That's the problem!
8. Click **+ Add Fingerprint**
9. Paste your app's SHA-1
10. **Save**

---

## Prevention: Keep Keystore Safe

Once you fix this, **keep your release keystore safe**:
- Don't commit to Git
- Store in secure location
- Backup separately
- Never share the password

Add to `.gitignore`:
```
*.keystore
android/app/release-keystore.properties
```

---

## Summary

**The Error**: Google API Manager rejects app because certificate hash doesn't match
**The Fix**:
1. Get your app's SHA-1 certificate hash
2. Add it to Firebase Console
3. Download updated google-services.json
4. Replace file and rebuild

**Time to Fix**: 5-10 minutes

**After Fix**: No more DEVELOPER_ERROR, Google Sign-In works

---

## Support

If you're stuck:

1. **Verify SHA-1 format**: Should be 40 characters, all uppercase, no colons
2. **Wait for propagation**: Firebase Console changes take 5-10 minutes
3. **Clear cache**: `flutter clean` before rebuilding
4. **Check package name**: Must match `com.plink.supper` exactly
5. **Rebuild app**: App must be signed with the certificate you registered

---

## Files to Update

- ✅ `android/app/google-services.json` (download from Firebase)
- ✅ `android/app/build.gradle` (if creating new release keystore)
- ✅ Firebase Console (add SHA-1 fingerprint)
- ✅ Google Cloud Console (verify OAuth client configuration)

---

**Status**: Ready to implement fix
**Difficulty**: Easy (5 minutes)
**Risk**: None (no breaking changes)
