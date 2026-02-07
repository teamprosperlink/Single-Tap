import 'package:flutter/material.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';

/// Screen for managing property-specific profile information
/// Includes description, check-in/out times, house rules, and cancellation policy
class PropertyProfileScreen extends StatefulWidget {
  final BusinessModel business;

  const PropertyProfileScreen({
    super.key,
    required this.business,
  });

  @override
  State<PropertyProfileScreen> createState() => _PropertyProfileScreenState();
}

class _PropertyProfileScreenState extends State<PropertyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();

  // Controllers
  final _descriptionController = TextEditingController();
  final _landmarksController = TextEditingController();
  final _houseRulesController = TextEditingController();

  bool _isSaving = false;
  TimeOfDay _checkInTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _checkOutTime = const TimeOfDay(hour: 11, minute: 0);
  String _selectedCancellationPolicy = 'Flexible';

  final List<Map<String, dynamic>> _cancellationPolicies = [
    {
      'value': 'Free',
      'label': 'Free Cancellation',
      'description': 'Full refund up to 24 hours before check-in',
      'icon': Icons.check_circle_outline,
    },
    {
      'value': 'Flexible',
      'label': 'Flexible',
      'description': '50% refund up to 48 hours before check-in',
      'icon': Icons.schedule_outlined,
    },
    {
      'value': 'Moderate',
      'label': 'Moderate',
      'description': '25% refund up to 5 days before check-in',
      'icon': Icons.info_outline,
    },
    {
      'value': 'Strict',
      'label': 'Strict',
      'description': 'No refunds after booking',
      'icon': Icons.block_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final business = widget.business;
    _descriptionController.text = business.propertyDescription ?? '';
    _landmarksController.text = business.nearbyLandmarks ?? '';
    _houseRulesController.text = business.houseRules ?? '';
    _selectedCancellationPolicy = business.cancellationPolicy ?? 'Flexible';

    // Parse check-in time
    if (business.checkInTime != null) {
      final parts = business.checkInTime!.split(':');
      if (parts.length == 2) {
        _checkInTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 14,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    // Parse check-out time
    if (business.checkOutTime != null) {
      final parts = business.checkOutTime!.split(':');
      if (parts.length == 2) {
        _checkOutTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 11,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _landmarksController.dispose();
    _houseRulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Property Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(isDark),
              const SizedBox(height: 28),

              // Property Description Section
              _buildSectionTitle('Property Description', isDark),
              const SizedBox(height: 8),
              Text(
                'Help guests discover your property with a compelling description',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _buildMultiLineTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe your property, amenities, and unique features...',
                isDark: isDark,
                maxLines: 6,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a property description';
                  }
                  if (value.trim().length < 50) {
                    return 'Description should be at least 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Location & Landmarks Section
              _buildSectionTitle('Nearby Landmarks', isDark),
              const SizedBox(height: 8),
              Text(
                'Help guests find you easily with nearby landmarks',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _buildMultiLineTextField(
                controller: _landmarksController,
                label: 'Landmarks',
                hint: 'e.g., 500m from railway station, Near City Mall...',
                isDark: isDark,
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 28),

              // Check-in/Check-out Times Section
              _buildSectionTitle('Check-in & Check-out Times', isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'Check-in Time',
                      time: _checkInTime,
                      icon: Icons.login_outlined,
                      isDark: isDark,
                      onTap: () => _selectTime(context, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'Check-out Time',
                      time: _checkOutTime,
                      icon: Icons.logout_outlined,
                      isDark: isDark,
                      onTap: () => _selectTime(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // House Rules Section
              _buildSectionTitle('House Rules', isDark),
              const SizedBox(height: 8),
              Text(
                'Set clear expectations for your guests',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _buildMultiLineTextField(
                controller: _houseRulesController,
                label: 'House Rules',
                hint: 'e.g., No smoking, No pets, Quiet hours after 10 PM...',
                isDark: isDark,
                maxLines: 5,
                maxLength: 300,
              ),
              const SizedBox(height: 28),

              // Cancellation Policy Section
              _buildSectionTitle('Cancellation Policy', isDark),
              const SizedBox(height: 8),
              Text(
                'Choose how flexible you want to be with cancellations',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _buildCancellationPolicySelector(isDark),
              const SizedBox(height: 32),

              // Save Button
              _buildSaveButton(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998e).withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Showcase Your Property',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an attractive profile that helps guests understand what makes your property special.',
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF0A84FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiLineTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 3,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 15,
        height: 1.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(8) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF0A84FF),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
            width: 2,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black26,
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFFF3B30),
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: const Color(0xFF0A84FF),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              time.format(context),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationPolicySelector(bool isDark) {
    return Column(
      children: _cancellationPolicies.map((policy) {
        final isSelected = _selectedCancellationPolicy == policy['value'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedCancellationPolicy = policy['value']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0A84FF).withAlpha(20)
                    : isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0A84FF)
                      : isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(8),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0A84FF)
                          : isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.black.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      policy['icon'],
                      size: 24,
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? Colors.white60
                              : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy['label'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          policy['description'],
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0A84FF),
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              isDark ? Colors.white.withAlpha(15) : Colors.grey[300],
          disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Save Property Profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isCheckIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? _checkInTime : _checkOutTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              dialBackgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withAlpha(15)
                  : Colors.grey[200],
              hourMinuteTextColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              dayPeriodTextColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedBusiness = widget.business.copyWith(
      propertyDescription: _descriptionController.text.trim(),
      nearbyLandmarks: _landmarksController.text.trim(),
      checkInTime: _formatTime(_checkInTime),
      checkOutTime: _formatTime(_checkOutTime),
      houseRules: _houseRulesController.text.trim(),
      cancellationPolicy: _selectedCancellationPolicy,
    );

    final success = await _businessService.updateBusinessProfile(updatedBusiness);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Property profile saved successfully'),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save property profile'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
