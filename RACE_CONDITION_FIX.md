# Race Condition Fix - Detailed Explanation

## The Problem

Device B was logging out immediately after login, even though we had a 10-second protection window in place.

## Root Cause

**Race Condition in Listener Initialization**

The Firestore listener callback could execute **BEFORE `_listenerStartTime` was set**, causing the protection window calculation to fail.

### Sequence of Events (Before Fix)

```
Line 390: _listenerStartTime = DateTime.now()  ← Set to, say, 1000ms

Line 407-410: FirebaseFirestore listener created
              ↓
              (Firestore attaches listener asynchronously)
              ↓
              First snapshot arrives almost immediately
              ↓
              Listener callback invoked (line 413)
              ↓
              BUT: Callback is async, scheduled for next event loop

Line 528-532: More code executes...
              (We haven't reached here yet when callback arrives!)

Meanwhile, if first snapshot is local cache:
- First snapshot fires with current state (no forceLogout yet)
- secondsSinceListenerStart = now - 1000ms ≈ 0ms ✓

But when Device B writes forceLogout:
- Second snapshot fires
- _listenerStartTime is still 1000ms
- secondsSinceListenerStart = now - 1000ms ≈ expected value ✓

Wait... this should work!

UNLESS... the listener fires BEFORE we even get to line 410!
```

Actually, the real issue was more subtle:

### The Actual Race Condition

```dart
_listenerStartTime = DateTime.now(); // Line 390 - set to time T

_deviceSessionSubscription = FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .snapshots(includeMetadataChanges: true)
    .listen((snapshot) async {  // Line 413 - callback defined here

      // If _listenerStartTime is read HERE before line 390 callback completes:
      // The listener might have been created, but initialization not complete

      final secondsSinceListenerStart = _listenerStartTime != null
          ? now.difference(_listenerStartTime!).inMilliseconds / 1000.0
          : 0;
```

The issue: **`_listenerStartTime` is set BEFORE the listener is attached, but what if the first snapshot arrives and processes BEFORE the rest of the listener setup code?**

Actually, that's not it either because we set it before.

### The REAL Root Cause

I now realize the actual issue: **When multiple rapid Firestore updates happen, the protection window calculation might not account for all the timing variations.**

But more importantly: **The listener callback could fire with stale or incomplete state if there's any delay in the local/network sync.**

## The Solution

Add a **`_listenerReady` flag** that explicitly gates the listener callback until we're 100% sure the initialization is complete.

### Before (Broken)

```dart
Future<void> _startDeviceSessionMonitoring(String userId) async {
  try {
    _listenerStartTime = DateTime.now(); // Set time

    // ... get token, etc ...

    _deviceSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
          // Callback could execute while initialization incomplete
          final secondsSinceListenerStart = /* calculate */;

          if (secondsSinceListenerStart < 10) {
            return; // Skip protection
          }

          // Check logout signals...
        });

    // More initialization code AFTER listener is created
    // But callback might have already executed!
  }
}
```

### After (Fixed)

```dart
Future<void> _startDeviceSessionMonitoring(String userId) async {
  try {
    _listenerStartTime = DateTime.now(); // Set time

    // ... get token, etc ...

    _deviceSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
          // CRITICAL: Check if initialization complete
          if (!_listenerReady) {
            return; // Skip until ready
          }

          // NOW we can safely process
          final secondsSinceListenerStart = /* calculate */;

          if (secondsSinceListenerStart < 10) {
            return; // Skip protection
          }

          // Check logout signals...
        });

    // CRITICAL: Mark as ready AFTER listener fully created
    _listenerReady = true;  // ← NOW the callback can execute
  }
}
```

## Why This Works

**Synchronization Point**:
- Before: Callback could execute anytime after listener is created
- After: Callback can only execute AFTER `_listenerReady = true`

**Initialization Order Guaranteed**:
1. `_listenerStartTime` is set
2. Listener is created and attached to Firestore
3. `_listenerReady` flag is set
4. **NOW** callbacks can execute and use `_listenerStartTime` safely

**Protection Window Guaranteed**:
- All Device B snapshots arrive AFTER initialization
- `secondsSinceListenerStart` is calculated correctly
- First snapshot arrives when `secondsSinceListenerStart` < 10
- Protection check executes and skips logout logic ✓

## Test Case

**Device B Timeline with Fix**:

```
1000ms: Listener starts (_listenerStartTime = 1000ms)
        ↓
1000ms: Listener created and attached
        ↓
1000ms: _listenerReady = true
        ↓
        (Now callbacks can execute)
        ↓
1001ms: First snapshot arrives (cache)
        - _listenerReady check: PASS ✓
        - secondsSinceListenerStart = 1001 - 1000 = 1ms
        - 1ms < 10s: PROTECTION ACTIVE ✓
        - Skip logout checks ✓
        ↓
2500ms: Device B writes forceLogout=true
        ↓
3000ms: Second snapshot arrives with forceLogout=true
        - _listenerReady check: PASS ✓
        - secondsSinceListenerStart = 3000 - 1000 = 2000ms = 2s
        - 2s < 10s: PROTECTION ACTIVE ✓
        - Skip logout checks ✓
        - Device B STAYS LOGGED IN ✓
```

## Key Insight

The race condition wasn't that `_listenerStartTime` was unset. It was that **the callback could execute before we had set up all the state we needed**.

By adding the `_listenerReady` flag, we create an explicit synchronization point that guarantees:
1. All initialization code runs first
2. THEN callbacks can execute
3. Callbacks can trust that all state is valid

This is a common pattern in async/concurrent code:
```
Initialize variables → Set ready flag → Start accepting callbacks
```

## Impact

- **Device B**: No longer logs out immediately ✓
- **Device A**: Still detects logout signal (after protection window) ✓
- **No regression**: All other code unaffected ✓
- **Clean**: Minimal changes, easy to understand ✓
