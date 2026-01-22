import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/call/group_video_call_screen.dart';
import '../screens/call/incoming_group_video_call_screen.dart';
import '../widgets/select_participants_dialog.dart';

/// Helper functions for managing group video calls
class GroupCallHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Show participant selection dialog and start a group video call
  static Future<void> showParticipantSelectionAndStartCall({
    required BuildContext context,
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhotoUrl,
  }) async {
    // Show participant selection dialog
    final selectedUsers = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => SelectParticipantsDialog(
        currentUserId: currentUserId,
        maxParticipants: 7,
      ),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty && context.mounted) {
      await startGroupVideoCall(
        context: context,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserPhotoUrl: currentUserPhotoUrl,
        selectedUsers: selectedUsers,
      );
    }
  }

  /// Start a group video call
  static Future<void> startGroupVideoCall({
    required BuildContext context,
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhotoUrl,
    required List<Map<String, dynamic>> selectedUsers,
  }) async {
    if (selectedUsers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Create group call document
      final callDoc = _firestore.collection('group_calls').doc();
      final callId = callDoc.id;

      await callDoc.set({
        'callId': callId,
        'callerUserId': currentUserId,
        'callerName': currentUserName,
        'callerPhotoUrl': currentUserPhotoUrl,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
        'maxParticipants': 8,
      });

      // Add all participants (including caller)
      final batch = _firestore.batch();

      // Add caller as active participant
      batch.set(callDoc.collection('participants').doc(currentUserId), {
        'userId': currentUserId,
        'userName': currentUserName,
        'userPhotoUrl': currentUserPhotoUrl,
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add other participants as inactive (waiting to join)
      for (var user in selectedUsers) {
        batch.set(callDoc.collection('participants').doc(user['userId']), {
          'userId': user['userId'],
          'userName': user['name'],
          'userPhotoUrl': user['photoUrl'],
          'isActive': false, // They haven't joined yet
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Send notifications to all participants
      for (var user in selectedUsers) {
        await sendGroupCallNotification(
          receiverUserId: user['userId'],
          callerName: currentUserName,
          callId: callId,
          participantCount: selectedUsers.length + 1,
        );
      }

      if (!context.mounted) return;

      // Navigate to group video call screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupVideoCallScreen(
            callId: callId,
            userId: currentUserId,
            userName: currentUserName,
            participants: [
              {
                'userId': currentUserId,
                'name': currentUserName,
                'photoUrl': currentUserPhotoUrl,
              },
              ...selectedUsers,
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('  Error starting group call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send group call notification to a user
  static Future<void> sendGroupCallNotification({
    required String receiverUserId,
    required String callerName,
    required String callId,
    required int participantCount,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': receiverUserId,
        'senderId': callerName,
        'type': 'group_video_call',
        'title': 'Group Video Call',
        'body': '$callerName is calling... ($participantCount participants)',
        'data': {'callId': callId, 'type': 'group_video_call'},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('  Group call notification sent to $receiverUserId');
    } catch (e) {
      debugPrint('  Error sending notification: $e');
    }
  }

  /// Handle incoming group call notification
  static Future<void> handleIncomingGroupCall({
    required BuildContext context,
    required String callId,
    required String currentUserId,
  }) async {
    try {
      // Fetch call details
      final callDoc = await _firestore
          .collection('group_calls')
          .doc(callId)
          .get();

      if (!callDoc.exists) {
        debugPrint('  Call document does not exist');
        return;
      }

      final callData = callDoc.data()!;
      final status = callData['status'] as String;

      // Only show if call is still ringing or active
      if (status != 'ringing' && status != 'active') {
        debugPrint('⚠️ Call is not ringing or active (status: $status)');
        return;
      }

      // Fetch participants
      final participantsSnapshot = await _firestore
          .collection('group_calls')
          .doc(callId)
          .collection('participants')
          .get();

      final participants = participantsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': data['userId'] as String,
          'name': data['userName'] as String,
          'photoUrl': data['userPhotoUrl'] as String?,
        };
      }).toList();

      if (!context.mounted) return;

      // Navigate to incoming call screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingGroupVideoCallScreen(
            callId: callId,
            callerName: callData['callerName'] as String,
            callerPhotoUrl: callData['callerPhotoUrl'] as String?,
            participants: participants,
            currentUserId: currentUserId,
          ),
        ),
      );

      debugPrint('  Navigated to incoming group call screen');
    } catch (e) {
      debugPrint('  Error handling incoming call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cancel a group call (for caller only)
  static Future<void> cancelGroupCall(String callId) async {
    try {
      await _firestore.collection('group_calls').doc(callId).update({
        'status': 'cancelled',
        'endedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('  Group call cancelled: $callId');
    } catch (e) {
      debugPrint('  Error cancelling call: $e');
    }
  }

  /// End a group call
  static Future<void> endGroupCall(String callId) async {
    try {
      await _firestore.collection('group_calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('  Group call ended: $callId');
    } catch (e) {
      debugPrint('  Error ending call: $e');
    }
  }

  /// Check if a group call is still active
  static Future<bool> isCallActive(String callId) async {
    try {
      final doc = await _firestore.collection('group_calls').doc(callId).get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final status = data['status'] as String?;
      return status == 'ringing' || status == 'active';
    } catch (e) {
      debugPrint('  Error checking call status: $e');
      return false;
    }
  }

  /// Get active participants count
  static Future<int> getActiveParticipantCount(String callId) async {
    try {
      final snapshot = await _firestore
          .collection('group_calls')
          .doc(callId)
          .collection('participants')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('  Error getting participant count: $e');
      return 0;
    }
  }
}
