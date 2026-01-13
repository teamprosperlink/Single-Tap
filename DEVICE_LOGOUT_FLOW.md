# Device Logout Flow - Visual Explanation

## The Problem (Before Fix)

```
┌─────────────────────────────────────────────────────────────┐
│ Device A (Old)                  Device B (New)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ ✅ Logged in                    User logs in                 │
│ App closed / Offline            ↓                            │
│ ❌ No listener running          Shows device conflict dialog │
│ activeDeviceToken stored        User clicks logout button    │
│                                 ↓                            │
│                                 forceLogout=true is set      │
│                                                              │
│ ❌ PROBLEM: Listener not        ✅ Device B logged in       │
│    running, so can't detect    ✅ activeDeviceToken = B's   │
│    forceLogout flag!                                         │
│                                                              │
│ ❌ Device A STILL LOGGED IN!    ✅ Both devices logged in!  │
│                                 🔴 SECURITY ISSUE           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## The Solution (After Fix)

### 3-Layer Detection System

```
┌──────────────────────────────────────────────────────────────────┐
│                     DEVICE LOGOUT DETECTION                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  LAYER 1: Immediate Token Deletion (PRIMARY FIX)                 │
│  ────────────────────────────────────────────────                │
│  ✅ Works when Device A is OFFLINE                               │
│  ✅ Token deleted from Firestore immediately                     │
│  ✅ Device A logs out when it comes online                       │
│                                                                   │
│  LAYER 2: forceLogout Flag (For Online Devices)                  │
│  ────────────────────────────────────                            │
│  ✅ Works when Device A is ONLINE                                │
│  ✅ Detected within 500ms by listener                            │
│  ✅ Instant logout for active devices                            │
│                                                                   │
│  LAYER 3: Stale Session Auto-Cleanup (Automatic)                │
│  ──────────────────────────────────────────────                 │
│  ✅ Removes stuck sessions (>5 min no update)                    │
│  ✅ Prevents app crash edge cases                                │
│  ✅ Triggered when Device B tries to login                       │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Scenario 1: Device A OFFLINE

```
Timeline:
─────────────────────────────────────────────────────────────────

Device A (OFFLINE)              Device B (NEW LOGIN)
─────────────────               ──────────────────────

❌ App closed                   T=0: User logs in
❌ No listener                  T=0: Dialog shows
❌ No network                   T=1: Click "Logout Other Device"

                                T=2: Call logoutFromOtherDevices()
                                ↓
                                STEP 0: Delete Device A's token ✅
                                  activeDeviceToken.delete()
                                ↓
                                STEP 1: Set forceLogout=true ✅
                                ↓
                                STEP 2: Set own token active ✅
                                  activeDeviceToken = "Device B token"

                                T=3: Device B logged in ✅

─────────────────────────────────────────────────────────────────

Device A comes ONLINE
T=10: App opens
T=11: Listener starts
T=12: Listener detects:
      ✅ activeDeviceToken is EMPTY!
      ✅ Calls _performRemoteLogout()

T=13: Device A LOGS OUT ✅
      Shows login screen
      No longer logged in

Result: SINGLE DEVICE LOGIN ENFORCED ✅
─────────────────────────────────────────────────────────────────
```

## Scenario 2: Device A ONLINE

```
Timeline:
─────────────────────────────────────────────────────────────────

Device A (ONLINE)               Device B (NEW LOGIN)
─────────────────               ──────────────────────

✅ App running                  T=0: User logs in
✅ Listener active              T=0: Dialog shows
✅ Has network                  T=1: Click "Logout Other Device"

                                T=2: Call logoutFromOtherDevices()
                                ↓
                                STEP 0: Delete token ✅
                                STEP 1: Set forceLogout=true ✅
                                STEP 2: Set own token ✅

                                T=3: Device B logged in ✅

Device A's listener detects:
T=2.5: Snapshot fires!
       ✅ forceLogout=true detected!
       ✅ Calls _performRemoteLogout()
       ✅ Firebase.signOut()

T=3: Device A LOGS OUT ✅
     Shows login screen
     No longer logged in

Device B at T=3:
✅ Successfully logged in
✅ Both devices NOT running same session
✅ Single device login enforced

Result: INSTANT LOGOUT (500ms) ✅
─────────────────────────────────────────────────────────────────
```

