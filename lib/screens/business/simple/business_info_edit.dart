import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_profile.dart';
import '../../../models/catalog_item.dart';
import '../../../services/account_type_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/ai_services/gemini_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'business_hours_edit.dart';

class BusinessInfoEdit extends StatefulWidget {
  final BusinessProfile? businessProfile;

  const BusinessInfoEdit({super.key, this.businessProfile});

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

  final List<String> _selectedBusinessTypes = [];

  bool get _isSetupMode => widget.businessProfile == null;

  static const List<String> _businessTypeOptions = [
    'Products',
    'Services',
  ];

  @override
  void initState() {
    super.initState();
    final bp = widget.businessProfile;
    _nameController = TextEditingController(text: bp?.businessName ?? '');
    _descriptionController = TextEditingController(text: bp?.description ?? '');
    _softLabelController = TextEditingController(text: bp?.softLabel ?? '');
    _phoneController = TextEditingController(text: bp?.contactPhone ?? '');
    _emailController = TextEditingController(text: bp?.contactEmail ?? '');
    _websiteController = TextEditingController(text: bp?.website ?? '');
    _addressController = TextEditingController(text: bp?.address ?? '');
    _coverImageUrl = bp?.coverImageUrl;

    // Social links
    final social = bp?.socialLinks ?? {};
    _instagramController = TextEditingController(text: social['instagram'] ?? '');
    _facebookController = TextEditingController(text: social['facebook'] ?? '');
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _linkedinController = TextEditingController(text: social['linkedin'] ?? '');
    _youtubeController = TextEditingController(text: social['youtube'] ?? '');

    if (bp?.businessTypes != null) {
      _selectedBusinessTypes.addAll(bp!.businessTypes);
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
      final coverUrl = await _uploadCoverIfNeeded();
      final socialLinks = _buildSocialLinks();

      if (_isSetupMode) {
        // ── Setup mode: create new business profile ──
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
          // Generate sample catalog items in background
          _generateSampleCatalog();
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
      } else {
        // ── Edit mode: update existing profile ──
        final updated = widget.businessProfile!.copyWith(
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
          socialLinks: socialLinks,
          businessTypes: _selectedBusinessTypes,
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

  // ── AI Sample Catalog Generation ──

  Future<void> _generateSampleCatalog() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final businessName = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final label = _softLabelController.text.trim();
    final types = _selectedBusinessTypes;

    if (description.isEmpty && label.isEmpty) {
      _addTemplateCatalogItems(userId, label, types);
      return;
    }

    try {
      final prompt =
          'Generate exactly 3 sample catalog items for a business.\n'
          'Business name: $businessName\n'
          'Type: ${types.join(', ')}\n'
          'Label: $label\n'
          'Description: $description\n\n'
          'Return ONLY a JSON array with objects having: name, description, price (number), category, type ("product" or "service").\n'
          'Example: [{"name":"Haircut","description":"Basic haircut","price":500,"category":"Hair","type":"service"}]';

      final response = await GeminiService().generateContent(prompt);
      if (response == null || !response.contains('[')) {
        _addTemplateCatalogItems(userId, label, types);
        return;
      }

      final jsonStr = response.substring(
          response.indexOf('['), response.lastIndexOf(']') + 1);
      final items = jsonDecode(jsonStr) as List;

      for (final item in items.take(3)) {
        await CatalogService().addItem(CatalogItem(
          id: '',
          userId: userId,
          name: item['name'] ?? 'Sample Item',
          description: item['description'],
          price: (item['price'] as num?)?.toDouble(),
          category: item['category'],
          type: CatalogItemType.fromString(item['type']),
          isAvailable: true,
        ));
      }
    } catch (e) {
      debugPrint('Error generating sample catalog: $e');
      _addTemplateCatalogItems(userId, label, types);
    }
  }

  Future<void> _addTemplateCatalogItems(
      String userId, String label, List<String> types) async {
    final isService = types.contains('Services');
    final templates = isService
        ? [
            ('Consultation', 'Initial consultation session', 500.0, 'service'),
            ('Basic Package', 'Standard service package', 1000.0, 'service'),
          ]
        : [
            ('Featured Item', 'Our signature product', 999.0, 'product'),
            ('Popular Choice', 'Customer favorite', 499.0, 'product'),
          ];

    for (final t in templates) {
      try {
        await CatalogService().addItem(CatalogItem(
          id: '',
          userId: userId,
          name: t.$1,
          description: t.$2,
          price: t.$3,
          category: label.isNotEmpty ? label : null,
          type: CatalogItemType.fromString(t.$4),
          isAvailable: true,
        ));
      } catch (e) {
        debugPrint('Error adding template catalog item: $e');
      }
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
        title: Text(_isSetupMode ? 'Set Up Business' : 'Edit Business Info'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _isSetupMode
            ? null
            : [
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
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.w600)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(_nameController, 'Business Name *', isDark, textColor,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null),

                  // Business Type selector
                  const SizedBox(height: 16),
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
                                ? const Color(0xFF22C55E)
                                    .withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFF0F0F0)),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF22C55E))
                                : Border.all(
                                    color: isDark
                                        ? Colors.white
                                            .withValues(alpha: 0.08)
                                        : Colors.black
                                            .withValues(alpha: 0.06)),
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
                  _field(_descriptionController, 'Description', isDark,
                      textColor,
                      maxLines: 3, maxLength: 300),
                  const SizedBox(height: 16),
                  _field(_softLabelController,
                      'Label (e.g. Salon, Restaurant, Cafe, Shop)', isDark,
                      textColor),
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

            // Business hours link (edit mode only)
            if (!_isSetupMode)
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.access_time, color: Color(0xFF3B82F6)),
                  title: Text('Business Hours',
                      style: TextStyle(color: textColor)),
                  subtitle: Text(
                    widget.businessProfile!.hours != null
                        ? (widget.businessProfile!.isCurrentlyOpen
                            ? 'Currently Open'
                            : 'Currently Closed')
                        : 'Not set',
                    style: TextStyle(
                      color: widget.businessProfile!.isCurrentlyOpen
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
                          hours: widget.businessProfile!.hours ??
                              BusinessHours.defaultHours(),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Setup mode: hours hint
            if (_isSetupMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Business hours default to Mon-Fri 9 AM - 6 PM. You can edit them after setup.',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
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
                  _socialField(_instagramController, 'Instagram',
                      FontAwesomeIcons.instagram, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_facebookController, 'Facebook',
                      FontAwesomeIcons.facebookF, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_twitterController, 'X (Twitter)',
                      FontAwesomeIcons.xTwitter, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_linkedinController, 'LinkedIn',
                      FontAwesomeIcons.linkedinIn, isDark, textColor),
                  const SizedBox(height: 12),
                  _socialField(_youtubeController, 'YouTube',
                      FontAwesomeIcons.youtube, isDark, textColor),
                ],
              ),
            ),

            // Setup mode: Create button at bottom
            if (_isSetupMode) ...[
              const SizedBox(height: 32),
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
            ],

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
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF0F0F0),
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
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
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4)
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(icon,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.3),
                size: 18)),
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
