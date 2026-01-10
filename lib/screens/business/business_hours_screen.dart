import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';

/// Screen for managing business operating hours
class BusinessHoursScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessHoursScreen({
    super.key,
    required this.business,
  });

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  final BusinessService _businessService = BusinessService();
  bool _isSaving = false;

  // Day schedules
  late Map<String, DaySchedule> _schedules;

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _initSchedules();
  }

  void _initSchedules() {
    _schedules = {};
    final hours = widget.business.hours;

    for (final day in _dayNames) {
      final dayKey = day.toLowerCase();
      if (hours != null && hours.schedule.containsKey(dayKey)) {
        final dayHours = hours.schedule[dayKey]!;
        _schedules[day] = DaySchedule(
          isOpen: !dayHours.isClosed,
          openTime: _parseTime(dayHours.open),
          closeTime: _parseTime(dayHours.close),
        );
      } else {
        _schedules[day] = DaySchedule(
          isOpen: true,
          openTime: const TimeOfDay(hour: 9, minute: 0),
          closeTime: const TimeOfDay(hour: 18, minute: 0),
        );
      }
    }
  }

  TimeOfDay _parseTime(String? time) {
    if (time == null) return const TimeOfDay(hour: 9, minute: 0);
    final parts = time.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCurrentlyOpen = widget.business.hours?.isCurrentlyOpen ?? false;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Business Hours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSchedule,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00D67D),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF00D67D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCurrentlyOpen
                      ? [const Color(0xFF00D67D), const Color(0xFF00D67D).withValues(alpha: 0.8)]
                      : [Colors.grey[600]!, Colors.grey[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCurrentlyOpen ? Icons.store : Icons.store_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentlyOpen ? 'Currently Open' : 'Currently Closed',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCurrentStatusMessage(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Schedule Title
            Text(
              'Weekly Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Day schedules
            ..._dayNames.map((day) => _buildDayScheduleCard(day, isDarkMode)),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Set All Open',
                    isDarkMode: isDarkMode,
                    onTap: () => _setAllDays(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.nights_stay_outlined,
                    label: 'Set All Closed',
                    isDarkMode: isDarkMode,
                    onTap: () => _setAllDays(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.work_outline,
                    label: 'Weekdays Only',
                    isDarkMode: isDarkMode,
                    onTap: () => _setWeekdaysOnly(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.schedule,
                    label: '24/7',
                    isDarkMode: isDarkMode,
                    onTap: () => _set24x7(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getCurrentStatusMessage() {
    final now = DateTime.now();
    final dayName = _dayNames[now.weekday - 1];
    final schedule = _schedules[dayName];

    if (schedule == null || !schedule.isOpen) {
      return 'Closed today';
    }

    return 'Open ${_formatTimeDisplay(schedule.openTime)} - ${_formatTimeDisplay(schedule.closeTime)}';
  }

  Widget _buildDayScheduleCard(String day, bool isDarkMode) {
    final schedule = _schedules[day]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: schedule.isOpen
            ? Border.all(color: const Color(0xFF00D67D).withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day name
          SizedBox(
            width: 100,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),

          // Open/Close toggle
          Switch(
            value: schedule.isOpen,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              setState(() {
                _schedules[day] = schedule.copyWith(isOpen: value);
              });
            },
            activeTrackColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
            activeThumbColor: const Color(0xFF00D67D),
          ),

          const Spacer(),

          // Time selection
          if (schedule.isOpen)
            Row(
              children: [
                _buildTimeButton(
                  time: schedule.openTime,
                  isDarkMode: isDarkMode,
                  onTap: () => _selectTime(day, true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '-',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ),
                _buildTimeButton(
                  time: schedule.closeTime,
                  isDarkMode: isDarkMode,
                  onTap: () => _selectTime(day, false),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Closed',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeButton({
    required TimeOfDay time,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00D67D).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00D67D).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          _formatTimeDisplay(time),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF00D67D),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF00D67D),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(String day, bool isOpenTime) async {
    final schedule = _schedules[day]!;
    final initialTime = isOpenTime ? schedule.openTime : schedule.closeTime;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF00D67D),
                ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      setState(() {
        if (isOpenTime) {
          _schedules[day] = schedule.copyWith(openTime: selectedTime);
        } else {
          _schedules[day] = schedule.copyWith(closeTime: selectedTime);
        }
      });
    }
  }

  void _setAllDays(bool isOpen) {
    setState(() {
      for (final day in _dayNames) {
        _schedules[day] = _schedules[day]!.copyWith(isOpen: isOpen);
      }
    });
  }

  void _setWeekdaysOnly() {
    setState(() {
      for (int i = 0; i < _dayNames.length; i++) {
        final isWeekday = i < 5; // Mon-Fri
        _schedules[_dayNames[i]] = _schedules[_dayNames[i]]!.copyWith(isOpen: isWeekday);
      }
    });
  }

  void _set24x7() {
    setState(() {
      for (final day in _dayNames) {
        _schedules[day] = DaySchedule(
          isOpen: true,
          openTime: const TimeOfDay(hour: 0, minute: 0),
          closeTime: const TimeOfDay(hour: 23, minute: 59),
        );
      }
    });
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);

    final scheduleMap = <String, DayHours>{};
    for (final day in _dayNames) {
      final schedule = _schedules[day]!;
      scheduleMap[day.toLowerCase()] = DayHours(
        isClosed: !schedule.isOpen,
        open: _formatTime(schedule.openTime),
        close: _formatTime(schedule.closeTime),
      );
    }

    final hours = BusinessHours(schedule: scheduleMap);
    final updatedBusiness = widget.business.copyWith(hours: hours);
    final success = await _businessService.updateBusiness(
      widget.business.id,
      updatedBusiness,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Business hours saved' : 'Failed to save hours'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context, true);
      }
    }
  }
}

class DaySchedule {
  final bool isOpen;
  final TimeOfDay openTime;
  final TimeOfDay closeTime;

  DaySchedule({
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  DaySchedule copyWith({
    bool? isOpen,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
  }) {
    return DaySchedule(
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}
