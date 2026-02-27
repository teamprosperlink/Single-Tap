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
  int _currentStep = 0;
  final List<String> _selectedBusinessTypes = [];

  static const _totalSteps = 4;

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

  void _nextStep() {
    // Validate current step before proceeding
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business name is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
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
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
        title: Text('Step ${_currentStep + 1} of $_totalSteps',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStepContent(
                    isDark, textColor, subtitleColor),
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
      bool isDark, Color textColor, Color subtitleColor) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isDark, textColor, subtitleColor);
      case 1:
        return _buildStep2(isDark, textColor, subtitleColor);
      case 2:
        return _buildStep3(isDark, textColor, subtitleColor);
      case 3:
        return _buildStep4(isDark, textColor, subtitleColor);
      default:
        return const SizedBox();
    }
  }

  // ── Step 1: What's your business? ──
  Widget _buildStep1(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What's your business?",
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Tell us about your business so customers can find you',
            style: TextStyle(color: subtitleColor, fontSize: 14)),
        const SizedBox(height: 24),

        // Business Name
        _fieldLabel('Business Name *', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('Your business name', isDark),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),

        const SizedBox(height: 20),

        // Business Type
        _fieldLabel('Business Type', textColor),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : (isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06)),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Label/Tagline
        _fieldLabel('Label / Tagline', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _softLabelController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('e.g. Salon, Restaurant, Tutor', isDark),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedLabels.map((label) {
            final isSelected = _softLabelController.text == label;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _softLabelController.text = isSelected ? '' : label;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF3B82F6))
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : subtitleColor,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Description
        _fieldLabel('Description', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('What do you offer?', isDark),
          maxLines: 3,
          maxLength: 300,
        ),

        const SizedBox(height: 16),

        // Phone
        _fieldLabel('Phone', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('+91 ...', isDark),
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),

        // Email
        _fieldLabel('Email', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('business@email.com', isDark),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 2: Where are you located? ──
  Widget _buildStep2(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where are you located?',
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Help customers find your business',
            style: TextStyle(color: subtitleColor, fontSize: 14)),
        const SizedBox(height: 24),

        _fieldLabel('Address', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('Your business address', isDark),
          maxLines: 2,
        ),

        const SizedBox(height: 20),

        _fieldLabel('Website (optional)', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _websiteController,
          style: TextStyle(color: textColor),
          decoration: _inputDecoration('https://www.example.com', isDark),
          keyboardType: TextInputType.url,
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Business hours default to Mon-Fri 9 AM - 6 PM. You can edit them after setup.',
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 3: Make it yours ──
  Widget _buildStep3(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Make it yours',
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Add a cover photo and social links',
            style: TextStyle(color: subtitleColor, fontSize: 14)),
        const SizedBox(height: 24),

        _fieldLabel('Cover Image', textColor),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                            style: TextStyle(
                                color: subtitleColor, fontSize: 13)),
                      ],
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 24),

        _fieldLabel('Instagram (optional)', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instagramController,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: _inputDecoration('Instagram profile URL', isDark).copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.camera_alt_outlined,
                  color: subtitleColor, size: 20),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          keyboardType: TextInputType.url,
        ),

        const SizedBox(height: 16),

        _fieldLabel('Facebook (optional)', textColor),
        const SizedBox(height: 8),
        TextFormField(
          controller: _facebookController,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: _inputDecoration('Facebook page URL', isDark).copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.facebook_outlined,
                  color: subtitleColor, size: 20),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 4: Review & Create ──
  Widget _buildStep4(bool isDark, Color textColor, Color subtitleColor) {
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Create',
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Check everything looks good before creating',
            style: TextStyle(color: subtitleColor, fontSize: 14)),
        const SizedBox(height: 24),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover preview
              if (_coverImageFile != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_coverImageFile!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],

              _reviewRow('Business Name', _nameController.text, textColor,
                  subtitleColor),
              if (_softLabelController.text.trim().isNotEmpty)
                _reviewRow('Label', _softLabelController.text, textColor,
                    subtitleColor),
              if (_selectedBusinessTypes.isNotEmpty)
                _reviewRow('Type', _selectedBusinessTypes.join(', '),
                    textColor, subtitleColor),
              if (_descriptionController.text.trim().isNotEmpty)
                _reviewRow('Description', _descriptionController.text,
                    textColor, subtitleColor),
              if (_phoneController.text.trim().isNotEmpty)
                _reviewRow(
                    'Phone', _phoneController.text, textColor, subtitleColor),
              if (_emailController.text.trim().isNotEmpty)
                _reviewRow(
                    'Email', _emailController.text, textColor, subtitleColor),
              if (_addressController.text.trim().isNotEmpty)
                _reviewRow('Address', _addressController.text, textColor,
                    subtitleColor),
              if (_websiteController.text.trim().isNotEmpty)
                _reviewRow('Website', _websiteController.text, textColor,
                    subtitleColor),
              if (_instagramController.text.trim().isNotEmpty)
                _reviewRow('Instagram', _instagramController.text, textColor,
                    subtitleColor),
              if (_facebookController.text.trim().isNotEmpty)
                _reviewRow('Facebook', _facebookController.text, textColor,
                    subtitleColor),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _reviewRow(
      String label, String value, Color textColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.trim(),
                style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Bottom Buttons ──
  Widget _buildBottomButtons(bool isDark, Color textColor) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button (not on first step)
          if (_currentStep > 0)
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Back',
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),

          // Continue / Create button
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isLastStep ? _save : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF3B82F6),
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLastStep ? 'Create Business Profile' : 'Continue',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, Color color) {
    return Text(text,
        style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.w600));
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.3),
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
