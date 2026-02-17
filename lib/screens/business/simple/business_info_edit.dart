import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../services/account_type_service.dart';
import 'business_hours_edit.dart';

class BusinessInfoEdit extends StatefulWidget {
  final BusinessProfile businessProfile;

  const BusinessInfoEdit({super.key, required this.businessProfile});

  @override
  State<BusinessInfoEdit> createState() => _BusinessInfoEditState();
}

class _BusinessInfoEditState extends State<BusinessInfoEdit> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _softLabelController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final bp = widget.businessProfile;
    _nameController = TextEditingController(text: bp.businessName ?? '');
    _descriptionController = TextEditingController(text: bp.description ?? '');
    _softLabelController = TextEditingController(text: bp.softLabel ?? '');
    _phoneController = TextEditingController(text: bp.contactPhone ?? '');
    _emailController = TextEditingController(text: bp.contactEmail ?? '');
    _websiteController = TextEditingController(text: bp.website ?? '');
    _addressController = TextEditingController(text: bp.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _softLabelController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updated = widget.businessProfile.copyWith(
        businessName: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        softLabel: _softLabelController.text.trim().isNotEmpty
            ? _softLabelController.text.trim()
            : null,
        contactPhone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        contactEmail: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        website: _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
      );

      final success =
          await AccountTypeService().updateBusinessProfile(updated);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business info updated'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Edit Business Info'),
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
                        color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _field(_nameController, 'Business Name *', isDark, textColor,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  _field(_descriptionController, 'Description', isDark,
                      textColor,
                      maxLines: 3, maxLength: 300),
                  const SizedBox(height: 16),
                  _field(
                      _softLabelController, 'Label (e.g. Salon)', isDark, textColor),
                  const SizedBox(height: 16),
                  _field(_phoneController, 'Phone', isDark, textColor,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _field(_emailController, 'Email', isDark, textColor,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _field(_websiteController, 'Website', isDark, textColor,
                      keyboardType: TextInputType.url),
                  const SizedBox(height: 16),
                  _field(_addressController, 'Address', isDark, textColor,
                      maxLines: 2),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Business hours link
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Color(0xFF3B82F6)),
                title: Text('Business Hours',
                    style: TextStyle(color: textColor)),
                subtitle: Text(
                  widget.businessProfile.hours != null
                      ? (widget.businessProfile.isCurrentlyOpen
                          ? 'Currently Open'
                          : 'Currently Closed')
                      : 'Not set',
                  style: TextStyle(
                    color: widget.businessProfile.isCurrentlyOpen
                        ? const Color(0xFF22C55E)
                        : Colors.red,
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.3)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessHoursEdit(
                        hours: widget.businessProfile.hours ??
                            BusinessHours.defaultHours(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    bool isDark,
    Color textColor, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
