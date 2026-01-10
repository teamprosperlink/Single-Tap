import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/inquiry_model.dart';

/// Service for managing professional inquiries
class InquiryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final InquiryService _instance = InquiryService._internal();
  factory InquiryService() => _instance;
  InquiryService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // INQUIRY CRUD OPERATIONS

  /// Send an inquiry to a professional
  Future<String?> sendInquiry({
    required String professionalId,
    required String message,
    String? serviceId,
    String? serviceName,
    String? projectDescription,
    String? budget,
    String? timeline,
    List<String>? attachments,
  }) async {
    if (_currentUserId == null) return null;

    try {
      // Get client info
      final clientDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      final clientData = clientDoc.data() ?? {};

      // Get professional info
      final proDoc = await _firestore
          .collection('users')
          .doc(professionalId)
          .get();
      final proData = proDoc.data() ?? {};

      final inquiry = InquiryModel(
        id: '',
        clientId: _currentUserId!,
        clientName: clientData['name'] ?? 'Anonymous',
        clientPhoto: clientData['profileImageUrl'] ?? clientData['photoUrl'],
        clientEmail: clientData['email'],
        professionalId: professionalId,
        professionalName:
            proData['name'] ??
            proData['professionalProfile']?['businessName'] ??
            'Professional',
        serviceId: serviceId,
        serviceName: serviceName,
        message: message,
        projectDescription: projectDescription,
        budget: budget,
        timeline: timeline,
        attachments: attachments ?? [],
      );

      // Add inquiry
      final docRef = await _firestore
          .collection('inquiries')
          .add(inquiry.toMap());

      // Update professional's inquiry count
      await _firestore
          .collection('professional_stats')
          .doc(professionalId)
          .set({
            'totalInquiries': FieldValue.increment(1),
            'pendingInquiries': FieldValue.increment(1),
            'lastInquiryAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update service inquiry count if applicable
      if (serviceId != null) {
        await _firestore.collection('services').doc(serviceId).update({
          'inquiries': FieldValue.increment(1),
        });
      }

      // TODO: Send push notification to professional

      return docRef.id;
    } catch (e) {
      debugPrint('Error sending inquiry: $e');
      return null;
    }
  }

  /// Respond to an inquiry (professional only)
  Future<bool> respondToInquiry(
    String inquiryId, {
    required String response,
    String? quotedPrice,
    String? estimatedDelivery,
    InquiryStatus? newStatus,
  }) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('inquiries').doc(inquiryId).get();
      if (!doc.exists) return false;

      final inquiry = InquiryModel.fromFirestore(doc);
      if (inquiry.professionalId != _currentUserId) return false;

      // Create response message
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      final userData = userDoc.data() ?? {};

      final newMessage = InquiryMessage(
        senderId: _currentUserId!,
        senderName: userData['name'] ?? 'Professional',
        message: response,
        isFromProfessional: true,
      );

      await _firestore.collection('inquiries').doc(inquiryId).update({
        'response': response,
        'quotedPrice': quotedPrice,
        'estimatedDelivery': estimatedDelivery,
        'status': (newStatus ?? InquiryStatus.responded).name,
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'messages': FieldValue.arrayUnion([newMessage.toMap()]),
      });

      // Update stats
      if (inquiry.status == InquiryStatus.pending) {
        await _firestore
            .collection('professional_stats')
            .doc(_currentUserId)
            .update({'pendingInquiries': FieldValue.increment(-1)});
      }

      // TODO: Send push notification to client

      return true;
    } catch (e) {
      debugPrint('Error responding to inquiry: $e');
      return false;
    }
  }

  /// Add a message to inquiry thread
  Future<bool> addMessage(
    String inquiryId,
    String message, {
    List<String>? attachments,
  }) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('inquiries').doc(inquiryId).get();
      if (!doc.exists) return false;

      final inquiry = InquiryModel.fromFirestore(doc);
      final isFromProfessional = inquiry.professionalId == _currentUserId;

      if (inquiry.clientId != _currentUserId && !isFromProfessional) {
        return false; // Not a participant
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      final userData = userDoc.data() ?? {};

      final newMessage = InquiryMessage(
        senderId: _currentUserId!,
        senderName: userData['name'] ?? 'User',
        message: message,
        attachments: attachments ?? [],
        isFromProfessional: isFromProfessional,
      );

      await _firestore.collection('inquiries').doc(inquiryId).update({
        'messages': FieldValue.arrayUnion([newMessage.toMap()]),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'status': InquiryStatus.negotiating.name,
      });

      return true;
    } catch (e) {
      debugPrint('Error adding message: $e');
      return false;
    }
  }

  /// Update inquiry status
  Future<bool> updateStatus(String inquiryId, InquiryStatus status) async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore.collection('inquiries').doc(inquiryId).get();
      if (!doc.exists) return false;

      final inquiry = InquiryModel.fromFirestore(doc);
      if (inquiry.professionalId != _currentUserId &&
          inquiry.clientId != _currentUserId) {
        return false;
      }

      final updates = <String, dynamic>{
        'status': status.name,
        'lastActivityAt': FieldValue.serverTimestamp(),
      };

      if (status == InquiryStatus.completed) {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('inquiries').doc(inquiryId).update(updates);

      // Update stats for status changes
      if (inquiry.professionalId == _currentUserId) {
        final statsUpdates = <String, dynamic>{};

        if (inquiry.status == InquiryStatus.pending &&
            status != InquiryStatus.pending) {
          statsUpdates['pendingInquiries'] = FieldValue.increment(-1);
        }

        if (status == InquiryStatus.completed) {
          statsUpdates['completedInquiries'] = FieldValue.increment(1);
        }

        if (statsUpdates.isNotEmpty) {
          await _firestore
              .collection('professional_stats')
              .doc(_currentUserId)
              .update(statsUpdates);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating status: $e');
      return false;
    }
  }

  /// Mark inquiry as read
  Future<bool> markAsRead(String inquiryId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('inquiries').doc(inquiryId).update({
        'isRead': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error marking as read: $e');
      return false;
    }
  }

  /// Archive an inquiry
  Future<bool> archiveInquiry(String inquiryId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('inquiries').doc(inquiryId).update({
        'isArchived': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error archiving: $e');
      return false;
    }
  }

  // INQUIRY QUERIES

  /// Get inquiries for professional (received)
  Future<List<InquiryModel>> getReceivedInquiries({
    InquiryStatus? status,
    int limit = 20,
    bool includeArchived = false,
  }) async {
    if (_currentUserId == null) return [];

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('inquiries')
          .where('professionalId', isEqualTo: _currentUserId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }

      query = query.orderBy('lastActivityAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => InquiryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting received inquiries: $e');
      return [];
    }
  }

  /// Stream received inquiries
  Stream<List<InquiryModel>> watchReceivedInquiries({
    bool includeArchived = false,
  }) {
    if (_currentUserId == null) return Stream.value([]);

    Query<Map<String, dynamic>> query = _firestore
        .collection('inquiries')
        .where('professionalId', isEqualTo: _currentUserId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    return query
        .orderBy('lastActivityAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InquiryModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get inquiries sent by client
  Future<List<InquiryModel>> getSentInquiries({int limit = 20}) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('inquiries')
          .where('clientId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => InquiryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting sent inquiries: $e');
      return [];
    }
  }

  /// Stream sent inquiries
  Stream<List<InquiryModel>> watchSentInquiries() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('inquiries')
        .where('clientId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InquiryModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get single inquiry
  Future<InquiryModel?> getInquiry(String inquiryId) async {
    try {
      final doc = await _firestore.collection('inquiries').doc(inquiryId).get();
      if (!doc.exists) return null;
      return InquiryModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting inquiry: $e');
      return null;
    }
  }

  /// Stream single inquiry
  Stream<InquiryModel?> watchInquiry(String inquiryId) {
    return _firestore
        .collection('inquiries')
        .doc(inquiryId)
        .snapshots()
        .map((doc) => doc.exists ? InquiryModel.fromFirestore(doc) : null);
  }

  /// Get pending inquiry count for professional
  Future<int> getPendingCount() async {
    if (_currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('inquiries')
          .where('professionalId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: InquiryStatus.pending.name)
          .where('isArchived', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }

  /// Stream pending inquiry count
  Stream<int> watchPendingCount() {
    if (_currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('inquiries')
        .where('professionalId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: InquiryStatus.pending.name)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
