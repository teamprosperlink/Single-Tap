import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Service for managing user connections and connection requests
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  //    CONNECTION REQUEST

  /// Send a connection request to another user
  Future<Map<String, dynamic>> sendConnectionRequest({
    required String receiverId,
    String? message,
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    if (senderId == receiverId) {
      return {'success': false, 'message': 'Cannot connect with yourself'};
    }

    try {
      // Check if already connected
      final isConnected = await areUsersConnected(senderId, receiverId);
      if (isConnected) {
        return {
          'success': false,
          'message': 'Already connected with this user',
        };
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('connection_requests')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return {'success': false, 'message': 'Connection request already sent'};
      }

      // Get sender info
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      final senderData = senderDoc.data() ?? {};
      final senderName = senderData['name'] ?? 'Someone';

      // Create connection request
      final requestRef = await _firestore.collection('connection_requests').add(
        {
          'senderId': senderId,
          'senderName': senderName,
          'senderPhoto': senderData['photoUrl'],
          'receiverId': receiverId,
          'message': message,
          'status': 'pending', // pending, accepted, rejected
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Send notification to receiver
      await _sendConnectionNotification(
        receiverId: receiverId,
        senderName: senderName,
        requestId: requestRef.id,
      );

      debugPrint(' Connection request sent to $receiverId');
      return {
        'success': true,
        'message': 'Connection request sent successfully',
        'requestId': requestRef.id,
      };
    } catch (e) {
      debugPrint(' Error sending connection request: $e');
      return {'success': false, 'message': 'Failed to send request: $e'};
    }
  }

  /// Accept a connection request
  Future<Map<String, dynamic>> acceptConnectionRequest(String requestId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      // Get request
      final requestDoc = await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Request not found'};
      }

      final requestData = requestDoc.data()!;
      final senderId = requestData['senderId'] as String;
      final receiverId = requestData['receiverId'] as String;

      // Verify current user is the receiver
      if (receiverId != currentUserId) {
        return {'success': false, 'message': 'Unauthorized'};
      }

      // Update request status
      await requestDoc.reference.update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create bidirectional connection
      await _createConnection(senderId, receiverId);

      // Get current user's name (the one who accepted)
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Someone';

      // Send notification to the SENDER (the person who sent the request)
      await _notificationService.sendNotificationToUser(
        userId: senderId,
        title: 'Connection Accepted',
        body: '$currentUserName accepted your connection request',
        type: 'connection_accepted',
        data: {'connectionUserId': currentUserId},
      );

      debugPrint(' Connection request accepted: $requestId');
      return {'success': true, 'message': 'Connection accepted'};
    } catch (e) {
      debugPrint(' Error accepting connection request: $e');
      return {'success': false, 'message': 'Failed to accept request: $e'};
    }
  }

  /// Reject a connection request
  Future<Map<String, dynamic>> rejectConnectionRequest(String requestId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      // Get request
      final requestDoc = await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Request not found'};
      }

      final requestData = requestDoc.data()!;
      final receiverId = requestData['receiverId'] as String;

      // Verify current user is the receiver
      if (receiverId != currentUserId) {
        return {'success': false, 'message': 'Unauthorized'};
      }

      // Update request status
      await requestDoc.reference.update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(' Connection request rejected: $requestId');
      return {'success': true, 'message': 'Connection request rejected'};
    } catch (e) {
      debugPrint(' Error rejecting connection request: $e');
      return {'success': false, 'message': 'Failed to reject request: $e'};
    }
  }

  /// Cancel a sent connection request
  Future<Map<String, dynamic>> cancelConnectionRequest(String requestId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      // Get request
      final requestDoc = await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return {'success': false, 'message': 'Request not found'};
      }

      final requestData = requestDoc.data()!;
      final senderId = requestData['senderId'] as String;

      // Verify current user is the sender
      if (senderId != currentUserId) {
        return {'success': false, 'message': 'Unauthorized'};
      }

      // Delete request
      await requestDoc.reference.delete();

      debugPrint(' Connection request cancelled: $requestId');
      return {'success': true, 'message': 'Connection request cancelled'};
    } catch (e) {
      debugPrint(' Error cancelling connection request: $e');
      return {'success': false, 'message': 'Failed to cancel request: $e'};
    }
  }

  //    CONNECTIONS MANAGEMENT

  /// Create a connection between two users
  Future<void> _createConnection(String user1Id, String user2Id) async {
    final batch = _firestore.batch();

    // Add to user1's connections
    batch.update(_firestore.collection('users').doc(user1Id), {
      'connections': FieldValue.arrayUnion([user2Id]),
      'connectionCount': FieldValue.increment(1),
    });

    // Add to user2's connections
    batch.update(_firestore.collection('users').doc(user2Id), {
      'connections': FieldValue.arrayUnion([user1Id]),
      'connectionCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Remove connection between two users
  Future<Map<String, dynamic>> removeConnection(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      final batch = _firestore.batch();

      // Remove from current user's connections
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'connections': FieldValue.arrayRemove([userId]),
        'connectionCount': FieldValue.increment(-1),
      });

      // Remove from other user's connections
      batch.update(_firestore.collection('users').doc(userId), {
        'connections': FieldValue.arrayRemove([currentUserId]),
        'connectionCount': FieldValue.increment(-1),
      });

      await batch.commit();

      debugPrint(' Connection removed with user $userId');
      return {'success': true, 'message': 'Connection removed'};
    } catch (e) {
      debugPrint(' Error removing connection: $e');
      return {'success': false, 'message': 'Failed to remove connection: $e'};
    }
  }

  /// Check if two users are connected
  Future<bool> areUsersConnected(String user1Id, String user2Id) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user1Id).get();
      final connections = List<String>.from(
        userDoc.data()?['connections'] ?? [],
      );
      return connections.contains(user2Id);
    } catch (e) {
      debugPrint('  Error checking connection status: $e');
      return false;
    }
  }

  /// Get user's connections list
  Future<List<String>> getUserConnections() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      return List<String>.from(userDoc.data()?['connections'] ?? []);
    } catch (e) {
      debugPrint('  Error getting connections: $e');
      return [];
    }
  }

  /// Get connections count
  Future<int> getConnectionsCount() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      return userDoc.data()?['connectionCount'] ?? 0;
    } catch (e) {
      debugPrint('  Error getting connection count: $e');
      return 0;
    }
  }

  //    REQUESTS QUERIES

  /// Get pending connection requests (received)
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('connection_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Get sent connection requests
  Stream<List<Map<String, dynamic>>> getSentRequestsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('connection_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Get pending requests count
  Stream<int> getPendingRequestsCountStream() {
    return getPendingRequestsStream().map((requests) => requests.length);
  }

  /// Check if connection request exists between users
  Future<String?> getConnectionRequestStatus(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      // Check if current user sent request
      final sentRequest = await _firestore
          .collection('connection_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: otherUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        return 'sent';
      }

      // Check if current user received request
      final receivedRequest = await _firestore
          .collection('connection_requests')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        return 'received';
      }

      return null;
    } catch (e) {
      debugPrint(' Error checking request status: $e');
      return null;
    }
  }

  /// Send connection request notification to the RECEIVER
  Future<void> _sendConnectionNotification({
    required String receiverId,
    required String senderName,
    required String requestId,
  }) async {
    try {
      // Send notification to the RECEIVER (the person receiving the request)
      await _notificationService.sendNotificationToUser(
        userId: receiverId,
        title: 'New Connection Request',
        body: '$senderName wants to connect with you',
        type: 'connection_request',
        data: {'requestId': requestId},
      );
    } catch (e) {
      debugPrint('  Error sending connection notification: $e');
    }
  }
}
