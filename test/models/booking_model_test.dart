import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/booking_model.dart';

void main() {
  group('BookingStatus', () {
    test('fromString parses all statuses', () {
      expect(BookingStatus.fromString('pending'), BookingStatus.pending);
      expect(BookingStatus.fromString('confirmed'), BookingStatus.confirmed);
      expect(BookingStatus.fromString('completed'), BookingStatus.completed);
      expect(BookingStatus.fromString('cancelled'), BookingStatus.cancelled);
    });

    test('fromString defaults to pending', () {
      expect(BookingStatus.fromString(null), BookingStatus.pending);
      expect(BookingStatus.fromString('unknown'), BookingStatus.pending);
    });
  });

  group('BookingModel - formattedDate', () {
    BookingModel makeBooking({required DateTime bookingDate}) {
      return BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: bookingDate,
      );
    }

    test('formats January correctly', () {
      final booking = makeBooking(bookingDate: DateTime(2024, 1, 15));
      expect(booking.formattedDate, 'Jan 15, 2024');
    });

    test('formats December correctly', () {
      final booking = makeBooking(bookingDate: DateTime(2024, 12, 25));
      expect(booking.formattedDate, 'Dec 25, 2024');
    });

    test('formats single-digit day', () {
      final booking = makeBooking(bookingDate: DateTime(2024, 3, 5));
      expect(booking.formattedDate, 'Mar 5, 2024');
    });
  });

  group('BookingModel - statusLabel', () {
    BookingModel makeBooking({BookingStatus status = BookingStatus.pending}) {
      return BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        status: status,
      );
    }

    test('returns correct labels for all statuses', () {
      expect(makeBooking(status: BookingStatus.pending).statusLabel, 'Pending');
      expect(
        makeBooking(status: BookingStatus.confirmed).statusLabel,
        'Confirmed',
      );
      expect(
        makeBooking(status: BookingStatus.completed).statusLabel,
        'Completed',
      );
      expect(
        makeBooking(status: BookingStatus.cancelled).statusLabel,
        'Cancelled',
      );
    });
  });

  group('BookingModel - timeAgo', () {
    test('just now for less than 1 minute', () {
      final booking = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now(),
      );
      expect(booking.timeAgo, 'Just now');
    });

    test('minutes ago', () {
      final booking = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(booking.timeAgo, '30m ago');
    });

    test('hours ago', () {
      final booking = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(booking.timeAgo, '5h ago');
    });

    test('days ago', () {
      final booking = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(booking.timeAgo, '3d ago');
    });

    test('falls back to formattedDate after 7 days', () {
      final booking = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 6, 15),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      // Should return formattedDate (Jun 15, 2024) instead of "10d ago"
      expect(booking.timeAgo, booking.formattedDate);
    });
  });

  group('BookingModel - copyWith', () {
    test('preserves unchanged fields', () {
      final original = BookingModel(
        id: 'b-1',
        customerId: 'c-1',
        customerName: 'Customer',
        businessOwnerId: 'o-1',
        businessName: 'Business',
        bookingDate: DateTime(2024, 1, 1),
        status: BookingStatus.pending,
        notes: 'Some notes',
      );
      final copy = original.copyWith(status: BookingStatus.confirmed);
      expect(copy.status, BookingStatus.confirmed);
      expect(copy.customerName, 'Customer');
      expect(copy.notes, 'Some notes');
      expect(copy.id, 'b-1');
    });
  });
}