## Scenario 3: Stale Session (Auto-Cleanup)

```
Timeline:
─────────────────────────────────────────────────────────────────

Device A Session                Device B (NEW LOGIN)
─────────────────               ──────────────────────

T=0: User logs in
T=1: App running, listener active

T=5: Screen off, app paused
T=6-T=60: No updates to Firestore
         ❌ lastSessionUpdate stuck at T=1

T=65: User force kills app on Device A
     ❌ No graceful logout
     activeDeviceToken still = "Device A token"
     lastSessionUpdate still = old timestamp

─────────────────────────────────────────────────────────────────

Device B tries to login at T=70:
T=70: Call _checkExistingSession()
      ↓
      Check: Is old session stale?
      ↓
      Calculate: T=70 - T=1 = 69 minutes
      ✅ Yes! Stale (>5 minutes)
      ↓
      Auto-cleanup:
      activeDeviceToken.delete() ✅
      forceLogout=false ✅
      ↓
      Return: No existing session!
      ↓
T=71: Device B logs in normally ✅
     No device conflict dialog
     No need to click anything

Result: AUTO-CLEANUP PREVENTS STUCK SESSIONS ✅
─────────────────────────────────────────────────────────────────
```

## Code Flow

```
User clicks "Logout Other Device"
           ↓
authService.logoutFromOtherDevices(userId)
           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 0: IMMEDIATE TOKEN DELETION                             │
│ ────────────────────────────────                             │
│ FirebaseFirestore.instance                                   │
│   .collection('users')                                       │
│   .doc(uid)                                                  │
│   .update({                                                  │
│     'activeDeviceToken': FieldValue.delete()  ✅            │
│   })                                                          │
│                                                               │
│ Result: Old device's token is GONE from Firestore           │
└──────────────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 1: SET FORCE LOGOUT FLAG                               │
│ ─────────────────────────────────                           │
│ FirebaseFirestore.instance                                   │
│   .collection('users')                                       │
│   .doc(uid)                                                  │
│   .set({                                                     │
│     'forceLogout': true  ✅                                 │
│   }, merge: true)                                            │
│                                                               │
│ Result: Signal sent to listening devices                     │
└──────────────────────────────────────────────────────────────┘
           ↓
        Wait 500ms
           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 2: SET NEW DEVICE AS ACTIVE                            │
│ ────────────────────────────────                            │
│ FirebaseFirestore.instance                                   │
│   .collection('users')                                       │
│   .doc(uid)                                                  │
│   .set({                                                     │
│     'activeDeviceToken': newDeviceToken  ✅                │
│   }, merge: true)                                            │
│                                                               │
│ Result: Device B is now the active device                    │
└──────────────────────────────────────────────────────────────┘
           ↓
        Wait 1000ms
           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 3: CLEAR LOGOUT FLAG                                   │
│ ───────────────────────────                                 │
│ FirebaseFirestore.instance                                   │
│   .collection('users')                                       │
│   .doc(uid)                                                  │
│   .update({                                                  │
│     'forceLogout': false  ✅                                │
│   })                                                          │
│                                                               │
│ Result: Cleanup complete, ready for next login              │
└──────────────────────────────────────────────────────────────┘
           ↓
      Device B logged in!
```

## Summary Table

| Scenario | Detection | Time | Result |
|----------|-----------|------|--------|
| **Device A Online** | forceLogout=true flag | 500ms | Instant logout |
| **Device A Offline** | Token deletion detection | 2-3s after reconnect | Logout on reconnect |
| **Stale Session** | Auto-cleanup check | When B logs in | Automatic removal |

## Key Improvements

✅ **Reliability:** 3-layer detection covers all scenarios
✅ **Speed:** Online logout in 500ms, offline logout on reconnect
✅ **Robustness:** Auto-cleanup handles edge cases
✅ **UX:** No user confusion, clear device conflict UI
✅ **Security:** Single device login enforced at system level
