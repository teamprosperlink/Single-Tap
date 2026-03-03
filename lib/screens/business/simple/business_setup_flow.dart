import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_profile.dart';
import '../../../services/account_type_service.dart';
import '../../../services/catalog_service.dart';

class BusinessSetupFlow extends StatefulWidget {
  final UserProfile? currentProfile;

  const BusinessSetupFlow({super.key, this.currentProfile});

  @override
  State<BusinessSetupFlow> createState() => _BusinessSetupFlowState();
}

class _BusinessSetupFlowState extends State<BusinessSetupFlow> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _softLabelController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();

  bool _isLoading = false;
  File? _coverImageFile;
  final List<String> _selectedBusinessTypes = [];

  static const List<String> _businessTypeOptions = [
    'Products',
    'Services',
    'Events',
  ];

  static const List<String> _suggestedLabels = [
    'Restaurant',
    'Cafe',
    'Salon',
    'Shop',
    'Tutor',
    'Freelancer',
    'Clinic',
    'Gym',
    'Studio',
    'Agency',
    'Bakery',
    'Store',
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final profile = widget.currentProfile;
    if (profile == null) return;

    _nameController.text =
        profile.businessProfile?.businessName ?? profile.name;
    _descriptionController.text = profile.businessProfile?.description ?? '';
    _softLabelController.text = profile.businessProfile?.softLabel ?? '';
    _phoneController.text =
        profile.businessProfile?.contactPhone ?? profile.phone ?? '';
    _emailController.text =
        profile.businessProfile?.contactEmail ?? profile.email;
    _websiteController.text = profile.businessProfile?.website ?? '';
    _addressController.text =
        profile.businessProfile?.address ?? profile.location ?? '';

    if (profile.businessProfile?.socialLinks != null) {
      _instagramController.text =
          profile.businessProfile!.socialLinks?['instagram'] ?? '';
      _facebookController.text =
          profile.businessProfile!.socialLinks?['facebook'] ?? '';
    }

    if (profile.businessProfile?.businessTypes != null) {
      _selectedBusinessTypes.addAll(profile.businessProfile!.businessTypes);
    }
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
    _instagramController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    if (kIsWeb) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _coverImageFile = File(picked.path));
    }
  }

  Future<String?> _uploadCoverIfNeeded() async {
    if (_coverImageFile == null) return null;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    return await CatalogService().uploadCoverImage(_coverImageFile!, userId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final coverUrl = await _uploadCoverIfNeeded();

      final socialLinks = <String, String>{};
      if (_instagramController.text.trim().isNotEmpty) {
        socialLinks['instagram'] = _instagramController.text.trim();
      }
      if (_facebookController.text.trim().isNotEmpty) {
        socialLinks['facebook'] = _facebookController.text.trim();
      }

      final profile = BusinessProfile(
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
        coverImageUrl: coverUrl,
        socialLinks: socialLinks.isNotEmpty ? socialLinks : null,
        businessTypes: _selectedBusinessTypes,
        hours: BusinessHours.defaultHours(),
        businessEnabledAt: DateTime.now(),
      );

      final success = await AccountTypeService().enableBusinessMode(profile);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business profile created!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create business profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Set Up Business'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Cover Image ──
            _sectionHeader('Cover Image', textColor),
            const SizedBox(height: 8),
            _buildCoverImagePicker(isDark, cardColor, subtitleColor),

            const SizedBox(height: 24),

            // ── About Your Business ──
            _sectionHeader('About Your Business', textColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Business Name *', isDark),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Business Type
                  Text('Business Type',
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _businessTypeOptions.map((type) {
                      final isSelected = _selectedBusinessTypes.contains(type);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedBusinessTypes.remove(type);
                            } else {
                              _selectedBusinessTypes.add(type);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFF0F0F0)),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF22C55E))
                                : Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF22C55E)
                                  : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: textColor),
                    decoration:
                        _inputDecoration('Description (what you offer)', isDark),
                    maxLines: 3,
                    maxLength: 300,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _softLabelController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration(
                        'Label (e.g. Salon, Restaurant)', isDark),
                  ),
                  const SizedBox(height: 12),
                  // Suggested labels
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedLabels.map((label) {
                      final isSelected = _softLabelController.text == label;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _softLabelController.text =
                                isSelected ? '' : label;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF22C55E)
                                    .withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFF0F0F0)),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF22C55E))
                                : null,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF22C55E)
                                  : subtitleColor,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Contact & Location ──
            _sectionHeader('Contact & Location', textColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Phone', isDark),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Email', isDark),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _websiteController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Website (optional)', isDark),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Address', isDark),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Social Links ──
            _sectionHeader('Social Links', textColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _socialField(_instagramController, 'Instagram (optional)',
                      Icons.camera_alt_outlined, isDark, textColor, subtitleColor),
                  const SizedBox(height: 12),
                  _socialField(_facebookController, 'Facebook (optional)',
                      Icons.facebook_outlined, isDark, textColor, subtitleColor),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Business hours default to Mon-Fri 9 AM - 6 PM. You can edit them after setup.',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Business Profile',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker(
      bool isDark, Color cardColor, Color subtitleColor) {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _coverImageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_coverImageFile!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Change',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12)),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 32, color: subtitleColor),
                    const SizedBox(height: 8),
                    Text('Tap to add a cover photo',
                        style: TextStyle(color: subtitleColor, fontSize: 13)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _socialField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      keyboardType: TextInputType.url,
      decoration: _inputDecoration(label, isDark).copyWith(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: subtitleColor, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
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
    );
  }
}
