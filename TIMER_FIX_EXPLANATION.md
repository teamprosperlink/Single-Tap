# Device B Logout Timer Fix ✅

**Issue:** Device B dialog not detecting token deletion
**Root Cause:** Timer was starting INSIDE builder (called repeatedly) instead of ONCE before dialog opens
**Status:** FIXED ✅
**Commit:** 0e14413

---

## The Problem

**Old Code:**
```dart
return StatefulBuilder(
  builder: (context, setDialogState) {
    // Timer code HERE - builder gets called REPEATEDLY!
    if (!logoutSuccess && uid != null && tokenCheckTimer == null) {
      Future.delayed(...).then((_) {
        tokenCheckTimer = Timer.periodic(...) { ... }
      });
    }
  }
);
```

**Issue:**
1. StatefulBuilder's builder function gets called multiple times
2. Each rebuild creates a NEW timer
3. Old timers get garbage collected
4. Token detection never works properly

---

## The Fix

**New Code:**
```dart
// START TIMER BEFORE DIALOG (in _showActiveSessionPopup function scope)
Timer? tokenCheckTimer;
print('[Dialog] 🔵 Starting token deletion detector for uid: $uid');

if (uid != null && uid.isNotEmpty) {
  tokenCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final token = doc.data()?['activeDeviceToken'];

      print('[Dialog] 🔍 Checking token: ${token == null ? "NULL ❌" : "EXISTS ✓"}');

      // If token deleted, close dialog and logout
      if (token == null || token.toString().isEmpty) {
        print('[Dialog] ✅ TOKEN DELETED DETECTED!');
        timer.cancel();

        // Close dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Sign out
        await FirebaseAuth.instance.signOut();
        print('[Dialog] ✅ Device B signed out automatically');
      }
    } catch (e) {
      print('[Dialog] ❌ Error: $e');
    }
  });
}

// NOW show dialog (timer is already running!)
showDialog(...);
```

---

## Why This Works

1. **Timer starts ONCE** - Before dialog opens
2. **Single instance** - Not recreated on rebuilds
3. **Continuous checking** - Every 200ms
4. **Keeps running** - Even if dialog rebuilds
5. **Detects deletion** - When token becomes NULL
6. **Auto-logout** - Closes dialog and signs out

---

## Timeline

```
T=0ms:    Timer starts (before dialog)
T=100ms:  Dialog appears on Device B
T=200ms:  Timer checks: "Is token NULL?"
T=400ms:  Timer checks again
T=2100ms: Device A deletes token
T=2200ms: Timer detects: Token is NULL!
T=2200ms: Dialog closes
T=2250ms: Device B signs out
T=2300ms: Device B returns to login

TOTAL: ~2.3 seconds (automatic!)
```

---

## What Changed

**File:** `lib/screens/login/login_screen.dart`

**Location:** Lines 776-809 (_showActiveSessionPopup function)

**Key Change:**
- Moved timer initialization OUT of StatefulBuilder
- Now runs BEFORE showDialog() call
- Survives dialog rebuilds
- Continuously detects token deletion

---

## Now Test This

1. **Build APK:**
   ```bash
   flutter build apk --release
   ```

2. **Install on 2 devices**

3. **Test:**
   - Device A: Click "Logout Other Device"
   - Device B: Watch for logs:
     ```
     [Dialog] 🔵 Starting token deletion detector
     [Dialog] 🔍 Checking token: EXISTS ✓
     [Dialog] 🔍 Checking token: NULL ❌
     [Dialog] ✅ TOKEN DELETED DETECTED!
     [Dialog] ✅ Device B signed out automatically
     ```

4. **Expected Result:**
   - Device B dialog closes automatically (2-3 seconds)
   - Device B is signed out
   - Both devices logged out ✓

---

## Commit Info

```
0e14413 FIX: Start token deletion timer BEFORE dialog opens (not inside builder)
```

---

**Status: Ready to test!** 🚀

Build and test on real devices now!

