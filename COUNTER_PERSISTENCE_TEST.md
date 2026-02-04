# Counter Persistence Test Guide

## 🧪 Comprehensive Testing for Daily Media Limit Counter

This guide will help you verify that the daily media limit counter works correctly and **persists across app restarts**.

---

## 📋 Test Prerequisites

1. **Two test devices/emulators** (for 1-to-1 chat) OR **one device** (for group chat)
2. **Flutter app installed** on device
3. **Clear app data** before starting (to ensure clean state):
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 🎯 Test Scenario 1: Basic Counter Functionality

### Test Steps:

1. **Open 1-to-1 chat** with any user
2. **Send 1 image**
3. **Check logs** for:
   ```
   📂 ========== LOADING COUNTERS (Enhanced Chat) ==========
   📂 Loading with key: userA_userB
   📂 Raw values from SharedPreferences:
   📂   Images: 0
   ✅ COUNTERS LOADED SUCCESSFULLY

   🔍 ========== WOULD EXCEED CHECK START ==========
   🔍 MediaType: image, Trying to add: 1
   📊   - Current image count: 0
   📊   - New total would be: 1
   📊   - Would exceed limit of 4? false

   📈 INCREMENT: Image counter: 0 → 1 (+1)

   💾 ========== SAVING COUNTERS TO STORAGE ==========
   💾   Images: 1
   ✅ ========== SAVE VERIFICATION ==========
   ✅   Verified Images: 1 (expected: 1)
   ✅ ✅ ✅ COUNTERS SAVED & VERIFIED! ✅ ✅ ✅
   ```

4. **Expected Result**: ✅ Image sent successfully, counter = 1

---

## 🔄 Test Scenario 2: Counter Persistence After App Restart

### Test Steps:

1. **Send 4 images** (one by one)
2. **Check final counter** in logs:
   ```
   ✅   Verified Images: 4 (expected: 4)
   ```

3. **Try to send 5th image**
4. **Expected Result**: ❌ Error message:
   ```
   "Already aap ki daily limit khatam ho gayi hai. Aap wait kare agle din ke liye."
   ```

5. **Close app completely** (swipe away from recent apps)

6. **Reopen app**

7. **Watch logs for counter loading**:
   ```
   🚀 ========== ENHANCED CHAT SCREEN OPENED ==========
   🔄 ========== COUNTER INITIALIZATION STARTED ==========
   📂 ========== LOADING COUNTERS FROM SHAREDPREFERENCES ==========
   📂 Loading with key: userA_userB
   📂 Raw values from SharedPreferences:
   📂   Images: 4  ← SHOULD BE 4, NOT 0!
   📂   Videos: 0
   📂   Audios: 0
   ✅ COUNTERS LOADED SUCCESSFULLY:
   ✅   Images=4, Videos=0, Audios=0
   ```

8. **Try to send another image**

9. **Expected Result**: ❌ Same error message (counter persisted!)

---

## 🎥 Test Scenario 3: Video Counter

### Test Steps:

1. **Send 4 videos** (one by one)
2. **Try 5th video** → Should show error
3. **App restart**
4. **Try video again** → Should still show error

### Expected Logs:
```
📂   Images: 4
📂   Videos: 4  ← Persisted!
📈 INCREMENT: Video counter: 3 → 4 (+1)
📊   - Would exceed limit of 4? true (5 > 4)
```

---

## 🎤 Test Scenario 4: Audio Counter

### Test Steps:

1. **Record and send 4 voice messages**
2. **Try 5th voice** → Should show error
3. **App restart**
4. **Try voice again** → Should still show error

### Expected Logs:
```
📂   Audios: 4  ← Persisted!
📈 INCREMENT: Audio counter: 3 → 4 (+1)
```

---

## 🔀 Test Scenario 5: Mixed Media Types

### Test Steps:

1. **Send 2 images** → Counter: Images=2
2. **Send 3 videos** → Counter: Videos=3
3. **Send 1 audio** → Counter: Audios=1
4. **App restart**
5. **Check all counters persisted**:
   ```
   📂   Images: 2
   📂   Videos: 3
   📂   Audios: 1
   ```

6. **Send 2 more images** → Counter: Images=4
7. **Try 1 more image** → Error!
8. **Send 1 more video** → Success! (Videos=4)
9. **Try 1 more video** → Error!

---

## ⏰ Test Scenario 6: 24-Hour Reset

### Test Steps:

1. **Send 4 images** → Counter: Images=4
2. **Note current time**:
   ```
   📂   LastReset: 2026-01-27 15:30:00.000
   ```

3. **Wait 24+ hours** (or manually change device time)

4. **Open app**

5. **Expected Logs**:
   ```
   🕐 _resetDailyCountersIfNeeded called
   🕐   Hours since last reset: 24
   🔄   ⚠️ 24 hours passed - RESETTING COUNTERS
   🔄   Old values: Images=4, Videos=0, Audios=0
   🔄   ✅ Daily media counters reset to 0
   ```

6. **Try sending image** → Should work! (Counter reset to 0)

---

## 🐛 Test Scenario 7: Edge Cases

### A. User Cancels Media Selection

