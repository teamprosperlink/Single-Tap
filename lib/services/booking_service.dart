import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _bookingsRef => _firestore.collection('bookings');

  String? get _currentUserId => _auth.currentUser?.uid;

  // ── Create ──

  Future<String?> createBooking(BookingModel booking) async {
    try {
      final doc = await _bookingsRef.add(booking.toMap());

      // Notify business owner
      await NotificationService().sendNotificationToUser(
        userId: booking.businessOwnerId,
        title: 'New Booking Request',
        body: '${booking.customerName} wants to book ${booking.serviceName ?? "your service"}',
        type: 'booking',
        data: {'bookingId': doc.id},
      );

      return doc.id;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      return null;
    }
  }

  // ── Update Status ──

  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus, {
    String? cancelReason,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cancelReason != null) {
        updates['cancelReason'] = cancelReason;
      }

      await _bookingsRef.doc(bookingId).update(updates);

      // Send notification
      final doc = await _bookingsRef.doc(bookingId).get();
      if (doc.exists) {
        final booking = BookingModel.fromFirestore(doc);
        final isOwnerAction = _currentUserId == booking.businessOwnerId;
        final targetUserId =
            isOwnerAction ? booking.customerId : booking.businessOwnerId;

        String title;
        String body;
        switch (newStatus) {
          case BookingStatus.confirmed:
            title = 'Booking Confirmed';
            body =
                '${booking.businessName} confirmed your booking for ${booking.serviceName ?? "service"}';
          case BookingStatus.completed:
            title = 'Booking Completed';
            body =
                'Your booking at ${booking.businessName} has been marked complete';
          case BookingStatus.cancelled:
            title = 'Booking Cancelled';
            body = isOwnerAction
                ? '${booking.businessName} cancelled your booking'
                : '${booking.customerName} cancelled their booking';
          case BookingStatus.pending:
            title = 'Booking Update';
            body = 'Your booking status has been updated';
        }

        await NotificationService().sendNotificationToUser(
          userId: targetUserId,
          title: title,
          body: body,
          type: 'booking',
          data: {'bookingId': bookingId},
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  // ── Streams ──

  Stream<List<BookingModel>> streamOwnerBookings(
    String ownerId, {
    BookingStatus? filter,
    List<BookingStatus>? filters,
  }) {
    Query query = _bookingsRef
        .where('businessOwnerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(100);

    if (filter != null) {
      query = query.where('status', isEqualTo: filter.name);
    } else if (filters != null && filters.isNotEmpty) {
      query = query.where('status',
          whereIn: filters.map((f) => f.name).toList());
    }

    return query.snapshots().map((snap) => snap.docs
        .map((doc) => BookingModel.fromFirestore(doc))
        .toList())
        .transform(StreamTransformer<List<BookingModel>,
            List<BookingModel>>.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (error, stackTrace, sink) {
            debugPrint('Error streaming bookings: $error');
            sink.add(<BookingModel>[]);
          },
        ));
  }

  Stream<List<BookingModel>> streamCustomerBookings(String customerId) {
    return _bookingsRef
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList())
        .transform(StreamTransformer<List<BookingModel>,
            List<BookingModel>>.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (error, stackTrace, sink) {
            debugPrint('Error streaming customer bookings: $error');
            sink.add(<BookingModel>[]);
          },
        ));
  }

  // ── Queries ──

  Future<List<BookingModel>> getBookingsByDate(
      String ownerId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snap = await _bookingsRef
          .where('businessOwnerId', isEqualTo: ownerId)
          .where('bookingDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('bookingDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return snap.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting bookings by date: $e');
      return [];
    }
  }

  Future<int> getPendingCount(String ownerId) async {
    try {
      final snap = await _bookingsRef
          .where('businessOwnerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }
}
