import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../services/account_type_service.dart';
import '../../../config/app_theme.dart';

class BusinessHoursEdit extends StatefulWidget {
  final BusinessHours hours;

  const BusinessHoursEdit({super.key, required this.hours});

  @override
  State<BusinessHoursEdit> createState() => _BusinessHoursEditState();
}

class _BusinessHoursEditState extends State<BusinessHoursEdit> {
  late Map<String, DayHours> _schedule;
  bool _isLoading = false;

  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const _dayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _schedule = Map<String, DayHours>.from(widget.hours.schedule);
    // Ensure all days exist
    for (final day in _days) {
      _schedule.putIfAbsent(day, () => DayHours(isClosed: true));
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final hours = BusinessHours(schedule: _schedule);
      final success = await AccountTypeService()
          .updateBusinessFields({'hours': hours.toMap()});

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hours updated'),
            backgroundColor: AppTheme.successStatus,
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(String day, bool isOpen) async {
    final current = _schedule[day];
    final initialTime = _parseTimeOfDay(
        isOpen ? current?.open : current?.close, isOpen ? 9 : 18);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      final existing = _schedule[day] ?? DayHours();
      _schedule[day] = DayHours(
        open: isOpen ? formatted : existing.open,
        close: isOpen ? existing.close : formatted,
        isClosed: false,
      );
    });
  }

  TimeOfDay _parseTimeOfDay(String? time, int defaultHour) {
    if (time == null) return TimeOfDay(hour: defaultHour, minute: 0);
    final parts = time.split(':');
    if (parts.length != 2) return TimeOfDay(hour: defaultHour, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? defaultHour,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.backgroundColor(isDark);
    final cardColor = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Business Hours'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.primaryAction, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final day = _days[index];
          final hours = _schedule[day] ?? DayHours(isClosed: true);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Day name
                SizedBox(
                  width: 90,
                  child: Text(
                    _dayLabels[day] ?? day,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Closed toggle
                Switch(
                  value: !hours.isClosed,
                  onChanged: (open) {
                    setState(() {
                      _schedule[day] = open
                          ? DayHours(open: '09:00', close: '18:00')
                          : DayHours(isClosed: true);
                    });
                  },
                  activeThumbColor: AppTheme.primaryAction,
                ),
                const SizedBox(width: 8),
                // Time display
                if (hours.isClosed)
                  Text('Closed',
                      style: TextStyle(color: subtitleColor, fontSize: 14))
                else
                  Expanded(
                    child: Row(
                      children: [
                        _timeChip(hours.open ?? '09:00', isDark,
                            () => _pickTime(day, true)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('-',
                              style: TextStyle(color: subtitleColor)),
                        ),
                        _timeChip(hours.close ?? '18:00', isDark,
                            () => _pickTime(day, false)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _timeChip(String time, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: AppTheme.textPrimary(isDark),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