1. **Click image picker**
2. **Cancel without selecting**
3. **Expected**: Counter should NOT increment
4. **Logs**:
   ```
   ❌ No images selected
   (No "📈 INCREMENT" log should appear)
   ```

### B. App Crash/Force Stop

1. **Send 2 images**
2. **Force stop app** (Settings → Apps → Force Stop)
3. **Reopen app**
4. **Expected**: Counter = 2 (persisted)

### C. Multiple Chats

1. **Chat A**: Send 4 images
2. **Chat B** (different user): Send 0 images
3. **App restart**
4. **Chat A**: Counter = 4 (error on new image)
5. **Chat B**: Counter = 0 (can send 4 images)

**Each chat has separate counter!**

---

## ✅ Success Criteria

All tests pass if:

1. ✅ Counter increments correctly after media selection
2. ✅ Counter **persists** after app restart (not reset to 0)
3. ✅ Error message appears when limit reached
4. ✅ Counter saves correctly (verification logs show match)
5. ✅ Counter loads correctly (values match saved values)
6. ✅ 24-hour reset works
7. ✅ Cancel/failure doesn't increment counter
8. ✅ Different chats have independent counters

---

## 🔍 Debug Log Filtering

To see only counter-related logs:

### On Windows (PowerShell):
```powershell
flutter run | Select-String -Pattern "📂|💾|🔍|📈|✅|❌|🔄|🚀|🕐"
```

### On Mac/Linux:
```bash
flutter run | grep -E "📂|💾|🔍|📈|✅|❌|🔄|🚀|🕐"
```

### On Android Device:
```bash
adb logcat | grep -E "📂|💾|🔍|📈|✅|❌|🔄|🚀|🕐"
```

---

## 📊 Expected Log Sequence (Complete Flow)

```
🚀 ========== ENHANCED CHAT SCREEN OPENED ==========
🔄 ========== COUNTER INITIALIZATION STARTED ==========
🔄 Attempt 1: Immediate load
📂 ========== LOADING COUNTERS FROM SHAREDPREFERENCES ==========
📂 Current UserId: user123
📂 Loading with key: user123_user456
📂 Raw values from SharedPreferences:
📂   Images: 0
📂   Videos: 0
📂   Audios: 0
✅ ✅ COUNTERS LOADED SUCCESSFULLY
✅   Images=0, Videos=0, Audios=0
🎉 🎉 COUNTER SUCCESSFULLY LOADED! 🎉 🎉

[User sends image]

🔍 ========== WOULD EXCEED CHECK START ==========
🔍 MediaType: image, Trying to add: 1
📊   - Current image count: 0
📊   - Would exceed limit of 4? false
🔍 ========== WOULD EXCEED CHECK END ==========
📈 INCREMENT: Image counter: 0 → 1 (+1)
💾 ========== SAVING COUNTERS TO STORAGE ==========
💾   Key: user123_user456
💾   Images: 1
✅ ========== SAVE VERIFICATION ==========
✅   Verified Images: 1 (expected: 1)
✅ ✅ ✅ COUNTERS SAVED & VERIFIED! ✅ ✅ ✅

[App restart]

🚀 ========== ENHANCED CHAT SCREEN OPENED ==========
📂 ========== LOADING COUNTERS FROM SHAREDPREFERENCES ==========
📂   Images: 1  ← PERSISTED! ✅
✅ COUNTERS LOADED SUCCESSFULLY
```

---

## 🚨 Common Issues & Solutions

### Issue 1: Counter resets to 0 after app restart
**Symptoms**:
```
📂   Images: 0  ← Should be 4!
```

**Debug**:
- Check if key is consistent: `user123_user456` (sorted)
- Check save verification logs
- Check if userId is null during save

---

### Issue 2: Save verification fails
**Symptoms**:
```
❌ ❌ ❌ SAVE VERIFICATION FAILED! ❌ ❌ ❌
```

**Debug**:
- Check error logs
- Check if SharedPreferences is working
- Check permissions

---

### Issue 3: Counter increments on cancel
**Symptoms**:
- User cancels, but counter increases

**Debug**:
- Check if increment happens AFTER picker, not before
- Should see: `📷 Camera cancelled by user, no counter increment`

---

## 📝 Test Checklist

- [ ] Test 1: Basic counter increments
- [ ] Test 2: Counter persists after app restart
- [ ] Test 3: Video counter works
- [ ] Test 4: Audio counter works
- [ ] Test 5: Mixed media types work independently
- [ ] Test 6: 24-hour reset works
- [ ] Test 7A: Cancel doesn't increment
- [ ] Test 7B: Force stop preserves counter
- [ ] Test 7C: Different chats have separate counters

---

## 🎯 Final Verification

Run this command to verify SharedPreferences storage:

### Android:
```bash
adb shell run-as com.yourapp.package cat /data/data/com.yourapp.package/shared_prefs/FlutterSharedPreferences.xml
```

Look for entries like:
```xml
<int name="flutter.user123_user456_imageCount" value="4" />
<int name="flutter.user123_user456_videoCount" value="2" />
<string name="flutter.user123_user456_lastReset">2026-01-27T15:30:00.000</string>
```

---

**Happy Testing!** 🚀
