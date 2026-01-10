# Quick Debug Commands - Copy & Paste

## Terminal 1: Clear and Start Monitoring All Logs

```bash
adb logcat -c
adb logcat | grep -E "\[RegisterDevice\]|\[RemoteLogout\]|\[Poll\]|\[DirectDetection\]|\[ForceLogout\]|\[Logout\]"
```

## Terminal 2: Run Test Steps

### Step 1: Login on Device A
```bash
# Open app on Device A
# Enter email/password
# Wait for login
# COPY ALL [RegisterDevice] LOGS from Terminal 1
```

### Step 2: Check Firestore
```bash
# Go to Firebase Console
# Firestore → users → [your-user-id]
# Is activeDeviceToken field present with a value?
# YES or NO?
```

### Step 3: Logout Other Device on Device B
```bash
# Open app on Device B
# Click "Already Logged In" button
# Click "Logout Other Device"
# COPY ALL [RemoteLogout] LOGS from Terminal 1
```

### Step 4: Check Device A
```bash
# Wait 3 seconds
# Watch Device A screen
# Do you see red notification? YES or NO?
# Does it go to login screen? YES or NO?
# COPY ALL [Poll], [ForceLogout] LOGS from Terminal 1
```

---

## What to Share Back

After running above, send me:

1. **Answer these questions:**
   - [ ] Did you see [RegisterDevice] logs? YES / NO
   - [ ] Is activeDeviceToken in Firestore? YES / NO
   - [ ] Did you see [RemoteLogout] logs? YES / NO
   - [ ] Is activeDeviceToken now empty? YES / NO
   - [ ] Did you see [Poll] *** LOGOUT DETECTED ***? YES / NO
   - [ ] Did you see [ForceLogout] ... Current user is now: NULL? YES / NO
   - [ ] Did Device A show red notification? YES / NO
   - [ ] Did Device A go to login screen? YES / NO

2. **Copy-paste the FIRST step that failed:**
   - If [RegisterDevice] missing → Share what you DO see in logs
   - If activeDeviceToken missing → Share Firebase error
   - If [RemoteLogout] missing → Share Device B logs
   - If [Poll] doesn't show LOGOUT → Share [Poll] logs
   - If [ForceLogout] missing → Share what you see
   - If no notification → Share Device A logs
   - If still logged in → Share [BUILD] logs

3. **Run this network test:**
   ```bash
   adb shell ping -c 5 google.com
   ```
   Share the output (should show latency)

---

## One Command - Get Everything

Copy and paste this entire block into Terminal:

```bash
echo "=== CLEARING LOGS ===" && \
adb logcat -c && \
echo "=== MONITORING (Step 1: Login on Device A, then press Ctrl+C after login) ===" && \
adb logcat | grep -E "\[RegisterDevice\]|\[RemoteLogout\]|\[Poll\]|\[DirectDetection\]|\[ForceLogout\]"
```

Then run separately:

```bash
echo "=== STEP 2: Logout on Device B, then wait 3 seconds ===" && \
adb logcat | grep -E "\[RemoteLogout\]|\[Poll\]|\[ForceLogout\]"
```

---

## Firebase Console Check

1. Go to: https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database"
4. Click "users" collection
5. Click your user document
6. Look for "activeDeviceToken" field
7. Copy the value or say "EMPTY" / "NOT PRESENT"

---

## Email me These 3 Things:

1. Answers to 8 YES/NO questions above
2. Copy of the logs from the FIRST failing step
3. Output of the `ping google.com` command

Then I'll know EXACTLY what's wrong and can fix it!
