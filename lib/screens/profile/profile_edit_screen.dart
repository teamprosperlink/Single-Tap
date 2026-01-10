import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../res/config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/user_manager.dart';
import '../../services/location services/location_service.dart';

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

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];
  final List<String> _occupationOptions = [
    'Accountant',
    'Actor/Actress',
    'Architect',
    'Artist',
    'Attorney/Lawyer',
    'Banker',
    'Barber/Hairstylist',
    'Bartender',
    'Business Owner',
    'Chef/Cook',
    'Civil Engineer',
    'Consultant',
    'Content Creator',
    'Customer Service',
    'Data Analyst',
    'Data Scientist',
    'Dentist',
    'Designer (Graphic/UI/UX)',
    'Developer/Programmer',
    'Doctor/Physician',
    'Driver/Delivery',
    'Electrician',
    'Engineer',
    'Entrepreneur',
    'Farmer',
    'Financial Advisor',
    'Firefighter',
    'Fitness Trainer',
    'Flight Attendant',
    'Freelancer',
    'HR Manager',
    'Interior Designer',
    'Journalist',
    'Marketing Manager',
    'Mechanic',
    'Military/Armed Forces',
    'Musician',
    'Nurse',
    'Paramedic',
    'Pharmacist',
    'Photographer',
    'Pilot',
    'Plumber',
    'Police Officer',
    'Product Manager',
    'Professor/Lecturer',
    'Project Manager',
    'Psychologist',
    'Real Estate Agent',
    'Receptionist',
    'Researcher',
    'Restaurant Manager',
    'Retail Worker',
    'Sales Manager',
    'Scientist',
    'Security Guard',
    'Social Media Manager',
    'Social Worker',
    'Software Engineer',
    'Student',
    'Teacher',
    'Therapist',
    'Translator',
    'Veterinarian',
    'Video Editor',
    'Waiter/Waitress',
    'Web Developer',
    'Writer/Author',
    'Other',
  ];

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

  // ignore: unused_element
  Future<void> _createInitialProfile() async {
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
        'email': user!.email ?? '',
        'photoUrl': user!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      debugPrint('Error creating initial profile: $e');
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
      setState(() => _isUpdating = false);
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
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
              if (_selectedImage != null || _currentPhotoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                      _currentPhotoUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_isUpdating)
            TextButton(
              onPressed: _updateProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Image Section (Clickable)
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade300,
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
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
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
                    const SizedBox(height: 24),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        hintText: '+1 234 567 8900',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Location Field
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isUpdatingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _updateLocation,
                                tooltip: 'Detect my location',
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bio / About Me
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'About Me',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                        hintText: 'Tell us about yourself...',
                      ),
                      maxLines: 3,
                      maxLength: 300,
                    ),
                    const SizedBox(height: 16),

                    // Gender Selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _genderOptions.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                      },
                      hint: const Text('Select your gender'),
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateOfBirth ?? DateTime(2000),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDateOfBirth = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDateOfBirth != null
                              ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                              : 'Select your date of birth',
                          style: TextStyle(
                            color: _selectedDateOfBirth != null
                                ? null
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Occupation Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOccupation,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _occupationOptions.map((occupation) {
                        return DropdownMenuItem(
                          value: occupation,
                          child: Text(occupation),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedOccupation = value);
                      },
                      hint: const Text('Select your occupation'),
                    ),
                    const SizedBox(height: 24),

                    // Update Button
                    GestureDetector(
                      onTap: _isUpdating ? null : _updateProfile,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.buttonBackground(),
                          borderRadius: BorderRadius.circular(
                            AppColors.buttonBorderRadius,
                          ),
                          border: Border.all(
                            color: AppColors.buttonBorder(),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Update Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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
      // Show current profile image from URL (Google Sign-In)
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _currentPhotoUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) {
            debugPrint('Error loading profile image in edit screen: $error');
            return Icon(Icons.person, size: 60, color: Colors.grey.shade600);
          },
        ),
      );
    } else {
      // Show default person icon
      return Icon(Icons.person, size: 60, color: Colors.grey.shade600);
    }
  }
}
