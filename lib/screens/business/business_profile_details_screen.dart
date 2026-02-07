import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';

/// Screen for managing business identity & compliance details
/// Includes GST, PAN, property type, and owner information
class BusinessProfileDetailsScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessProfileDetailsScreen({
    super.key,
    required this.business,
  });

  @override
  State<BusinessProfileDetailsScreen> createState() =>
      _BusinessProfileDetailsScreenState();
}

class _BusinessProfileDetailsScreenState
    extends State<BusinessProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();

  // Controllers
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _totalRoomsController = TextEditingController();

  bool _isSaving = false;
  String _selectedPropertyType = 'Hotel';

  final List<Map<String, dynamic>> _propertyTypes = [
    {'value': 'Hotel', 'icon': Icons.hotel_outlined},
    {'value': 'Hostel', 'icon': Icons.bed_outlined},
    {'value': 'PG', 'icon': Icons.home_outlined},
    {'value': 'Resort', 'icon': Icons.pool_outlined},
    {'value': 'Guesthouse', 'icon': Icons.house_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final business = widget.business;
    _gstController.text = business.gstNumber ?? '';
    _panController.text = business.panNumber ?? '';
    _ownerNameController.text = business.ownerName ?? '';
    _ownerPhoneController.text = business.ownerPhone ?? '';
    _ownerEmailController.text = business.ownerEmail ?? '';
    _totalRoomsController.text = business.totalRoomCount?.toString() ?? '';
    _selectedPropertyType = business.propertyType ?? 'Hotel';
  }

  @override
  void dispose() {
    _gstController.dispose();
    _panController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerEmailController.dispose();
    _totalRoomsController.dispose();
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
          'Business Profile Details',
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

              // Property Type Section
              _buildSectionTitle('Property Type', isDark),
              const SizedBox(height: 12),
              _buildPropertyTypeSelector(isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _totalRoomsController,
                label: 'Total Number of Rooms',
                hint: 'e.g., 25',
                icon: Icons.meeting_room_outlined,
                isDark: isDark,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter total room count';
                  }
                  final count = int.tryParse(value);
                  if (count == null || count < 1) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Legal Compliance Section
              _buildSectionTitle('Legal Compliance (Optional)', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _gstController,
                label: 'GST Number',
                hint: '15-digit GSTIN (e.g., 22AAAAA0000A1Z5)',
                icon: Icons.receipt_long_outlined,
                isDark: isDark,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(15),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 15) {
                    return 'GST number must be exactly 15 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _panController,
                label: 'PAN Number',
                hint: '10-digit PAN (e.g., ABCDE1234F)',
                icon: Icons.credit_card_outlined,
                isDark: isDark,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 10) {
                    return 'PAN must be exactly 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Owner Information Section
              _buildSectionTitle('Owner Information', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ownerNameController,
                label: 'Owner Full Name',
                hint: 'Enter owner\'s full name',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter owner name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ownerPhoneController,
                label: 'Owner Phone Number',
                hint: 'Enter contact number',
                icon: Icons.phone_outlined,
                isDark: isDark,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ownerEmailController,
                label: 'Owner Email Address',
                hint: 'Enter email for notifications',
                icon: Icons.email_outlined,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
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
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withAlpha(50),
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
              Icons.business_center_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Complete Your Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide business and owner details to build trust with customers and enable seamless transactions.',
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

  Widget _buildPropertyTypeSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _propertyTypes.map((type) {
          final isSelected = _selectedPropertyType == type['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPropertyType = type['value']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0A84FF)
                      : isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0A84FF)
                        : isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(10),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0A84FF).withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      type['icon'],
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? Colors.white60
                              : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['value'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isDark
                                ? Colors.white70
                                : Colors.black54,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A84FF).withAlpha(30)
                : const Color(0xFF0A84FF).withAlpha(15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF0A84FF),
          ),
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
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
                    'Save Profile Details',
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

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedBusiness = widget.business.copyWith(
      panNumber: _panController.text.trim().toUpperCase(),
      gstNumber: _gstController.text.trim().toUpperCase(),
      propertyType: _selectedPropertyType,
      totalRoomCount: int.tryParse(_totalRoomsController.text.trim()),
      ownerName: _ownerNameController.text.trim(),
      ownerPhone: _ownerPhoneController.text.trim(),
      ownerEmail: _ownerEmailController.text.trim().toLowerCase(),
    );

    final success = await _businessService.updateBusinessProfile(updatedBusiness);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile details saved successfully'),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save profile details'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
