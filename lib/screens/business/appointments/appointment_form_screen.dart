import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/appointment_model.dart';
import '../../../models/business_model.dart';
import '../../../services/appointment_service.dart';
import '../../../services/business_service.dart';

/// Screen for creating or editing appointments
class AppointmentFormScreen extends StatefulWidget {
  final BusinessModel business;
  final AppointmentModel? existingAppointment;
  final DateTime? initialDate;
  final Function(AppointmentModel) onSave;

  const AppointmentFormScreen({
    super.key,
    required this.business,
    this.existingAppointment,
    this.initialDate,
    required this.onSave,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appointmentService = AppointmentService();
  final _businessService = BusinessService();

  // Form controllers
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();

  // Form state
  late DateTime _selectedDate;
  TimeSlot? _selectedTimeSlot;
  String? _selectedServiceId;
  String _selectedServiceName = '';
  int _duration = 30;
  bool _isLoading = false;
  bool _isSaving = false;

  // Data
  List<TimeSlot> _availableSlots = [];
  List<BusinessListing> _services = [];

  // Duration options
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existingAppointment?.appointmentDate ??
        widget.initialDate ??
        DateTime.now();

    if (widget.existingAppointment != null) {
      _populateExistingData();
    }

    _loadServices();
    _loadAvailableSlots();
  }

  void _populateExistingData() {
    final apt = widget.existingAppointment!;
    _customerNameController.text = apt.customerName;
    _customerPhoneController.text = apt.customerPhone ?? '';
    _customerEmailController.text = apt.customerEmail ?? '';
    _notesController.text = apt.notes ?? '';
    _priceController.text = apt.price?.toString() ?? '';
    _selectedServiceId = apt.serviceId;
    _selectedServiceName = apt.serviceName;
    _duration = apt.duration;
    _selectedTimeSlot = TimeSlot(
      startTime: apt.startTime,
      endTime: apt.endTime,
      isAvailable: true,
    );
  }

  Future<void> _loadServices() async {
    try {
      final services = await _businessService.getBusinessListings(widget.business.id);
      setState(() {
        _services = services.where((s) => s.type == 'service').toList();
      });
    } catch (e) {
      debugPrint('Error loading services: $e');
    }
  }

  Future<void> _loadAvailableSlots() async {
    setState(() => _isLoading = true);
    try {
      final slots = await _appointmentService.getAvailableSlots(
        widget.business.id,
        _selectedDate,
        slotDurationMinutes: _duration,
      );
      setState(() {
        _availableSlots = slots;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading slots: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingAppointment != null;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Appointment' : 'New Appointment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAppointment,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00D67D),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer section
            _buildSectionTitle('Customer Information', isDarkMode),
            const SizedBox(height: 12),
            _buildCustomerSection(isDarkMode),
            const SizedBox(height: 24),

            // Service section
            _buildSectionTitle('Service', isDarkMode),
            const SizedBox(height: 12),
            _buildServiceSection(isDarkMode),
            const SizedBox(height: 24),

            // Date & Time section
            _buildSectionTitle('Date & Time', isDarkMode),
            const SizedBox(height: 12),
            _buildDateTimeSection(isDarkMode),
            const SizedBox(height: 24),

            // Price section
            _buildSectionTitle('Price', isDarkMode),
            const SizedBox(height: 12),
            _buildPriceSection(isDarkMode),
            const SizedBox(height: 24),

            // Notes section
            _buildSectionTitle('Notes (Optional)', isDarkMode),
            const SizedBox(height: 12),
            _buildNotesSection(isDarkMode),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildCustomerSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Customer name
          TextFormField(
            controller: _customerNameController,
            decoration: InputDecoration(
              labelText: 'Customer Name',
              hintText: 'Enter customer name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter customer name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone
          TextFormField(
            controller: _customerPhoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _customerEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter email address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service selection
          if (_services.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedServiceId,
              decoration: InputDecoration(
                labelText: 'Select Service',
                prefixIcon: const Icon(Icons.spa_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _services.map((service) {
                return DropdownMenuItem(
                  value: service.id,
                  child: Text(service.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final service = _services.firstWhere((s) => s.id == value);
                  setState(() {
                    _selectedServiceId = value;
                    _selectedServiceName = service.name;
                    if (service.price != null) {
                      _priceController.text = service.price!.toStringAsFixed(0);
                    }
                  });
                }
              },
            )
          else
            TextFormField(
              initialValue: _selectedServiceName,
              decoration: InputDecoration(
                labelText: 'Service Name',
                hintText: 'Enter service name',
                prefixIcon: const Icon(Icons.spa_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => _selectedServiceName = value,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter service name';
                }
                return null;
              },
            ),
          const SizedBox(height: 16),

          // Duration
          Text(
            'Duration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationOptions.map((duration) {
              final isSelected = _duration == duration;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _duration = duration;
                    _selectedTimeSlot = null;
                  });
                  _loadAvailableSlots();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00D67D)
                          : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDarkMode ? Colors.white38 : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time slots
          Text(
            'Available Time Slots',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF00D67D)),
              ),
            )
          else if (_availableSlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No available slots for this date',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSlots.map((slot) {
                final isSelected = _selectedTimeSlot?.startTime == slot.startTime;
                final isAvailable = slot.isAvailable;

                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTimeSlot = slot);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D67D)
                          : (isAvailable
                              ? Colors.transparent
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[100])),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D67D)
                            : (isAvailable
                                ? (isDarkMode ? Colors.white24 : Colors.grey[300]!)
                                : Colors.transparent),
                      ),
                    ),
                    child: Text(
                      slot.formattedStartTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isAvailable
                                ? (isDarkMode ? Colors.white : Colors.black87)
                                : (isDarkMode ? Colors.white24 : Colors.grey[400])),
                        decoration: isAvailable ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          if (_selectedTimeSlot != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF00D67D),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Selected: ${_selectedTimeSlot!.displayString}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextFormField(
        controller: _priceController,
        decoration: InputDecoration(
          labelText: 'Price',
          hintText: '0',
          prefixText: '\u{20B9} ',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _buildNotesSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextFormField(
        controller: _notesController,
        decoration: InputDecoration(
          labelText: 'Notes',
          hintText: 'Add any notes about this appointment...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignLabelWithHint: true,
        ),
        maxLines: 3,
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedTimeSlot = null;
      });
      _loadAvailableSlots();
    }
  }

  void _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedServiceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appointment = AppointmentModel(
        id: widget.existingAppointment?.id ?? '',
        businessId: widget.business.id,
        customerId: widget.existingAppointment?.customerId ?? '',
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty
            ? null
            : _customerEmailController.text.trim(),
        serviceId: _selectedServiceId,
        serviceName: _selectedServiceName,
        appointmentDate: _selectedDate,
        startTime: _selectedTimeSlot!.startTime,
        endTime: _selectedTimeSlot!.endTime,
        duration: _duration,
        status: widget.existingAppointment?.status ?? AppointmentStatus.pending,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        price: double.tryParse(_priceController.text),
        currency: 'INR',
        createdAt: widget.existingAppointment?.createdAt,
      );

      widget.onSave(appointment);
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else if (minutes % 60 == 0) {
      return '${minutes ~/ 60} hr';
    } else {
      return '${minutes ~/ 60} hr ${minutes % 60} min';
    }
  }
}
