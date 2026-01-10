import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class GroupChatService {
  static final GroupChatService _instance = GroupChatService._internal();
  factory GroupChatService() => _instance;
  GroupChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  /// Create a new group chat
  /// Returns the group ID if successful
  Future<String?> createGroup({
    required String groupName,
    required List<String> memberIds,
    String? groupPhotoUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('GroupChatService: No authenticated user');
      return null;
    }

    try {
      // Generate unique group ID
      final groupId = 'group_${_uuid.v4()}';

      // Add current user to members if not already included
      final allMembers = <String>{currentUserId, ...memberIds}.toList();

      // BATCH READ: Get all member docs at once instead of one by one
      final memberNames = <String, String>{};
      final memberPhotos = <String, String?>{};

      final userDocs = await Future.wait(
        allMembers.map((id) => _firestore.collection('users').doc(id).get()),
      );

      for (int i = 0; i < allMembers.length; i++) {
        final memberId = allMembers[i];
        final userDoc = userDocs[i];
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          memberNames[memberId] = userData['name'] ?? 'Unknown';
          memberPhotos[memberId] = userData['photoUrl'] ?? userData['profileImageUrl'];
        } else {
          memberNames[memberId] = 'Unknown';
          memberPhotos[memberId] = null;
        }
      }

      // Create group conversation document
      await _firestore.collection('conversations').doc(groupId).set({
        'id': groupId,
        'isGroup': true,
        'groupName': groupName,
        'groupPhoto': groupPhotoUrl,
        'participants': allMembers,
        'participantNames': memberNames,
        'participantPhotos': memberPhotos,
        'admins': [currentUserId],
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '${memberNames[currentUserId] ?? 'Someone'} created this group',
        'lastMessageSenderId': 'system',
        'unreadCount': {for (var id in allMembers) id: 0},
        'isTyping': {for (var id in allMembers) id: false},
        'readBy': <String, dynamic>{}, // Per-user read tracking
      });

      // Add system message for group creation
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '${memberNames[currentUserId] ?? 'Someone'} created this group',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[], // Track who has read this message
      });

      debugPrint('GroupChatService: Created group $groupId with ${allMembers.length} members');
      return groupId;
    } catch (e) {
      debugPrint('GroupChatService: Error creating group: $e');
      return null;
    }
  }

  /// Add members to a group (admin only)
  Future<bool> addMembers({
    required String groupId,
    required List<String> newMemberIds,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final admins = List<String>.from(data['admins'] ?? []);

      // Only admins can add members
      if (!admins.contains(currentUserId)) {
        debugPrint('GroupChatService: User is not admin, cannot add members');
        return false;
      }

      final existingMembers = List<String>.from(data['participants'] ?? []);
      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});
      final memberPhotos = Map<String, String?>.from(data['participantPhotos'] ?? {});
      final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
      final isTyping = Map<String, bool>.from(data['isTyping'] ?? {});

      // Filter out already existing members
      final actualNewMembers = newMemberIds.where((id) => !existingMembers.contains(id)).toList();

      if (actualNewMembers.isEmpty) return true; // No new members to add

      // BATCH READ: Get all new member docs at once
      final userDocs = await Future.wait(
        actualNewMembers.map((id) => _firestore.collection('users').doc(id).get()),
      );

      for (int i = 0; i < actualNewMembers.length; i++) {
        final memberId = actualNewMembers[i];
        final userDoc = userDocs[i];

        existingMembers.add(memberId);
        unreadCount[memberId] = 0;
        isTyping[memberId] = false;

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          memberNames[memberId] = userData['name'] ?? 'Unknown';
          memberPhotos[memberId] = userData['photoUrl'] ?? userData['profileImageUrl'];
        } else {
          memberNames[memberId] = 'Unknown';
          memberPhotos[memberId] = null;
        }
      }

      // Update group
      await _firestore.collection('conversations').doc(groupId).update({
        'participants': existingMembers,
        'participantNames': memberNames,
        'participantPhotos': memberPhotos,
        'unreadCount': unreadCount,
        'isTyping': isTyping,
      });

      // Add system message
      final adderName = memberNames[currentUserId] ?? 'Someone';
      final addedNames = actualNewMembers
          .map((id) => memberNames[id] ?? 'Unknown')
          .join(', ');

      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '$adderName added $addedNames to the group',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error adding members: $e');
      return false;
    }
  }

  /// Remove a member from a group (admin only, cannot remove other admins unless you're the creator)
  Future<bool> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final admins = List<String>.from(data['admins'] ?? []);
      final createdBy = data['createdBy'] as String?;

      // Only admins can remove members
      if (!admins.contains(currentUserId)) {
        debugPrint('GroupChatService: User is not admin, cannot remove members');
        return false;
      }

      // Cannot remove yourself using this method (use leaveGroup instead)
      if (memberId == currentUserId) {
        debugPrint('GroupChatService: Use leaveGroup to remove yourself');
        return false;
      }

      // Only the creator can remove other admins
      if (admins.contains(memberId) && currentUserId != createdBy) {
        debugPrint('GroupChatService: Only group creator can remove other admins');
        return false;
      }

      final participants = List<String>.from(data['participants'] ?? []);
      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});

      if (!participants.contains(memberId)) return false;

      final removedName = memberNames[memberId] ?? 'Unknown';
      final removerName = memberNames[currentUserId] ?? 'Someone';

      participants.remove(memberId);

      // Also remove from admins if they were an admin
      final updatedAdmins = admins.where((id) => id != memberId).toList();

      await _firestore.collection('conversations').doc(groupId).update({
        'participants': participants,
        'admins': updatedAdmins,
      });

      // Add system message
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '$removerName removed $removedName from the group',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error removing member: $e');
      return false;
    }
  }

  /// Make a member an admin (only creator can do this)
  Future<bool> makeAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final createdBy = data['createdBy'] as String?;
      final admins = List<String>.from(data['admins'] ?? []);
      final participants = List<String>.from(data['participants'] ?? []);
      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});

      // Only creator can make someone admin
      if (currentUserId != createdBy) {
        debugPrint('GroupChatService: Only creator can make admins');
        return false;
      }

      // Member must be a participant
      if (!participants.contains(memberId)) {
        debugPrint('GroupChatService: User is not a member of this group');
        return false;
      }

      // Already an admin
      if (admins.contains(memberId)) {
        return true;
      }

      admins.add(memberId);

      await _firestore.collection('conversations').doc(groupId).update({
        'admins': admins,
      });

      // Add system message
      final memberName = memberNames[memberId] ?? 'Someone';
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '$memberName is now an admin',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error making admin: $e');
      return false;
    }
  }

  /// Remove admin privileges (only creator can do this)
  Future<bool> removeAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final createdBy = data['createdBy'] as String?;
      final admins = List<String>.from(data['admins'] ?? []);
      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});

      // Only creator can remove admin privileges
      if (currentUserId != createdBy) {
        debugPrint('GroupChatService: Only creator can remove admins');
        return false;
      }

      // Cannot remove creator's admin status
      if (memberId == createdBy) {
        debugPrint('GroupChatService: Cannot remove creator admin status');
        return false;
      }

      // Not an admin
      if (!admins.contains(memberId)) {
        return true;
      }

      admins.remove(memberId);

      await _firestore.collection('conversations').doc(groupId).update({
        'admins': admins,
      });

      // Add system message
      final memberName = memberNames[memberId] ?? 'Someone';
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '$memberName is no longer an admin',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error removing admin: $e');
      return false;
    }
  }

  /// Leave a group
  Future<bool> leaveGroup(String groupId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});
      final admins = List<String>.from(data['admins'] ?? []);
      final createdBy = data['createdBy'] as String?;

      final leaverName = memberNames[currentUserId] ?? 'Someone';

      participants.remove(currentUserId);
      admins.remove(currentUserId);

      // If no participants left, delete the group
      if (participants.isEmpty) {
        // Delete all messages first
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(groupId)
            .collection('messages')
            .get();

        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(_firestore.collection('conversations').doc(groupId));
        await batch.commit();

        return true;
      }

      // If the creator is leaving and there are admins, transfer ownership
      String? newCreator;
      if (currentUserId == createdBy) {
        if (admins.isNotEmpty) {
          newCreator = admins.first;
        } else if (participants.isNotEmpty) {
          newCreator = participants.first;
          admins.add(newCreator);
        }
      }

      // If no admins left, make the first participant an admin
      if (admins.isEmpty && participants.isNotEmpty) {
        admins.add(participants.first);
      }

      final updates = <String, dynamic>{
        'participants': participants,
        'admins': admins,
      };

      if (newCreator != null) {
        updates['createdBy'] = newCreator;
      }

      await _firestore.collection('conversations').doc(groupId).update(updates);

      // Add system message
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '$leaverName left the group',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      // Clear typing status on leave
      await clearTypingStatus(groupId);

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error leaving group: $e');
      return false;
    }
  }

  /// Update group name (admin only)
  Future<bool> updateGroupName({
    required String groupId,
    required String newName,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final admins = List<String>.from(data['admins'] ?? []);

      // Only admins can update group name
      if (!admins.contains(currentUserId)) {
        debugPrint('GroupChatService: Only admins can update group name');
        return false;
      }

      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});
      final oldName = data['groupName'] ?? 'Group';

      await _firestore.collection('conversations').doc(groupId).update({
        'groupName': newName,
      });

      // Add system message
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '${memberNames[currentUserId] ?? 'Someone'} changed the group name from "$oldName" to "$newName"',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error updating group name: $e');
      return false;
    }
  }

  /// Update group photo (admin only)
  Future<bool> updateGroupPhoto({
    required String groupId,
    required String photoUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      final admins = List<String>.from(data['admins'] ?? []);

      // Only admins can update group photo
      if (!admins.contains(currentUserId)) {
        debugPrint('GroupChatService: Only admins can update group photo');
        return false;
      }

      final memberNames = Map<String, String>.from(data['participantNames'] ?? {});

      await _firestore.collection('conversations').doc(groupId).update({
        'groupPhoto': photoUrl,
      });

      // Add system message
      await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '${memberNames[currentUserId] ?? 'Someone'} updated the group photo',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
        'readBy': <String>[],
      });

      return true;
    } catch (e) {
      debugPrint('GroupChatService: Error updating group photo: $e');
      return false;
    }
  }

  /// Send a message to a group
  Future<String?> sendMessage({
    required String groupId,
    required String text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    String? replyToMessageId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      // Verify user is a participant
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return null;

      final participants = List<String>.from(groupDoc.data()?['participants'] ?? []);
      if (!participants.contains(currentUserId)) {
        debugPrint('GroupChatService: User is not a participant');
        return null;
      }

      // Add message with per-user read tracking
      final messageRef = await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': text,
        'imageUrl': imageUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
        'readBy': [currentUserId], // Sender has read their own message
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      });

      final updates = <String, dynamic>{
        'lastMessage': text.isNotEmpty ? text : (imageUrl != null ? ' Photo' : '📎 File'),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      };

      // Increment unread count for other participants
      for (final participantId in participants) {
        if (participantId != currentUserId) {
          updates['unreadCount.$participantId'] = FieldValue.increment(1);
        }
      }

      await _firestore.collection('conversations').doc(groupId).update(updates);

      return messageRef.id;
    } catch (e) {
      debugPrint('GroupChatService: Error sending message: $e');
      return null;
    }
  }

  /// Mark messages as read with per-user tracking
  Future<void> markAsRead(String groupId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Update unread count
      await _firestore.collection('conversations').doc(groupId).update({
        'unreadCount.$currentUserId': 0,
        'readBy.$currentUserId': FieldValue.serverTimestamp(),
      });

      // Mark recent messages as read by this user
      final recentMessages = await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final batch = _firestore.batch();
      for (final doc in recentMessages.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(currentUserId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUserId]),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('GroupChatService: Error marking as read: $e');
    }
  }

  /// Set typing status
  Future<void> setTyping(String groupId, bool isTyping) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('conversations').doc(groupId).update({
        'isTyping.$currentUserId': isTyping,
        if (isTyping) 'typingTimestamp.$currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('GroupChatService: Error setting typing: $e');
    }
  }

  /// Clear typing status (call when leaving chat or disconnecting)
  Future<void> clearTypingStatus(String groupId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('conversations').doc(groupId).update({
        'isTyping.$currentUserId': false,
      });
    } catch (e) {
      debugPrint('GroupChatService: Error clearing typing status: $e');
    }
  }

  /// Get group members with batch read
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return [];

      final data = groupDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final admins = List<String>.from(data['admins'] ?? []);
      final createdBy = data['createdBy'] as String?;

      if (participants.isEmpty) return [];

      // BATCH READ: Get all user docs at once
      final userDocs = await Future.wait(
        participants.map((id) => _firestore.collection('users').doc(id).get()),
      );

      final members = <Map<String, dynamic>>[];
      for (int i = 0; i < participants.length; i++) {
        final userId = participants[i];
        final userDoc = userDocs[i];

        if (userDoc.exists) {
          members.add({
            ...userDoc.data()!,
            'id': userId,
            'isAdmin': admins.contains(userId),
            'isCreator': userId == createdBy,
          });
        }
      }

      // Sort: creator first, then admins, then regular members
      members.sort((a, b) {
        if (a['isCreator'] == true) return -1;
        if (b['isCreator'] == true) return 1;
        if (a['isAdmin'] == true && b['isAdmin'] != true) return -1;
        if (b['isAdmin'] == true && a['isAdmin'] != true) return 1;
        return 0;
      });

      return members;
    } catch (e) {
      debugPrint('GroupChatService: Error getting members: $e');
      return [];
    }
  }

  /// Check if user is admin
  Future<bool> isAdmin(String groupId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final admins = List<String>.from(groupDoc.data()?['admins'] ?? []);
      return admins.contains(currentUserId);
    } catch (e) {
      return false;
    }
  }

  /// Check if user is the group creator
  Future<bool> isCreator(String groupId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return false;

      return groupDoc.data()?['createdBy'] == currentUserId;
    } catch (e) {
      return false;
    }
  }

  /// Get who has read a specific message
  Future<List<String>> getMessageReadBy(String groupId, String messageId) async {
    try {
      final messageDoc = await _firestore
          .collection('conversations')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return [];

      return List<String>.from(messageDoc.data()?['readBy'] ?? []);
    } catch (e) {
      debugPrint('GroupChatService: Error getting message read by: $e');
      return [];
    }
  }

  /// Clean up stale typing indicators (older than 10 seconds)
  Future<void> cleanupStaleTypingIndicators(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (!groupDoc.exists) return;

      final data = groupDoc.data()!;
      final isTyping = Map<String, bool>.from(data['isTyping'] ?? {});
      final typingTimestamps = Map<String, dynamic>.from(data['typingTimestamp'] ?? {});

      final now = DateTime.now();
      final updates = <String, dynamic>{};

      for (final entry in isTyping.entries) {
        if (entry.value == true) {
          final timestamp = typingTimestamps[entry.key];
          if (timestamp != null && timestamp is Timestamp) {
            final typingTime = timestamp.toDate();
            if (now.difference(typingTime).inSeconds > 10) {
              updates['isTyping.${entry.key}'] = false;
            }
          } else {
            // No timestamp, clear it
            updates['isTyping.${entry.key}'] = false;
          }
        }
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('conversations').doc(groupId).update(updates);
      }
    } catch (e) {
      debugPrint('GroupChatService: Error cleaning up typing indicators: $e');
    }
  }
}
