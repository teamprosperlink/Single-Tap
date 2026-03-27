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

      // Get sender info — networking_profiles first, fallback to users
      final senderNetDoc = await _firestore
          .collection('networking_profiles')
          .doc(senderId)
          .get();
      final senderData = (senderNetDoc.exists && senderNetDoc.data() != null)
          ? senderNetDoc.data()!
          : (await _firestore.collection('users').doc(senderId).get()).data() ??
              {};
      final senderName = _resolveName(senderData, 'Someone');

      // Get receiver info — networking_profiles first, fallback to users
      final receiverNetDoc = await _firestore
          .collection('networking_profiles')
          .doc(receiverId)
          .get();
      final receiverData =
          (receiverNetDoc.exists && receiverNetDoc.data() != null)
          ? receiverNetDoc.data()!
          : (await _firestore.collection('users').doc(receiverId).get()).data() ??
              {};
      final receiverName = _resolveName(receiverData, 'Unknown');

      // Create connection request
      final requestRef = await _firestore.collection('connection_requests').add(
        {
          'senderId': senderId,
          'senderName': senderName,
          'senderPhoto': senderData['photoUrl'],
          'senderAge': senderData['age'] ?? _calcAgeFromDob(senderData['dateOfBirth']),
          'senderOccupation': _resolveOccupation(senderData),
          'senderLatitude': senderData['latitude'],
          'senderLongitude': senderData['longitude'],
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverPhoto': receiverData['photoUrl'],
          'receiverAge': receiverData['age'] ?? _calcAgeFromDob(receiverData['dateOfBirth']),
          'receiverOccupation': _resolveOccupation(receiverData),
          'receiverLatitude': receiverData['latitude'],
          'receiverLongitude': receiverData['longitude'],
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
      final senderId = requestData['senderId'] as String?;
      final receiverId = requestData['receiverId'] as String?;

      if (senderId == null || receiverId == null) {
        return {'success': false, 'message': 'Invalid request data'};
      }

      // Verify current user is either sender or receiver
      if (receiverId != currentUserId && senderId != currentUserId) {
        return {'success': false, 'message': 'Unauthorized'};
      }

      // Update request status
      await requestDoc.reference.update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create bidirectional connection
      await _createConnection(senderId, receiverId);

      // Get current user's name — networking_profiles first, fallback to users
      final currentNetDoc = await _firestore
          .collection('networking_profiles')
          .doc(currentUserId)
          .get();
      final currentUserName = (currentNetDoc.exists && currentNetDoc.data() != null)
          ? _resolveName(currentNetDoc.data()!, 'Someone')
          : (await _firestore.collection('users').doc(currentUserId).get())
                  .data()?['name'] ??
              'Someone';

      // Send notification to the OTHER user
      final otherUserId = currentUserId == senderId ? receiverId : senderId;
      await _notificationService.sendNotificationToUser(
        userId: otherUserId,
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
      final receiverId = requestData['receiverId'] as String?;

      // Verify current user is the receiver
      if (receiverId == null || receiverId != currentUserId) {
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
      final senderId = requestData['senderId'] as String?;

      // Verify current user is the sender
      if (senderId == null || senderId != currentUserId) {
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

  /// Create a connection between two users (stored in networking_profiles)
  Future<void> _createConnection(String user1Id, String user2Id) async {
    final batch = _firestore.batch();

    // Add to user1's networking connections
    batch.set(_firestore.collection('networking_profiles').doc(user1Id), {
      'connections': FieldValue.arrayUnion([user2Id]),
      'connectionCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Add to user2's networking connections
    batch.set(_firestore.collection('networking_profiles').doc(user2Id), {
      'connections': FieldValue.arrayUnion([user1Id]),
      'connectionCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

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

      // Remove from current user's networking connections
      batch.set(_firestore.collection('networking_profiles').doc(currentUserId), {
        'connections': FieldValue.arrayRemove([userId]),
        'connectionCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      // Remove from other user's networking connections
      batch.set(_firestore.collection('networking_profiles').doc(userId), {
        'connections': FieldValue.arrayRemove([currentUserId]),
        'connectionCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      await batch.commit();

      // Also delete the connection_requests document(s) so they don't appear in My Network
      // Check both directions: current user as sender or receiver
      try {
        final asSender = await _firestore
            .collection('connection_requests')
            .where('senderId', isEqualTo: currentUserId)
            .where('receiverId', isEqualTo: userId)
            .get();
        for (final doc in asSender.docs) {
          await doc.reference.delete();
        }

        final asReceiver = await _firestore
            .collection('connection_requests')
            .where('senderId', isEqualTo: userId)
            .where('receiverId', isEqualTo: currentUserId)
            .get();
        for (final doc in asReceiver.docs) {
          await doc.reference.delete();
        }
        debugPrint('ConnectionService: Deleted connection_requests for $userId');
      } catch (e) {
        debugPrint('ConnectionService: Error deleting connection_requests: $e');
      }

      debugPrint('ConnectionService: Connection removed with user $userId');
      return {'success': true, 'message': 'Connection removed'};
    } catch (e) {
      debugPrint('ConnectionService: Error removing connection: $e');
      return {'success': false, 'message': 'Failed to remove connection: $e'};
    }
  }

  /// Check if two users are connected (via networking_profiles)
  Future<bool> areUsersConnected(String user1Id, String user2Id) async {
    try {
      final doc = await _firestore
          .collection('networking_profiles')
          .doc(user1Id)
          .get();
      final connections = List<String>.from(
        doc.data()?['connections'] ?? [],
      );
      return connections.contains(user2Id);
    } catch (e) {
      debugPrint('  Error checking connection status: $e');
      return false;
    }
  }

  /// Get user's networking connections list (accepted connections)
  Future<List<String>> getUserConnections() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('ConnectionService: getUserConnections - no current user');
      return [];
    }

    final Set<String> connectedIds = {};

    // Run all 3 sources in PARALLEL for speed
    final results = await Future.wait([
      // Source 1: networking_profiles connections array
      _firestore.collection('networking_profiles').doc(currentUserId).get().then((doc) {
        return List<String>.from(doc.data()?['connections'] ?? []);
      }).catchError((e) {
        debugPrint('ConnectionService: Error reading networking_profiles connections: $e');
        return <String>[];
      }),
      // Source 2: connection_requests where current user is RECEIVER and status is 'accepted'
      _firestore.collection('connection_requests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get().then((snap) {
        return snap.docs
            .map((d) => d.data()['senderId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();
      }).catchError((e) {
        debugPrint('ConnectionService: Error querying received accepted requests: $e');
        return <String>[];
      }),
      // Source 3: connection_requests where current user is SENDER and status is 'accepted'
      _firestore.collection('connection_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get().then((snap) {
        return snap.docs
            .map((d) => d.data()['receiverId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();
      }).catchError((e) {
        debugPrint('ConnectionService: Error querying sent accepted requests: $e');
        return <String>[];
      }),
    ]);

    for (final list in results) {
      connectedIds.addAll(list);
    }

    debugPrint('ConnectionService: Total unique connections: ${connectedIds.length}');
    return connectedIds.toList();
  }

  /// Get user IDs who have pending requests (both sent and received)
  Future<List<String>> getPendingRequestUserIds() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final Set<String> pendingIds = {};

    // Run both queries in PARALLEL for speed
    final results = await Future.wait([
      // Pending requests sent BY current user
      _firestore.collection('connection_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get().then((snap) {
        return snap.docs
            .map((d) => d.data()['receiverId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();
      }).catchError((e) {
        debugPrint('ConnectionService: Error querying sent pending requests: $e');
        return <String>[];
      }),
      // Pending requests received BY current user
      _firestore.collection('connection_requests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get().then((snap) {
        return snap.docs
            .map((d) => d.data()['senderId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();
      }).catchError((e) {
        debugPrint('ConnectionService: Error querying received pending requests: $e');
        return <String>[];
      }),
    ]);

    for (final list in results) {
      pendingIds.addAll(list);
    }

    debugPrint('ConnectionService: Total pending request users: ${pendingIds.length}');
    return pendingIds.toList();
  }

  /// Get networking connections count
  Future<int> getConnectionsCount() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    try {
      final doc = await _firestore
          .collection('networking_profiles')
          .doc(currentUserId)
          .get();
      return doc.data()?['connectionCount'] ?? 0;
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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['requestType'] = 'received';
            return data;
          }).toList();
          // Sort by createdAt descending (client-side to avoid index)
          list.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          return list;
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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['requestType'] = 'sent';
            return data;
          }).toList();
          list.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Get ALL pending requests (both received and sent) combined
  /// Get pending requests count (received only)
  Stream<int> getPendingRequestsCountStream() {
    return getPendingRequestsStream().map((requests) => requests.length);
  }

  /// Get accepted connections where current user is receiver
  Stream<List<Map<String, dynamic>>> getAcceptedAsReceiverStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('connection_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Get accepted connections where current user is sender
  Stream<List<Map<String, dynamic>>> getAcceptedAsSenderStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('connection_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
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

  /// Resolve user display name from Firestore data, checking multiple fields
  String _resolveName(Map<String, dynamic> data, String fallback) {
    final name = data['name'] as String?;
    if (name != null && name.isNotEmpty && name != 'User' && name != 'Unknown') {
      return name;
    }
    final displayName = data['displayName'] as String?;
    if (displayName != null && displayName.isNotEmpty && displayName != 'User' && displayName != 'Unknown') {
      return displayName;
    }
    final phone = data['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return fallback;
  }

  /// Calculate age from dateOfBirth if age field is null
  int? _calcAgeFromDob(dynamic dob) {
    if (dob == null) return null;
    try {
      final DateTime birthDate;
      if (dob is Timestamp) {
        birthDate = dob.toDate();
      } else if (dob is String && dob.isNotEmpty) {
        birthDate = DateTime.parse(dob);
      } else {
        return null;
      }
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  /// Resolve occupation from multiple possible fields
  String? _resolveOccupation(Map<String, dynamic> data) {
    final occupation = data['occupation'] as String?;
    if (occupation != null && occupation.isNotEmpty) return occupation;
    final profession = data['profession'] as String?;
    if (profession != null && profession.isNotEmpty) return profession;
    final bizProfile = data['businessProfile'] as Map<String, dynamic>?;
    if (bizProfile != null) {
      final label = bizProfile['softLabel'] as String?;
      if (label != null && label.isNotEmpty) return label;
    }
    final subcat = data['networkingSubcategory'] as String?;
    if (subcat != null && subcat.isNotEmpty) return subcat;
    return null;
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
