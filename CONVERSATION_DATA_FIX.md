# Conversation Data Fix

## Problem

Group call messages are appearing in 1-on-1 chats and vice versa.

## Root Cause

Possible data inconsistency issues:
1. Some conversations might not have `isGroup` field set correctly
2. Some group conversations might have wrong ID format (not starting with "group_")
3. Some 1-on-1 conversations might have `isGroup: true` incorrectly

## Solution

Run this Firestore query in Firebase Console to check for inconsistencies:

### Check 1: Find conversations without isGroup field

```javascript
// In Firebase Console -> Firestore -> Run Query
db.collection('conversations')
  .get()
  .then(snapshot => {
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.isGroup === undefined) {
        console.log(`Missing isGroup: ${doc.id}`);
      }
    });
  });
```

### Check 2: Find groups with wrong ID format

```javascript
db.collection('conversations')
  .where('isGroup', '==', true)
  .get()
  .then(snapshot => {
    snapshot.docs.forEach(doc => {
      if (!doc.id.startsWith('group_')) {
        console.log(`Wrong group ID format: ${doc.id}`);
      }
    });
  });
```

### Check 3: Find 1-on-1 chats with isGroup=true

```javascript
db.collection('conversations')
  .where('isGroup', '==', true)
  .get()
  .then(snapshot => {
    snapshot.docs.forEach(doc => {
      const participants = doc.data().participants || [];
      if (participants.length === 2 && !doc.id.startsWith('group_')) {
        console.log(`1-on-1 chat marked as group: ${doc.id}`);
      }
    });
  });
```

## Fix Script

Run this in Firebase Console to fix data:

```javascript
// Fix conversations without isGroup field
db.collection('conversations')
  .get()
  .then(snapshot => {
    const batch = db.batch();
    let count = 0;

    snapshot.docs.forEach(doc => {
      const data = doc.data();

      // If isGroup field is missing, set it based on ID format
      if (data.isGroup === undefined) {
        const isGroup = doc.id.startsWith('group_');
        batch.update(doc.ref, { isGroup: isGroup });
        console.log(`Fixing ${doc.id}: isGroup = ${isGroup}`);
        count++;
      }
    });

    if (count > 0) {
      return batch.commit().then(() => {
        console.log(`Fixed ${count} conversations`);
      });
    } else {
      console.log('No conversations to fix');
    }
  });
```

## Prevention

The current code is correct and should prevent this issue going forward:

1. ✅ Group conversations are created with `isGroup: true` and ID starting with "group_"
2. ✅ 1-on-1 conversations use "userId1_userId2" format
3. ✅ System messages are saved to correct conversation using groupId/conversationId

## Testing

After running the fix script:

1. Create a new group call - message should appear in group chat only
2. Create a new 1-on-1 call - message should appear in that specific chat only
3. Check existing calls to verify they're in correct chats

---

**Date**: January 24, 2026
**Status**: Data fix required - code is already correct
