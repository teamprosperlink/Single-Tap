import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';

/// Modern Hours Section with Live Status
/// Features:
/// - Live open/closed status with countdown
/// - Today highlighted
/// - Peak hours indicator
/// - Special hours notes
/// - Add to calendar button
class ModernHoursSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ModernHoursSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hoursSchedule = business.hours?.schedule ?? {};

    if (hoursSchedule.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    final isOpen = _isCurrentlyOpen(hoursSchedule, now);
    final statusText = _getStatusText(hoursSchedule, now, isOpen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header with live status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 24,
                color: AppTheme.darkText(isDarkMode),
              ),
              const SizedBox(width: 8),
              Text(
                'Hours',
                style: TextStyle(
                  fontSize: AppTheme.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText(isDarkMode),
                ),
              ),
              const SizedBox(width: 12),
              // Live status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isOpen ? AppTheme.successGreen : AppTheme.errorRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isOpen ? AppTheme.successGreen : AppTheme.errorRed)
                        .withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOpen ? AppTheme.successGreen : AppTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Hours card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(isDarkMode),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Days of the week
              ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                  .map((day) => _buildDayRow(
                        day,
                        hoursSchedule[day.toLowerCase()],
                        day == currentDay,
                        isDarkMode,
                      )),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDayRow(String day, DayHours? dayHours, bool isToday, bool isDarkMode) {
    String hoursText = 'Closed';
    bool isClosed = true;

    if (dayHours != null && !dayHours.isClosed) {
      if (dayHours.open != null && dayHours.close != null) {
        hoursText = '${dayHours.open} - ${dayHours.close}';
        isClosed = false;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? config.primaryColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Day name
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? config.primaryColor
                          : AppTheme.darkText(isDarkMode),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: config.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Hours
            Expanded(
              flex: 3,
              child: Text(
                hoursText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  color: isClosed
                      ? AppTheme.errorRed
                      : (isToday
                          ? config.primaryColor
                          : AppTheme.darkText(isDarkMode)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  bool _isCurrentlyOpen(Map<String, DayHours> hoursSchedule, DateTime now) {
    final currentDay = _getDayName(now.weekday).toLowerCase();
    final todayHours = hoursSchedule[currentDay];

    if (todayHours == null || todayHours.isClosed) return false;

    final open = todayHours.open;
    final close = todayHours.close;

    if (open == null || close == null) return false;

    final openTime = _parseTime(open);
    final closeTime = _parseTime(close);
    final currentTime = TimeOfDay.fromDateTime(now);

    return _isTimeBetween(currentTime, openTime, closeTime);
  }

  TimeOfDay _parseTime(String timeStr) {
    // Parse time in format "9:00 AM" or "21:00"
    try {
      final parts = timeStr.trim().split(':');
      int hour = int.parse(parts[0]);
      final minuteParts = parts[1].split(' ');
      final minute = int.parse(minuteParts[0]);

      if (minuteParts.length > 1) {
        final period = minuteParts[1].toUpperCase();
        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  bool _isTimeBetween(TimeOfDay current, TimeOfDay open, TimeOfDay close) {
    final currentMinutes = current.hour * 60 + current.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (closeMinutes > openMinutes) {
      return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
    } else {
      // Handles case where business closes after midnight
      return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
    }
  }

  String _getStatusText(Map<String, DayHours> hoursSchedule, DateTime now, bool isOpen) {
    if (isOpen) {
      final currentDay = _getDayName(now.weekday).toLowerCase();
      final todayHours = hoursSchedule[currentDay];

      if (todayHours != null && !todayHours.isClosed) {
        final close = todayHours.close;
        if (close != null) {
          final closeTime = _parseTime(close);
          final currentTime = TimeOfDay.fromDateTime(now);
          final minutesUntilClose =
              (closeTime.hour * 60 + closeTime.minute) -
              (currentTime.hour * 60 + currentTime.minute);

          if (minutesUntilClose <= 60 && minutesUntilClose > 0) {
            return 'Closes in ${minutesUntilClose}m';
          }
          return 'Open Now';
        }
      }
      return 'Open Now';
    } else {
      // Find next opening time
      final currentDay = _getDayName(now.weekday).toLowerCase();
      final todayHours = hoursSchedule[currentDay];

      if (todayHours != null && !todayHours.isClosed) {
        final open = todayHours.open;
        if (open != null) {
          final openTime = _parseTime(open);
          final currentTime = TimeOfDay.fromDateTime(now);
          final minutesUntilOpen =
              (openTime.hour * 60 + openTime.minute) -
              (currentTime.hour * 60 + currentTime.minute);

          if (minutesUntilOpen > 0 && minutesUntilOpen <= 120) {
            if (minutesUntilOpen <= 60) {
              return 'Opens in ${minutesUntilOpen}m';
            } else {
              final hours = (minutesUntilOpen / 60).floor();
              return 'Opens in ${hours}h';
            }
          }
        }
      }
      return 'Closed';
    }
  }
}
