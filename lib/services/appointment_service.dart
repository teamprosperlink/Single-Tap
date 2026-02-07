import '../models/appointment_model.dart';

/// Stub service for appointment management.
class AppointmentService {
  // Singleton pattern
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  /// Create a new appointment from the given data map.
  Future<String?> createAppointment(dynamic data) async {
    return null;
  }

  /// Update the status of an appointment by its ID.
  Future<bool> updateAppointmentStatus(String businessId, String id, dynamic status) async {
    return false;
  }

  /// Watch appointments for a given business in real time.
  Stream<List<dynamic>> watchAppointments(String businessId) {
    return const Stream.empty();
  }

  /// Watch appointments for a given business filtered by date.
  Stream<List<AppointmentModel>> watchAppointmentsByDate(String businessId, DateTime date) {
    return const Stream.empty();
  }

  /// Get dates in a month that have appointments.
  Future<List<DateTime>> getAppointmentDatesInMonth(String businessId, int year, int month) async {
    return [];
  }

  /// Update an appointment with new data.
  Future<bool> updateAppointment(String businessId, String appointmentId, dynamic data) async {
    return false;
  }

  /// Cancel an appointment with optional reason.
  Future<bool> cancelAppointment(String businessId, String appointmentId, {String? reason, String? cancelledBy}) async {
    return false;
  }

  /// Delete an appointment.
  Future<bool> deleteAppointment(String businessId, String appointmentId) async {
    return false;
  }

  /// Search appointments by query string.
  Future<List<AppointmentModel>> searchAppointments(String businessId, String query) async {
    return [];
  }

  /// Get available time slots for a given date.
  Future<List<TimeSlot>> getAvailableSlots(String businessId, DateTime date, {int slotDurationMinutes = 30}) async {
    return [];
  }
}
