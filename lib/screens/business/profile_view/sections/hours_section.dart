import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying business operating hours
class HoursSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const HoursSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hours = business.hours;

    if (hours == null) {
      return const SizedBox.shrink();
    }

    final isOpen = hours.isCurrentlyOpen;
    final today = _getTodayName();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isOpen ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.access_time,
              color: isOpen ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Text(
                'Hours',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOpen ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOpen ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          subtitle: _buildTodayHours(hours, today, isDarkMode),
          children: [
            _buildWeeklySchedule(hours, today, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHours(BusinessHours hours, String today, bool isDarkMode) {
    final dayHours = hours.schedule[today];
    final hoursText = dayHours?.formatted ?? 'Not set';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Today: $hoursText',
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildWeeklySchedule(
      BusinessHours hours, String today, bool isDarkMode) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];

    final dayLabels = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };

    return Column(
      children: days.map((day) {
        final dayHours = hours.schedule[day];
        final isToday = day == today;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  dayLabels[day]!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                    color: isToday
                        ? config.primaryColor
                        : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  dayHours?.formatted ?? 'Not set',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                    color: dayHours?.isClosed == true
                        ? Colors.red
                        : isToday
                            ? config.primaryColor
                            : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: config.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: config.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getTodayName() {
    final now = DateTime.now();
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return days[now.weekday - 1];
  }
}
