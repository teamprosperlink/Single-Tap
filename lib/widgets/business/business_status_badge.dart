import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/booking_model.dart';

/// Unified status badge replacing duplicate implementations across
/// bookings, catalog, and customer-facing screens.
class BusinessStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const BusinessStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  /// Maps a [BookingStatus] to an appropriate color and label.
  ///
  /// Owner view (default):
  ///   pending   -> warningStatus  / "Pending"
  ///   confirmed -> successStatus  / "Confirmed"
  ///   completed -> primaryAction  / "Completed"
  ///   cancelled -> errorStatus    / "Cancelled"
  ///
  /// Customer view uses the same mapping — the [isOwnerView] flag is
  /// reserved for future label customisation (e.g. "Awaiting Response"
  /// instead of "Pending").
  factory BusinessStatusBadge.fromBookingStatus(
    BookingStatus status, {
    bool isOwnerView = true,
  }) {
    final Color color;
    final String label;

    switch (status) {
      case BookingStatus.pending:
        color = AppTheme.warningStatus;
        label = isOwnerView ? 'Pending' : 'Pending';
      case BookingStatus.confirmed:
        color = AppTheme.successStatus;
        label = 'Confirmed';
      case BookingStatus.completed:
        color = AppTheme.primaryAction;
        label = 'Completed';
      case BookingStatus.cancelled:
        color = AppTheme.errorStatus;
        label = 'Cancelled';
    }

    return BusinessStatusBadge(label: label, color: color);
  }

  /// Availability badge for catalog items.
  ///
  /// [isAvailable] true  -> successStatus / "Active"
  /// [isAvailable] false -> errorStatus   / "Sold Out"
  factory BusinessStatusBadge.fromAvailability(bool isAvailable) {
    return BusinessStatusBadge(
      label: isAvailable ? 'Active' : 'Sold Out',
      color: isAvailable ? AppTheme.successStatus : AppTheme.errorStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
