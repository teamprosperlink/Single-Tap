import 'package:flutter/material.dart';

/// Availability status types for different business items
enum AvailabilityStatus {
  available,
  lowStock,
  outOfStock,
  fullyBooked,
  unavailable,
  lastRoom,
  availableToday,
  nextAvailable,
}

/// Reusable availability status badge widget
/// Used across products, menu items, rooms, and services
class AvailabilityBadge extends StatelessWidget {
  final AvailabilityStatus status;
  final String? customLabel;
  final int? stockCount;
  final DateTime? nextAvailableTime;
  final bool compact;

  const AvailabilityBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.stockCount,
    this.nextAvailableTime,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();
    final label = customLabel ?? config.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: compact ? 12 : 14,
            color: config.iconColor,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case AvailabilityStatus.available:
        return _StatusConfig(
          label: 'Available',
          icon: Icons.check_circle,
          iconColor: const Color(0xFF00D67D),
          textColor: const Color(0xFF00D67D),
          backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.1),
          borderColor: const Color(0xFF00D67D).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.lowStock:
        final count = stockCount ?? 2;
        return _StatusConfig(
          label: 'Only $count left',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFFA726),
          textColor: const Color(0xFFFFA726),
          backgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.1),
          borderColor: const Color(0xFFFFA726).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.outOfStock:
        return _StatusConfig(
          label: 'Out of Stock',
          icon: Icons.cancel,
          iconColor: const Color(0xFFEF5350),
          textColor: const Color(0xFFEF5350),
          backgroundColor: const Color(0xFFEF5350).withValues(alpha: 0.1),
          borderColor: const Color(0xFFEF5350).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.fullyBooked:
        return _StatusConfig(
          label: 'Fully Booked',
          icon: Icons.event_busy,
          iconColor: const Color(0xFFEF5350),
          textColor: const Color(0xFFEF5350),
          backgroundColor: const Color(0xFFEF5350).withValues(alpha: 0.1),
          borderColor: const Color(0xFFEF5350).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.unavailable:
        return _StatusConfig(
          label: 'Unavailable',
          icon: Icons.block,
          iconColor: Colors.grey,
          textColor: Colors.grey,
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          borderColor: Colors.grey.withValues(alpha: 0.3),
        );

      case AvailabilityStatus.lastRoom:
        return _StatusConfig(
          label: 'Last Room',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFFA726),
          textColor: const Color(0xFFFFA726),
          backgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.1),
          borderColor: const Color(0xFFFFA726).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.availableToday:
        return _StatusConfig(
          label: 'Available Today',
          icon: Icons.check_circle,
          iconColor: const Color(0xFF00D67D),
          textColor: const Color(0xFF00D67D),
          backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.1),
          borderColor: const Color(0xFF00D67D).withValues(alpha: 0.3),
        );

      case AvailabilityStatus.nextAvailable:
        final timeStr = _formatNextAvailableTime();
        return _StatusConfig(
          label: 'Next: $timeStr',
          icon: Icons.schedule,
          iconColor: const Color(0xFF42A5F5),
          textColor: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
          borderColor: const Color(0xFF42A5F5).withValues(alpha: 0.3),
        );
    }
  }

  String _formatNextAvailableTime() {
    if (nextAvailableTime == null) return 'Soon';

    final now = DateTime.now();
    final diff = nextAvailableTime!.difference(now);

    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inMinutes}m';
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  _StatusConfig({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
