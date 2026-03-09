import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/networking/networking_constants.dart';
import '../../widgets/networking/networking_widgets.dart';

class CreateNetworkingProfileScreen extends StatefulWidget {
  final String? createdFrom;

  const CreateNetworkingProfileScreen({super.key, this.createdFrom});

  @override
  State<CreateNetworkingProfileScreen> createState() =>
      _CreateNetworkingProfileScreenState();
}

class _CreateNetworkingProfileScreenState
    extends State<CreateNetworkingProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late AnimationController _shimmerController;

  // Form controllers
  final _nameController = TextEditingController();
  final _aboutMeController = TextEditingController();
  final _occupationController = TextEditingController();

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _currentPhotoUrl;

  // Active status & location
  bool _discoveryModeEnabled = true;
  RangeValues _ageRange = const RangeValues(18, 60);
  RangeValues _distanceRange = const RangeValues(1, 500);
  String? _locationCity;
  double? _userLatitude;
  double? _userLongitude;

  // Selected values
  String? _selectedGender;
  String? _selectedCategory;
  String? _selectedSubcategory;
  final Map<String, String> _categoryFilterValues = {};
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];
  final List<String> _selectedInterests = [];

  bool _allowCalls = true;
  bool _isSaving = false;
  bool _ageExplicitlySet = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _nameController.addListener(() => setState(() {}));
    _loadBasicUserInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shimmerController.dispose();
    _nameController.dispose();
    _aboutMeController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _loadBasicUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || doc.data() == null || !mounted) return;

      final data = doc.data()!;
      setState(() {
        // Only load location from main profile (needed for discovery)
        // All other fields stay empty — networking profile is separate
        _locationCity = data['city'] ?? data['location'];
        _userLatitude = (data['latitude'] as num?)?.toDouble();
        _userLongitude = (data['longitude'] as num?)?.toDouble();
      });
    } catch (e) {
      debugPrint('Error loading basic user info: $e');
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (_selectedImage != null ||
          (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)) &&
      _ageExplicitlySet &&
      (_locationCity != null && _locationCity!.isNotEmpty) &&
      _selectedGender != null;

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_selectedCategory == null) {
      _showSnackBar('Please select a Networking Category', isError: true);
      return;
    }
    if (_selectedGender == null) {
      _showSnackBar('Please select your Gender', isError: true);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('Please login first', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image if selected
      String? photoUrl = _currentPhotoUrl;
      if (_selectedImage != null) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final ref = FirebaseStorage.instance.ref().child(
            'networking_profile_images/${uid}_$timestamp.jpg',
          );
          await ref.putFile(_selectedImage!);
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Failed to upload image: $e');
        }
      }

      final data = <String, dynamic>{
        'userId': uid,
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl ?? '',
        'aboutMe': _aboutMeController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'age': _ageRange.start.round(),
        'ageRangeStart': _ageRange.start.round(),
        'ageRangeEnd': _ageRange.end.round(),
        'gender': _selectedGender ?? '',
        'discoveryModeEnabled': _discoveryModeEnabled,
        'allowCalls': _allowCalls,
        'distanceRangeStart': _distanceRange.start.round(),
        'distanceRangeEnd': _distanceRange.end.round(),
        'city': _locationCity ?? '',
        'location': _locationCity ?? '',
        if (_userLatitude != null) 'latitude': _userLatitude,
        if (_userLongitude != null) 'longitude': _userLongitude,
        'networkingCategory': _selectedCategory ?? '',
        'networkingSubcategory': _selectedSubcategory ?? '',
        'connectionTypes': _selectedConnectionTypes,
        'activities': _selectedActivities,
        'interests': _selectedInterests,
        'categoryFilters': _categoryFilterValues.isNotEmpty
            ? _categoryFilterValues
            : <String, String>{},
        if (widget.createdFrom != null) 'createdFrom': widget.createdFrom,
      };

      // Save to subcollection (each profile is a separate document)
      data['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .collection('profiles')
          .add(data);
      if (!mounted) return;

      // Also set as active top-level profile
      await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      if (mounted) {
        _showSnackBar('Profile saved successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        _showSnackBar('Failed to save profile: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) _showSnackBar('Failed to pick image', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo != null && mounted) {
        setState(() => _selectedImage = File(photo.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) _showSnackBar('Failed to take photo', isError: true);
    }
  }

  void _showImagePickerOptions() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 22),
                    const Text(
                      'Change Photo',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF6366F1),
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontFamily: 'Poppins', 
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF06B6D4),
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontFamily: 'Poppins', 
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              if (_selectedImage != null || _currentPhotoUrl != null)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(fontFamily: 'Poppins', 
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _currentPhotoUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: NetworkingWidgets.networkingAppBar(
          title: 'Create Networking Profile',
          onBack: () => Navigator.pop(context),
        ),
        bottomNavigationBar: _buildSaveButton(),
        body: Container(
          decoration: NetworkingWidgets.bodyGradient(fourStop: true),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image with glassmorphic card
                  Center(
                    child: Container(
                      width: 250,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 2,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _selectedImage != null
                                            ? Image.file(
                                                _selectedImage!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              )
                                            : _currentPhotoUrl != null &&
                                                  _currentPhotoUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: _currentPhotoUrl!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white54,
                                                          ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.person_rounded,
                                                          size: 40,
                                                          color: Colors.white54,
                                                        ),
                                              )
                                            : const Icon(
                                                Icons.person_rounded,
                                                size: 40,
                                                color: Colors.white54,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _showImagePickerOptions,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF6366F1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  Text(
                    'Name',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    label: '',
                    hint: 'Enter your name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 1. Basic Info Section
                  _buildSectionHeader(
                    'Basic Information',
                    Icons.person_outline_rounded,
                    [const Color(0xFF6366F1), const Color(0xFFA855F7)],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'About Me',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _aboutMeController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length}/300',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 11,
                              color: value.text.length > 300
                                  ? Colors.redAccent
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _aboutMeController,
                    label: '',
                    hint: 'Tell others about yourself...',
                    minLines: 1,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Occupation',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _occupationController,
                    label: '',
                    hint: 'e.g. Software Developer, Designer...',
                  ),
                  const SizedBox(height: 16),

                  // 2. Networking Category (Dropdown)
                  _buildSectionHeader(
                    'Networking Category',
                    Icons.hub_rounded,
                    [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                  ),
                  const SizedBox(height: 8),

                  // Category Dropdown
                  LayoutBuilder(
                    builder: (_, boxConstraints) => PopupMenuButton<String>(
                      constraints: BoxConstraints(
                        minWidth: boxConstraints.maxWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      color: const Color(0xFF2A2A2A),
                      position: PopupMenuPosition.under,
                      borderRadius: BorderRadius.circular(14),
                      initialValue: _selectedCategory,
                      itemBuilder: (context) =>
                          NetworkingConstants.categorySubcategories.keys.map((catName) {
                            final icon =
                                NetworkingConstants.categoryIcons[catName] ?? Icons.hub_rounded;
                            final colors =
                                NetworkingConstants.categoryColors[catName] ??
                                [const Color(0xFF6366F1)];
                            return PopupMenuItem<String>(
                              value: catName,
                              child: Row(
                                children: [
                                  Icon(icon, color: colors[0], size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    catName,
                                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onSelected: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedSubcategory = null;
                          _categoryFilterValues.clear();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCategory != null) ...[
                              Icon(
                                NetworkingConstants.categoryIcons[_selectedCategory] ??
                                    Icons.hub_rounded,
                                color:
                                    (NetworkingConstants.categoryColors[_selectedCategory] ??
                                    [const Color(0xFF6366F1)])[0],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                _selectedCategory ?? 'Select Category',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  color: _selectedCategory != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Subcategory Dropdown (if category selected)
                  if (_selectedCategory != null) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final subs =
                            NetworkingConstants.categorySubcategories[_selectedCategory] ?? [];
                        final catColor =
                            (NetworkingConstants.categoryColors[_selectedCategory] ??
                            [const Color(0xFF6366F1)])[0];
                        return LayoutBuilder(
                          builder: (_, boxConstraints) =>
                              PopupMenuButton<String>(
                                constraints: BoxConstraints(
                                  minWidth: boxConstraints.maxWidth,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                color: const Color(0xFF2A2A2A),
                                position: PopupMenuPosition.under,
                                borderRadius: BorderRadius.circular(14),
                                initialValue: _selectedSubcategory,
                                itemBuilder: (context) => subs
                                    .map(
                                      (sub) => PopupMenuItem<String>(
                                        value: sub,
                                        child: Text(
                                          sub,
                                          style: const TextStyle(fontFamily: 'Poppins', 
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (value) {
                                  setState(() {
                                    _selectedSubcategory = value;
                                    _categoryFilterValues.clear();
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedSubcategory ??
                                              'Select Subcategory',
                                          style: TextStyle(fontFamily: 'Poppins', 
                                            color: _selectedSubcategory != null
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        );
                      },
                    ),

                    // 4. Category + Subcategory specific filter dropdowns
                    for (final filter in <Map<String, dynamic>>[
                      ...(NetworkingConstants.categoryFilters[_selectedCategory] ?? []),
                      if (_selectedSubcategory != null)
                        ...(NetworkingConstants.subcategoryFilters[_selectedSubcategory] ?? []),
                    ]) ...[
                      const SizedBox(height: 16),
                      Text(
                        (filter['label'] ?? '').toString(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (_, boxConstraints) {
                          final label = (filter['label'] ?? '').toString();
                          final options = (filter['options'] as List?)
                              ?.map((e) => e.toString()).toList() ?? <String>[];
                          final catColor =
                              (NetworkingConstants.categoryColors[_selectedCategory] ??
                              [const Color(0xFF6366F1)])[0];
                          return PopupMenuButton<String>(
                            constraints: BoxConstraints(
                              minWidth: boxConstraints.maxWidth,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            color: const Color(0xFF2A2A2A),
                            position: PopupMenuPosition.under,
                            borderRadius: BorderRadius.circular(14),
                            initialValue: _categoryFilterValues[label],
                            itemBuilder: (context) => options
                                .map(
                                  (opt) => PopupMenuItem<String>(
                                    value: opt,
                                    child: Text(
                                      opt,
                                      style: const TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onSelected: (value) {
                              setState(() {
                                _categoryFilterValues[label] = value;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _categoryFilterValues[label] ??
                                          'Select $label',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color:
                                            _categoryFilterValues[label] != null
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),

                  // ── Age Range (RangeSlider Popup) ──
                  Text(
                    'Age Range',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      RangeValues tempAge = _ageRange;
                      showDialog(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setSliderState) => AlertDialog(
                            backgroundColor: const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            title: const Text(
                              'Age Range',
                              style: TextStyle(fontFamily: 'Poppins', 
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${tempAge.start.round()} - ${tempAge.end.round() == 60 ? "60+" : tempAge.end.round()}',
                                  style: const TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    rangeThumbShape:
                                        const RoundRangeSliderThumbShape(
                                          enabledThumbRadius: 8,
                                        ),
                                  ),
                                  child: RangeSlider(
                                    values: tempAge,
                                    min: 18,
                                    max: 60,
                                    divisions: 42,
                                    onChanged: (values) {
                                      setSliderState(() {
                                        tempAge = values;
                                      });
                                    },
                                  ),
                                ),
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '18',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '60+',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _ageRange = tempAge;
                                    _ageExplicitlySet = true;
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Done',
                                  style: TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_ageRange.start.round()} - ${_ageRange.end.round() == 60 ? "60+" : _ageRange.end.round()}',
                              style: const TextStyle(fontFamily: 'Poppins', 
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Gender (Popup with Icons) ──
                  Text(
                    'Gender',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (_, boxConstraints) => PopupMenuButton<String>(
                      constraints: BoxConstraints(
                        minWidth: boxConstraints.maxWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      color: const Color(0xFF2A2A2A),
                      position: PopupMenuPosition.under,
                      borderRadius: BorderRadius.circular(14),
                      initialValue: _selectedGender,
                      itemBuilder: (context) => NetworkingConstants.genderOptions
                          .map(
                            (gender) => PopupMenuItem<String>(
                              value: gender,
                              child: Row(
                                children: [
                                  Icon(
                                    gender == 'Male'
                                        ? Icons.male
                                        : gender == 'Female'
                                        ? Icons.female
                                        : Icons.transgender,
                                    color: const Color(0xFFFF6B9D),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    gender,
                                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        setState(() => _selectedGender = value);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedGender != null) ...[
                              Icon(
                                _selectedGender == 'Male'
                                    ? Icons.male
                                    : _selectedGender == 'Female'
                                    ? Icons.female
                                    : Icons.transgender,
                                color: const Color(0xFFFF6B9D),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                _selectedGender ?? 'Select Gender',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  color: _selectedGender != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Location (Distance RangeSlider Popup) ──
                  Text(
                    'Location',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      RangeValues tempDist = _distanceRange;
                      showDialog(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setSliderState) => AlertDialog(
                            backgroundColor: const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            title: const Text(
                              'Location Range',
                              style: TextStyle(fontFamily: 'Poppins', 
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${tempDist.start.round()} km - ${tempDist.end.round() == 500 ? "500+" : "${tempDist.end.round()}"} km',
                                  style: const TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    rangeThumbShape:
                                        const RoundRangeSliderThumbShape(
                                          enabledThumbRadius: 8,
                                        ),
                                  ),
                                  child: RangeSlider(
                                    values: tempDist,
                                    min: 1,
                                    max: 500,
                                    divisions: 499,
                                    onChanged: (values) {
                                      setSliderState(() {
                                        tempDist = values;
                                      });
                                    },
                                  ),
                                ),
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '1 km',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '500+ km',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _distanceRange = tempDist);
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Done',
                                  style: TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_distanceRange.start.round()} km - ${_distanceRange.end.round() == 500 ? "500+" : "${_distanceRange.end.round()}"} km',
                              style: const TextStyle(fontFamily: 'Poppins', 
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Active Status (Discovery Toggle) ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _discoveryModeEnabled
                                ? const Color(0xFF00E676)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: _discoveryModeEnabled
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00E676,
                                      ).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Show me in Discovery',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Switch(
                              value: _discoveryModeEnabled,
                              onChanged: (value) {
                                setState(() => _discoveryModeEnabled = value);
                              },
                              activeTrackColor: const Color(
                                0xFF00E676,
                              ).withValues(alpha: 0.5),
                              activeThumbColor: const Color(0xFF00E676),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Allow Calls Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _allowCalls
                                ? const Color(0xFF00E676).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call_rounded,
                            color: _allowCalls ? const Color(0xFF00E676) : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Allow Calls',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Switch(
                              value: _allowCalls,
                              onChanged: (value) {
                                HapticFeedback.lightImpact();
                                setState(() => _allowCalls = value);
                              },
                              activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.5),
                              activeThumbColor: const Color(0xFF00E676),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Section Header ────────────────────
  Widget _buildSectionHeader(String title, IconData icon, List<Color> colors) {
    return Text(
      title,
      style: const TextStyle(fontFamily: 'Poppins', 
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  // ──────────────────── Text Field ────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        keyboardType: minLines != null ? TextInputType.multiline : keyboardType,
        textAlignVertical: TextAlignVertical.top,
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontFamily: 'Poppins', 
          fontSize: 14,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label.isNotEmpty ? label : null,
          hintText: hint,
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          hintStyle: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          counterStyle: TextStyle(fontFamily: 'Poppins', 
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ──────────────────── Save Button ────────────────────
  Widget _buildSaveButton() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(30, 30, 30, 1),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: (_canSave && !_isSaving) ? _saveProfile : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 54,
              decoration: BoxDecoration(
                color: _canSave
                    ? const Color(0xFF016CFF)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _canSave
                    ? [
                        BoxShadow(
                          color: const Color(0xFF016CFF).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.save_rounded,
                            color: _canSave
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Save Profile',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _canSave
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
