import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../res/config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/user_manager.dart';
import '../../services/ip_location_service.dart';
import '../../widgets/common widgets/shared_form_widgets.dart';
import '../../widgets/common widgets/country_code_picker_sheet.dart';
import '../home/main_navigation_screen.dart';

class ProfileCreateScreen extends StatefulWidget {
  const ProfileCreateScreen({super.key});

  @override
  State<ProfileCreateScreen> createState() => _ProfileCreateScreenState();
}

class _ProfileCreateScreenState extends State<ProfileCreateScreen> {
  final AuthService _authService = AuthService();
  final UserManager _userManager = UserManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  User? user;
  String? _currentPhotoUrl;
  File? _selectedImage;
  bool _isSaving = false;
  bool _isUpdatingLocation = false;

  // Additional profile fields
  String? _selectedGender;
  String? _selectedOccupation;
  DateTime? _selectedDateOfBirth;

  // Country code data
  String _selectedCountryCode = '+91';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'country': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'country': 'UK', 'flag': '🇬🇧'},
    {'code': '+61', 'country': 'Australia', 'flag': '🇦🇺'},
    {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+65', 'country': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+60', 'country': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+49', 'country': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'country': 'France', 'flag': '🇫🇷'},
    {'code': '+39', 'country': 'Italy', 'flag': '🇮🇹'},
    {'code': '+81', 'country': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'country': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+86', 'country': 'China', 'flag': '🇨🇳'},
    {'code': '+55', 'country': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'country': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+27', 'country': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'country': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+92', 'country': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'country': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+977', 'country': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+94', 'country': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+63', 'country': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+62', 'country': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+66', 'country': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+84', 'country': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+7', 'country': 'Russia', 'flag': '🇷🇺'},
    {'code': '+34', 'country': 'Spain', 'flag': '🇪🇸'},
    {'code': '+31', 'country': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+46', 'country': 'Sweden', 'flag': '🇸🇪'},
  ];

  List<String> get _genderOptions => SharedFormWidgets.genderOptions;
  List<String> get _occupationOptions => SharedFormWidgets.occupationOptions;

  @override
  void initState() {
    super.initState();
    user = _authService.currentUser;
    _prefillFromAuth();
  }

  void _prefillFromAuth() {
    if (user != null) {
      _nameController.text = user!.displayName ?? '';
      _currentPhotoUrl = user!.photoURL;
    }
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isSaving = true);

    try {
      // Handle photo upload if new image selected
      String? photoUrl = _currentPhotoUrl ?? user!.photoURL;

      if (_selectedImage != null) {
        debugPrint('Uploading profile image...');
        try {
          final ref = _storage.ref().child('profile_images/${user!.uid}.jpg');
          await ref.putFile(_selectedImage!);
          final uploadedUrl = await ref.getDownloadURL();
          photoUrl = uploadedUrl;
          debugPrint('Profile image uploaded: $uploadedUrl');
        } catch (e) {
          debugPrint('Failed to upload profile image: $e');
        }
      }

      // Update Firebase Auth profile (name and photo)
      await user!.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: photoUrl,
      );

      // Reload user to get updated data
      await user!.reload();
      user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Calculate age from date of birth
      int? age;
      if (_selectedDateOfBirth != null) {
        age = DateTime.now().year - _selectedDateOfBirth!.year;
        if (DateTime.now().month < _selectedDateOfBirth!.month ||
            (DateTime.now().month == _selectedDateOfBirth!.month &&
                DateTime.now().day < _selectedDateOfBirth!.day)) {
          age--;
        }
      }

      // Combine country code + phone number
      final phoneNumber = _phoneController.text.trim().isNotEmpty
          ? '$_selectedCountryCode${_phoneController.text.trim()}'
          : '';

      // Save to Firestore
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': _nameController.text.trim(),
        'email': user!.email ?? '',
        'photoUrl': photoUrl,
        'phone': phoneNumber,
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _selectedOccupation,
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'age': age,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update via UserManager for cache
      await _userManager.updateProfile({
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl,
        'phone': phoneNumber,
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _selectedOccupation,
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'age': age,
      });

      debugPrint('Profile created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Profile created successfully!'),
              backgroundColor: Colors.green,
            ),
          );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error creating profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        setState(() {
          _selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to take photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    SharedFormWidgets.showImagePickerDialog(
      context: context,
      onPickGallery: _pickImage,
      onTakePhoto: _takePhoto,
      showRemove: _selectedImage != null || _currentPhotoUrl != null,
      onRemovePhoto: () {
        setState(() {
          _selectedImage = null;
          _currentPhotoUrl = null;
        });
      },
    );
  }

  void _showCustomDropdown({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelected,
  }) {
    SharedFormWidgets.showCustomDropdown(
      context: context,
      title: title,
      options: options,
      selectedValue: selectedValue,
      onSelected: onSelected,
    );
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      debugPrint('ProfileCreateScreen: Detecting location...');
      final result = await IpLocationService.detectLocation();

      if (result != null && mounted) {
        final display = result['displayAddress'] as String?;
        debugPrint('ProfileCreateScreen: Got location: $display');
        if (display != null && display.isNotEmpty) {
          setState(() {
            _locationController.text = display;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location detected: $display'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get address. Please check internet connection.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect location. Please check internet connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('ProfileCreateScreen: Error updating location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(64, 64, 64, 1),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CountryCodePickerSheet(
          countryCodes: _countryCodes,
          selectedCountryCode: _selectedCountryCode,
          onSelect: (code, flag) {
            setState(() {
              _selectedCountryCode = code;
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  InputDecoration _glassInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? labelText,
  }) {
    return SharedFormWidgets.glassInputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelText: labelText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        title: const Text(
          'Create Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image with background card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              child: _selectedImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _selectedImage!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _buildProfileImage(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePickerOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.iosBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: Colors.white,
                    decoration: _glassInputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: Icons.person_rounded,
                      labelText: 'Name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field (Read-only)
                  TextFormField(
                    initialValue: user?.email ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                    decoration: _glassInputDecoration(
                      hintText: '',
                      prefixIcon: Icons.email_rounded,
                      labelText: 'Email',
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 16),

                  // Phone Number Field with Country Code Picker
                  Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(filled: false),
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        floatingLabelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      child: Row(
                        children: [
                          // Phone icon
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              Icons.phone_rounded,
                              color: Colors.grey[400],
                              size: 22,
                            ),
                          ),
                          // Country code section
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showCountryCodePicker,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCountryCode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          // Phone number input
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 15,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              cursorColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter phone number',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 15,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio / About Me
                  TextFormField(
                    controller: _bioController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: Colors.white,
                    decoration: _glassInputDecoration(
                      hintText: 'Tell us about yourself...',
                      prefixIcon: Icons.info_outline_rounded,
                      labelText: 'About Me',
                    ),
                    minLines: 1,
                    maxLines: null,
                    maxLength: 300,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 16),

                  // Location Field
                  TextFormField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: Colors.white,
                    decoration: _glassInputDecoration(
                      hintText: 'Your location',
                      prefixIcon: Icons.location_on_rounded,
                      labelText: 'Location',
                      suffixIcon: _isUpdatingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(Icons.my_location, color: Colors.grey[400]),
                              onPressed: _updateLocation,
                              tooltip: 'Detect my location',
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Selection
                  GestureDetector(
                    onTap: () => _showCustomDropdown(
                      context: context,
                      title: 'Select Gender',
                      options: _genderOptions,
                      selectedValue: _selectedGender,
                      onSelected: (value) {
                        setState(() => _selectedGender = value);
                      },
                    ),
                    child: InputDecorator(
                      decoration: _glassInputDecoration(
                        hintText: '',
                        prefixIcon: Icons.person_outline_rounded,
                        labelText: 'Gender',
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                      ),
                      child: Text(
                        _selectedGender ?? 'Select your gender',
                        style: TextStyle(
                          color: _selectedGender != null
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDateOfBirth ?? DateTime(2000),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.iosBlue,
                                onPrimary: Colors.white,
                                surface: Color(0xFF1a1a2e),
                                onSurface: Colors.white,
                              ),
                              datePickerTheme: DatePickerThemeData(
                                backgroundColor: const Color(0xFF1a1a2e),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                headerBackgroundColor: const Color(0xFF1a1a2e),
                                headerForegroundColor: Colors.white,
                                cancelButtonStyle: ButtonStyle(
                                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                                  side: WidgetStatePropertyAll(BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  )),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  )),
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                ),
                                confirmButtonStyle: ButtonStyle(
                                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                                  backgroundColor: const WidgetStatePropertyAll(AppColors.iosBlue),
                                  side: WidgetStatePropertyAll(BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  )),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  )),
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedDateOfBirth = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: _glassInputDecoration(
                        hintText: '',
                        prefixIcon: Icons.calendar_today_rounded,
                        labelText: 'Date of Birth',
                      ),
                      child: Text(
                        _selectedDateOfBirth != null
                            ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                            : 'Select your date of birth',
                        style: TextStyle(
                          color: _selectedDateOfBirth != null
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Occupation Dropdown
                  GestureDetector(
                    onTap: () => _showCustomDropdown(
                      context: context,
                      title: 'Select Occupation',
                      options: _occupationOptions,
                      selectedValue: _selectedOccupation,
                      onSelected: (value) {
                        setState(() => _selectedOccupation = value);
                      },
                    ),
                    child: InputDecorator(
                      decoration: _glassInputDecoration(
                        hintText: '',
                        prefixIcon: Icons.work_outline_rounded,
                        labelText: 'Occupation',
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                      ),
                      child: Text(
                        _selectedOccupation ?? 'Select your occupation',
                        style: TextStyle(
                          color: _selectedOccupation != null
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Create Profile Button
                  GestureDetector(
                    onTap: _isSaving ? null : _createProfile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.iosBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _currentPhotoUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
          errorWidget: (context, url, error) {
            debugPrint('Error loading profile image: $error');
            return const Icon(Icons.person, size: 60, color: Colors.white54);
          },
        ),
      );
    } else {
      return const Icon(Icons.person, size: 60, color: Colors.white54);
    }
  }
}
