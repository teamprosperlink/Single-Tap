import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_profile.dart';
import '../../../services/account_type_service.dart';
import '../../../services/catalog_service.dart';
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

  // Social links controllers
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _twitterController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _youtubeController;

  bool _isLoading = false;
  bool _isUploadingCover = false;
  String? _coverImageUrl;
  File? _selectedCoverFile;

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
    _coverImageUrl = bp.coverImageUrl;

    // Social links
    final social = bp.socialLinks ?? {};
    _instagramController = TextEditingController(text: social['instagram'] ?? '');
    _facebookController = TextEditingController(text: social['facebook'] ?? '');
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _linkedinController = TextEditingController(text: social['linkedin'] ?? '');
    _youtubeController = TextEditingController(text: social['youtube'] ?? '');
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
    _twitterController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (kIsWeb) {
      // Web: can't use File, just show preview info
      return;
    }

    setState(() {
      _selectedCoverFile = File(picked.path);
    });
  }

  Future<String?> _uploadCoverIfNeeded() async {
    if (_selectedCoverFile == null) return _coverImageUrl;

    setState(() => _isUploadingCover = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return _coverImageUrl;
      final url = await CatalogService().uploadCoverImage(_selectedCoverFile!, userId);
      return url ?? _coverImageUrl;
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Map<String, String> _buildSocialLinks() {
    final links = <String, String>{};
    if (_instagramController.text.trim().isNotEmpty) {
      links['instagram'] = _instagramController.text.trim();
    }
    if (_facebookController.text.trim().isNotEmpty) {
      links['facebook'] = _facebookController.text.trim();
    }
    if (_twitterController.text.trim().isNotEmpty) {
      links['twitter'] = _twitterController.text.trim();
    }
    if (_linkedinController.text.trim().isNotEmpty) {
      links['linkedin'] = _linkedinController.text.trim();
    }
    if (_youtubeController.text.trim().isNotEmpty) {
      links['youtube'] = _youtubeController.text.trim();
    }
    return links;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Upload cover image first if changed
      final coverUrl = await _uploadCoverIfNeeded();

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
        coverImageUrl: coverUrl,
        socialLinks: _buildSocialLinks(),
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
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);

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
            // ── Cover Image ──
            _sectionHeader('Cover Image', textColor),
            const SizedBox(height: 8),
            _buildCoverImagePicker(isDark, cardColor),

            const SizedBox(height: 24),

            // ── Business Details ──
            _sectionHeader('Business Details', textColor),
            const SizedBox(height: 8),
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Contact & Location ──
            _sectionHeader('Contact & Location', textColor),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
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

            const SizedBox(height: 24),

            // ── Social Links ──
            _sectionHeader('Social Links', textColor),
            const SizedBox(height: 4),
            Text(
              'Add your social media links so customers can find you',
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _socialField(_instagramController, 'Instagram', Icons.camera_alt_outlined, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_facebookController, 'Facebook', Icons.facebook_outlined, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_twitterController, 'X (Twitter)', Icons.alternate_email, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_linkedinController, 'LinkedIn', Icons.work_outline, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_youtubeController, 'YouTube', Icons.play_circle_outline, isDark, textColor),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker(bool isDark, Color cardColor) {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            style: (_selectedCoverFile == null && _coverImageUrl == null)
                ? BorderStyle.solid
                : BorderStyle.none,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_selectedCoverFile != null)
              Image.file(_selectedCoverFile!, fit: BoxFit.cover)
            else if (_coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: _coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => _coverPlaceholder(isDark),
              )
            else
              _coverPlaceholder(isDark),

            // Overlay with edit hint
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        color: Colors.white.withValues(alpha: 0.8), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _coverImageUrl != null || _selectedCoverFile != null
                          ? 'Change'
                          : 'Add Cover',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isUploadingCover)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
              : [const Color(0xFFe0e7ff), const Color(0xFFdbeafe)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w700,
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

  Widget _socialField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark,
    Color textColor,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.4),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.3),
            size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
