import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/appointment_model.dart';
import '../../../models/business_model.dart';
import '../../../services/appointment_service.dart';
import '../../../widgets/business/business_widgets.dart';
import '../../../widgets/business/enhanced_empty_state.dart';
import 'appointment_form_screen.dart';

/// Appointments tab for managing service-based business appointments
class AppointmentsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const AppointmentsTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  final AppointmentService _appointmentService = AppointmentService();
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All';
  bool _isCalendarExpanded = true;

  final List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Appointments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: Icon(
              _isCalendarExpanded
                  ? Icons.calendar_view_day
                  : Icons.calendar_month,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _isCalendarExpanded = !_isCalendarExpanded);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar section
          _buildCalendarSection(isDarkMode),

          // Filter chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: BusinessFilterBar(
              chips: _filters.map((filter) {
                return BusinessFilterChip(
                  label: filter,
                  isSelected: _selectedFilter == filter,
                  onTap: () => setState(() => _selectedFilter = filter),
                );
              }).toList(),
            ),
          ),

          // Appointments list
          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream: _appointmentService.watchAppointmentsByDate(
                widget.business.id,
                _selectedDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                  );
                }

                final allAppointments = snapshot.data ?? [];
                final appointments = _filterAppointments(allAppointments);

                if (allAppointments.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                if (appointments.isEmpty) {
                  return _buildNoResultsState(isDarkMode);
                }

                return RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  color: const Color(0xFF00D67D),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      return _AppointmentCard(
                        appointment: appointment,
                        isDarkMode: isDarkMode,
                        onTap: () => _showAppointmentDetails(appointment),
                        onStatusChange: (status) => _updateStatus(appointment, status),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAppointment(),
        backgroundColor: const Color(0xFF00D67D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
      ),
    );
  }

  Widget _buildCalendarSection(bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isCalendarExpanded ? 340 : 80,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: _isCalendarExpanded
            ? _buildFullCalendar(isDarkMode)
            : _buildCompactDateSelector(isDarkMode),
      ),
    );
  }

  Widget _buildFullCalendar(bool isDarkMode) {
    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                _getMonthYearString(_selectedDate),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: FutureBuilder<List<DateTime>>(
            future: _appointmentService.getAppointmentDatesInMonth(
              widget.business.id,
              _selectedDate.year,
              _selectedDate.month,
            ),
            builder: (context, snapshot) {
              final appointmentDates = snapshot.data ?? [];
              return _buildCalendarGrid(isDarkMode, appointmentDates);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDarkMode, List<DateTime> appointmentDates) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final dayOffset = index - firstWeekday;
        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox();
        }

        final day = dayOffset + 1;
        final date = DateTime(_selectedDate.year, _selectedDate.month, day);
        final isSelected = _selectedDate.year == date.year &&
            _selectedDate.month == date.month &&
            _selectedDate.day == date.day;
        final isToday = today.year == date.year &&
            today.month == date.month &&
            today.day == date.day;
        final hasAppointments = appointmentDates.any((d) =>
            d.year == date.year && d.month == date.month && d.day == date.day);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedDate = date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D)
                  : (isToday
                      ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
                if (hasAppointments && !isSelected)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D67D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactDateSelector(bool isDarkMode) {
    final today = DateTime.now();
    final dates = List.generate(7, (index) {
      return today.add(Duration(days: index - 3));
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: dates.map((date) {
          final isSelected = _selectedDate.year == date.year &&
              _selectedDate.month == date.month &&
              _selectedDate.day == date.day;
          final isToday = today.year == date.year &&
              today.month == date.month &&
              today.day == date.day;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = date);
            },
            child: Container(
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF00D67D), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekdayShort(date.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white70
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<AppointmentModel> _filterAppointments(List<AppointmentModel> appointments) {
    if (_selectedFilter == 'All') return appointments;

    final status = AppointmentFilters.getStatusFromFilter(_selectedFilter);
    if (status == null) return appointments;

    return appointments.where((a) => a.status == status).toList();
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return EnhancedEmptyState(
      icon: Icons.calendar_today_outlined,
      title: 'No Appointments',
      message: 'No appointments scheduled for ${_getFormattedDate(_selectedDate)}. Tap below to schedule one.',
      color: const Color(0xFF00D67D),
    );
  }

  Widget _buildNoResultsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedFilter appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedFilter = 'All'),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  void _showAddAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(
          business: widget.business,
          initialDate: _selectedDate,
          onSave: (appointment) async {
            final id = await _appointmentService.createAppointment(appointment);
            if (id != null && mounted) {
              widget.onRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appointment scheduled successfully')),
              );
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to schedule appointment. Time slot may be unavailable.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showAppointmentDetails(AppointmentModel appointment) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppointmentDetailsSheet(
        appointment: appointment,
        isDarkMode: isDarkMode,
        onStatusChange: (status) {
          Navigator.pop(context);
          _updateStatus(appointment, status);
        },
        onEdit: () {
          Navigator.pop(context);
          _editAppointment(appointment);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteAppointment(appointment);
        },
      ),
    );
  }

  void _editAppointment(AppointmentModel appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(
          business: widget.business,
          existingAppointment: appointment,
          onSave: (updated) async {
            final success = await _appointmentService.updateAppointment(
              widget.business.id,
              appointment.id,
              updated,
            );
            if (success && mounted) {
              widget.onRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appointment updated successfully')),
              );
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to update appointment'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _updateStatus(AppointmentModel appointment, AppointmentStatus status) async {
    if (status == AppointmentStatus.cancelled) {
      _showCancelDialog(appointment);
      return;
    }

    final success = await _appointmentService.updateAppointmentStatus(
      widget.business.id,
      appointment.id,
      status,
    );

    if (success && mounted) {
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment ${status.displayName.toLowerCase()}')),
      );
    }
  }

  void _showCancelDialog(AppointmentModel appointment) {
    final reasonController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this appointment?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _appointmentService.cancelAppointment(
                widget.business.id,
                appointment.id,
                reason: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
                cancelledBy: 'business',
              );
              if (success && mounted) {
                widget.onRefresh();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Appointment cancelled')),
                );
              }
            },
            child: const Text('Cancel Appointment', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteAppointment(AppointmentModel appointment) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Delete Appointment'),
        content: Text(
          'Are you sure you want to delete the appointment with ${appointment.customerName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _appointmentService.deleteAppointment(
                widget.business.id,
                appointment.id,
              );
              if (success && mounted) {
                widget.onRefresh();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Appointment deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              title: Text(
                'Search Appointments',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by client name or service...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() => query = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() => query = value);
                      },
                    ),
                    if (query.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 300,
                        child: FutureBuilder<List<AppointmentModel>>(
                          future: _appointmentService.searchAppointments(
                            widget.business.id,
                            query,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00D67D),
                                ),
                              );
                            }

                            final results = snapshot.data ?? [];
                            if (results.isEmpty) {
                              return Center(
                                child: Text(
                                  'No appointments found',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final apt = results[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFF00D67D)
                                            .withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.event,
                                      color: Color(0xFF00D67D),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    apt.customerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${apt.serviceName} • ${_getFormattedDate(apt.appointmentDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    setState(() {
                                      _selectedDate = apt.appointmentDate;
                                    });
                                    _showAppointmentDetails(apt);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getFormattedDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Appointment card widget
class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isDarkMode;
  final VoidCallback onTap;
  final Function(AppointmentStatus) onStatusChange;

  const _AppointmentCard({
    required this.appointment,
    required this.isDarkMode,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Time column
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatTimeOnly(appointment.startTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                        Text(
                          _formatTimeOnly(appointment.endTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Customer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appointment.customerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                appointment.status.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment.serviceName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: isDarkMode ? Colors.white38 : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appointment.formattedDuration,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white38 : Colors.grey[400],
                              ),
                            ),
                            if (appointment.price != null) ...[
                              const SizedBox(width: 16),
                              Text(
                                appointment.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D67D),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Quick actions
            if (_showQuickActions(appointment.status))
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildQuickActions(appointment.status),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _showQuickActions(AppointmentStatus status) {
    return status == AppointmentStatus.pending ||
        status == AppointmentStatus.confirmed ||
        status == AppointmentStatus.inProgress;
  }

  List<Widget> _buildQuickActions(AppointmentStatus status) {
    final actions = <Widget>[];

    if (status == AppointmentStatus.pending) {
      actions.add(_buildActionButton(
        'Confirm',
        Icons.check,
        Colors.green,
        () => onStatusChange(AppointmentStatus.confirmed),
      ));
      actions.add(const SizedBox(width: 8));
      actions.add(_buildActionButton(
        'Cancel',
        Icons.close,
        Colors.red,
        () => onStatusChange(AppointmentStatus.cancelled),
      ));
    } else if (status == AppointmentStatus.confirmed) {
      actions.add(_buildActionButton(
        'Start',
        Icons.play_arrow,
        Colors.blue,
        () => onStatusChange(AppointmentStatus.inProgress),
      ));
    } else if (status == AppointmentStatus.inProgress) {
      actions.add(_buildActionButton(
        'Complete',
        Icons.done_all,
        const Color(0xFF00D67D),
        () => onStatusChange(AppointmentStatus.completed),
      ));
    }

    return actions;
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOnly(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts[1];
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '$displayHours:$minutes\n$period';
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.inProgress:
        return Colors.blue;
      case AppointmentStatus.completed:
        return const Color(0xFF00D67D);
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.noShow:
        return Colors.grey;
    }
  }
}

/// Appointment details bottom sheet
class _AppointmentDetailsSheet extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isDarkMode;
  final Function(AppointmentStatus) onStatusChange;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppointmentDetailsSheet({
    required this.appointment,
    required this.isDarkMode,
    required this.onStatusChange,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.customerName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                appointment.status.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Service info
                  _buildDetailCard(
                    icon: Icons.spa_outlined,
                    title: 'Service',
                    content: appointment.serviceName,
                    subtitle: appointment.formattedPrice,
                  ),
                  const SizedBox(height: 12),

                  // Date & Time
                  _buildDetailCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Date & Time',
                    content: appointment.formattedDate,
                    subtitle: '${appointment.formattedTimeRange} (${appointment.formattedDuration})',
                  ),
                  const SizedBox(height: 12),

                  // Contact info
                  if (appointment.customerPhone != null || appointment.customerEmail != null)
                    _buildDetailCard(
                      icon: Icons.contact_phone_outlined,
                      title: 'Contact',
                      content: appointment.customerPhone ?? '',
                      subtitle: appointment.customerEmail,
                    ),

                  // Staff
                  if (appointment.staffName != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      icon: Icons.person_outline,
                      title: 'Staff',
                      content: appointment.staffName!,
                    ),
                  ],

                  // Notes
                  if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      icon: Icons.notes_outlined,
                      title: 'Notes',
                      content: appointment.notes!,
                    ),
                  ],

                  // Customer notes
                  if (appointment.customerNotes != null &&
                      appointment.customerNotes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      icon: Icons.note_alt_outlined,
                      title: 'Customer Notes',
                      content: appointment.customerNotes!,
                    ),
                  ],

                  // Cancellation reason
                  if (appointment.status == AppointmentStatus.cancelled &&
                      appointment.cancellationReason != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      icon: Icons.cancel_outlined,
                      title: 'Cancellation Reason',
                      content: appointment.cancellationReason!,
                      iconColor: Colors.red,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Action buttons
                  ..._buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2D2D44)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? const Color(0xFF00D67D)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? const Color(0xFF00D67D),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final buttons = <Widget>[];

    switch (appointment.status) {
      case AppointmentStatus.pending:
        buttons.add(_buildFullWidthButton(
          'Confirm Appointment',
          Icons.check_circle_outline,
          Colors.green,
          () => onStatusChange(AppointmentStatus.confirmed),
        ));
        buttons.add(const SizedBox(height: 12));
        buttons.add(_buildFullWidthButton(
          'Cancel Appointment',
          Icons.cancel_outlined,
          Colors.red,
          () => onStatusChange(AppointmentStatus.cancelled),
          outlined: true,
        ));
        break;

      case AppointmentStatus.confirmed:
        buttons.add(_buildFullWidthButton(
          'Start Appointment',
          Icons.play_circle_outline,
          Colors.blue,
          () => onStatusChange(AppointmentStatus.inProgress),
        ));
        buttons.add(const SizedBox(height: 12));
        buttons.add(Row(
          children: [
            Expanded(
              child: _buildFullWidthButton(
                'No Show',
                Icons.person_off_outlined,
                Colors.grey,
                () => onStatusChange(AppointmentStatus.noShow),
                outlined: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFullWidthButton(
                'Cancel',
                Icons.cancel_outlined,
                Colors.red,
                () => onStatusChange(AppointmentStatus.cancelled),
                outlined: true,
              ),
            ),
          ],
        ));
        break;

      case AppointmentStatus.inProgress:
        buttons.add(_buildFullWidthButton(
          'Complete Appointment',
          Icons.check_circle,
          const Color(0xFF00D67D),
          () => onStatusChange(AppointmentStatus.completed),
        ));
        break;

      default:
        break;
    }

    return buttons;
  }

  Widget _buildFullWidthButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: color) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: outlined ? color : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.inProgress:
        return Colors.blue;
      case AppointmentStatus.completed:
        return const Color(0xFF00D67D);
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.noShow:
        return Colors.grey;
    }
  }
}
