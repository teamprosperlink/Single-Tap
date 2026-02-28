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
import '../../services/location_services/location_service.dart';
import '../../widgets/common widgets/shared_form_widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final AuthService _authService = AuthService();
  final UserManager _userManager = UserManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  User? user;
  String? _currentPhotoUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isUpdatingLocation = false;

  // Additional profile fields
  String? _selectedGender;
  String? _selectedOccupation;
  DateTime? _selectedDateOfBirth;

  List<String> get _genderOptions => SharedFormWidgets.genderOptions;
  List<String> get _occupationOptions => SharedFormWidgets.occupationOptions;

  @override
  void initState() {
    super.initState();
    user = _authService.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get profile from UserManager
      final profileData =
          _userManager.cachedProfile ??
          await _userManager.loadUserProfile(user!.uid);

      if (profileData != null) {
        _nameController.text = profileData['name'] ?? '';
        _phoneController.text = profileData['phone'] ?? '';
        _locationController.text =
            profileData['city'] ?? profileData['location'] ?? '';
        _bioController.text = profileData['bio'] ?? '';
        _currentPhotoUrl = profileData['photoUrl'];

        // Validate gender value matches dropdown options
        final gender = profileData['gender'];
        if (gender != null && _genderOptions.contains(gender)) {
          _selectedGender = gender;
        }

        // Validate occupation value matches dropdown options
        final occupation = profileData['occupation'];
        if (occupation != null && _occupationOptions.contains(occupation)) {
          _selectedOccupation = occupation;
        } else if (occupation != null) {
          // Try to find case-insensitive match
          _selectedOccupation = _occupationOptions.firstWhere(
            (opt) => opt.toLowerCase() == occupation.toLowerCase(),
            orElse: () => 'Other',
          );
        }

        // Parse date of birth if exists
        if (profileData['dateOfBirth'] != null) {
          if (profileData['dateOfBirth'] is Timestamp) {
            _selectedDateOfBirth = (profileData['dateOfBirth'] as Timestamp)
                .toDate();
          } else if (profileData['dateOfBirth'] is String) {
            _selectedDateOfBirth = DateTime.tryParse(
              profileData['dateOfBirth'],
            );
          }
        }
      } else {
        // Fallback to Auth data
        _nameController.text = user!.displayName ?? '';
        _currentPhotoUrl = user!.photoURL;
      }

      debugPrint(
        'Loaded profile - Name: ${_nameController.text}, Photo URL: $_currentPhotoUrl',
      );
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() => _isUpdating = true);

    try {
      // Handle photo upload if new image selected
      String? photoUrl = _currentPhotoUrl ?? user!.photoURL;

      if (_selectedImage != null) {
        debugPrint('Uploading new profile image...');
        try {
          final ref = _storage.ref().child('profile_images/${user!.uid}.jpg');
          await ref.putFile(_selectedImage!);
          final uploadedUrl = await ref.getDownloadURL();
          photoUrl = uploadedUrl;
          debugPrint('New profile image uploaded: $uploadedUrl');
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

      // Update Firestore directly
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': _nameController.text.trim(),
        'email': user!.email ?? '',
        'photoUrl': photoUrl,
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _selectedOccupation,
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'age': age,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      // Also update via UserManager for cache
      await _userManager.updateProfile({
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl,
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _selectedOccupation,
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'age': age,
      });

      debugPrint('Profile updated successfully');

      // Update local state with new photo URL and clear selected image
      setState(() {
        _currentPhotoUrl = photoUrl;
        _selectedImage = null; // Clear selected image after successful upload
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload profile to ensure everything is synced
        await _loadUserProfile();

        if (!mounted) return;
        // ignore: use_build_context_synchronously
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate profile was updated
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95, // High quality to prevent blur
        maxWidth: 1920, // Max resolution for optimization
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
        imageQuality: 95, // High quality to prevent blur
        maxWidth: 1920, // Max resolution for optimization
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
      debugPrint('ProfileEditScreen: Getting GPS location (user-initiated)...');
      // User manually clicked location button, so NOT silent mode
      final position = await _locationService.getCurrentLocation(silent: false);

      if (position != null) {
        debugPrint(
          'ProfileEditScreen: Got GPS position: ${position.latitude}, ${position.longitude}',
        );
        final addressData = await _locationService.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (addressData != null &&
            addressData['city'] != null &&
            addressData['city'].toString().isNotEmpty &&
            mounted) {
          // Only show real location with valid city name
          final locationString = addressData['display'] ?? addressData['city'];
          debugPrint('ProfileEditScreen: Got real location: $locationString');
          setState(() {
            _locationController.text = locationString;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location detected: $locationString'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          debugPrint(
            'ProfileEditScreen: Geocoding failed or returned invalid data',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not get address from GPS coordinates. Please check internet connection.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('ProfileEditScreen: Could not get GPS position');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied or GPS is disabled. Please enable in settings.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ProfileEditScreen: Error updating location: $e');
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
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
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

                              // Phone Number Field
                              TextFormField(
                                controller: _phoneController,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                cursorColor: Colors.white,
                                decoration: _glassInputDecoration(
                                  hintText: '+1 234 567 8900',
                                  prefixIcon: Icons.phone_rounded,
                                  labelText: 'Phone Number',
                                ),
                                keyboardType: TextInputType.phone,
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

                              // Update Button
                              GestureDetector(
                                onTap: _isUpdating ? null : _updateProfile,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.iosBlue,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: _isUpdating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Update Profile',
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
            ],
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
            debugPrint('Error loading profile image in edit screen: $error');
            return const Icon(Icons.person, size: 60, color: Colors.white54);
          },
        ),
      );
    } else {
      return const Icon(Icons.person, size: 60, color: Colors.white54);
    }
  }
}
