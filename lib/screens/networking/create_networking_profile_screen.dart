import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/location_services/geocoding_service.dart';
import '../../services/ip_location_service.dart';
import '../../widgets/networking/networking_constants.dart';
import '../../widgets/networking/networking_helpers.dart';
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
  final _locationController = TextEditingController();

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  String? _currentPhotoUrl;

  // Active status & location
  bool _discoveryModeEnabled = true;
  DateTime? _dateOfBirth;
  RangeValues _distanceRange = const RangeValues(1, 500);
  String? _locationCity;
  double? _userLatitude;
  double? _userLongitude;

  // Location search
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _showLocationSuggestions = false;
  Timer? _locationDebounce;
  bool _isDetectingLocation = false;

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
  bool get _ageExplicitlySet => _dateOfBirth != null;

  final LayerLink _categoryLayerLink = LayerLink();
  OverlayEntry? _categoryOverlay;
  final GlobalKey _categoryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _nameController.addListener(() => setState(() {}));
    _locationController.addListener(_onLocationTextChanged);
    _loadBasicUserInfo();
    _autoDetectLocation();
  }

  @override
  void dispose() {
    _categoryOverlay?.remove();
    _locationDebounce?.cancel();
    _scrollController.dispose();
    _shimmerController.dispose();
    _nameController.dispose();
    _aboutMeController.dispose();
    _occupationController.dispose();
    _locationController.dispose();
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
      _locationController.removeListener(_onLocationTextChanged);
      setState(() {
        // Only load location from main profile (needed for discovery)
        // All other fields stay empty — networking profile is separate
        _locationCity = data['city'] ?? data['location'];
        _userLatitude = (data['latitude'] as num?)?.toDouble();
        _userLongitude = (data['longitude'] as num?)?.toDouble();
        if (_locationCity != null && _locationCity!.isNotEmpty) {
          _locationController.text = _locationCity!;
        }
      });
      _locationController.addListener(_onLocationTextChanged);
    } catch (e) {
      debugPrint('Error loading basic user info: $e');
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      (_selectedImage != null ||
          (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)) &&
      _ageExplicitlySet &&
      _locationController.text.trim().isNotEmpty &&
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
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final bytes = await _selectedImage!.readAsBytes();
          await ref.putData(bytes, metadata);
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Failed to upload image: $e');
          if (mounted) {
            setState(() => _isSaving = false);
            NetworkingHelpers.showSnackBar(context, 'Failed to upload photo. Please try again.', isError: true);
          }
          return;
        }
      }

      // Ensure coordinates are available (GPS-first fallback chain)
      double? lat = _userLatitude;
      double? lng = _userLongitude;
      if (lat == null || lng == null) {
        // Priority 1: Fresh GPS
        try {
          final locResult = await IpLocationService.detectLocation();
          if (locResult != null) {
            lat = locResult['lat'] as double;
            lng = locResult['lng'] as double;
          }
        } catch (_) {}
        // Priority 2: Firestore user profile (skip stale Mountain View)
        if (lat == null || lng == null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (userDoc.exists) {
              final fLat = (userDoc.data()?['latitude'] as num?)?.toDouble();
              final fLng = (userDoc.data()?['longitude'] as num?)?.toDouble();
              final fCity = (userDoc.data()?['city'] as String? ?? '').toLowerCase();
              final isMVCoords = (fLat != null && fLng != null &&
                  (fLat - 37.422).abs() < 0.05 && (fLng + 122.084).abs() < 0.05);
              if (fLat != null && fLng != null &&
                  !fCity.contains('mountain view') &&
                  !isMVCoords &&
                  !(fLat.abs() < 0.01 && fLng.abs() < 0.01)) {
                lat = fLat;
                lng = fLng;
              }
            }
          } catch (_) {}
        }
      }

      // Block save if no coordinates
      if (lat == null || lng == null) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showSnackBar(
            'Location is required. Please enable GPS or enter your location.',
            isError: true,
          );
        }
        return;
      }

      final data = <String, dynamic>{
        'userId': uid,
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl ?? '',
        'aboutMe': _aboutMeController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'dateOfBirth': _dateOfBirth != null
            ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
            : '',
        'age': _dateOfBirth != null ? _calculateAge(_dateOfBirth!) : 0,
        'gender': _selectedGender ?? '',
        'discoveryModeEnabled': _discoveryModeEnabled,
        'allowCalls': _allowCalls,
        'distanceRangeStart': _distanceRange.start.round(),
        'distanceRangeEnd': _distanceRange.end.round(),
        'city': _locationController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': lat,
        'longitude': lng,
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
      final subDocRef = await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .collection('profiles')
          .add(data);
      if (!mounted) return;

      // Also set as active top-level profile with reference to subcollection doc
      data['_activeSubDocId'] = subDocRef.id;
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

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    NetworkingHelpers.showSnackBar(context, message, isError: isError);
  }

  // ──────────────────── Location Methods ────────────────────

  void _onLocationTextChanged() {
    if (!mounted) return;
    setState(() {});
    final query = _locationController.text.trim();
    _locationDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _locationSuggestions = [];
        _showLocationSuggestions = false;
      });
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocationSuggestions(query);
    });
  }

  Future<void> _autoDetectLocation() async {
    if (!mounted || _isDetectingLocation) return;
    setState(() => _isDetectingLocation = true);

    // Priority 1: Fresh GPS via IpLocationService (always accurate)
    try {
      final result = await IpLocationService.detectLocation();
      if (result != null && mounted) {
        _userLatitude = result['lat'] as double;
        _userLongitude = result['lng'] as double;
        final display = result['displayAddress'] as String?;
        _locationController.removeListener(_onLocationTextChanged);
        setState(() {
          _isDetectingLocation = false;
          if (display != null && display.isNotEmpty) {
            _locationController.text = display;
          }
        });
        _locationController.addListener(_onLocationTextChanged);
        debugPrint('AutoDetect: Fresh GPS location used');
        return;
      }
    } catch (e) {
      debugPrint('AutoDetect: GPS location error: $e');
    }

    // Priority 2: Firestore user profile (only if GPS failed, skip stale data)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists && mounted) {
          final lat = (userDoc.data()?['latitude'] as num?)?.toDouble();
          final lng = (userDoc.data()?['longitude'] as num?)?.toDouble();
          final city = userDoc.data()?['city'] as String? ??
              userDoc.data()?['location'] as String? ?? '';
          final cityLower = city.toLowerCase();
          final isMVCoords2 = (lat != null && lng != null &&
              (lat - 37.422).abs() < 0.05 && (lng + 122.084).abs() < 0.05);
          if (lat != null && lng != null &&
              !cityLower.contains('mountain view') &&
              !isMVCoords2 &&
              !(lat.abs() < 0.01 && lng.abs() < 0.01)) {
            _userLatitude = lat;
            _userLongitude = lng;
            _locationController.removeListener(_onLocationTextChanged);
            setState(() {
              _isDetectingLocation = false;
              if (city.isNotEmpty) {
                _locationController.text = city;
              }
            });
            _locationController.addListener(_onLocationTextChanged);
            debugPrint('AutoDetect: Firestore fallback: $lat, $lng');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('AutoDetect: Firestore GPS error: $e');
    }

    if (mounted) {
      setState(() => _isDetectingLocation = false);
      _showSnackBar('Could not detect location. Please enter manually.', isError: true);
    }
  }

  Future<void> _searchLocationSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingLocation = true);
    try {
      double? lat = _userLatitude;
      double? lng = _userLongitude;

      if (lat == null || lng == null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            lat = (doc.data()?['latitude'] as num?)?.toDouble();
            lng = (doc.data()?['longitude'] as num?)?.toDouble();
          }
        }
      }
      final results = await GeocodingService.searchLocation(
        query,
        userLat: lat,
        userLng: lng,
      );
      if (mounted) {
        setState(() {
          _locationSuggestions = results;
          _showLocationSuggestions = results.isNotEmpty;
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Location search error: $e');
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    final area = (suggestion['area'] ?? '').toString();
    final city = (suggestion['city'] ?? '').toString();
    final state = (suggestion['state'] ?? '').toString();

    String display = '';
    if (area.isNotEmpty) {
      display = area;
      if (city.isNotEmpty && city != area) {
        display += ', $city';
      }
    } else if (city.isNotEmpty) {
      display = city;
    }

    if (state.isNotEmpty) {
      if (display.isNotEmpty) {
        display += ', $state';
      } else {
        display = state;
      }
    } else if (display.isEmpty) {
      display = (suggestion['formatted'] ?? '').toString().split(',').take(2).join(',').trim();
    }

    _locationController.removeListener(_onLocationTextChanged);
    _locationController.text = display;
    _locationController.addListener(_onLocationTextChanged);

    _userLatitude = (suggestion['latitude'] as num?)?.toDouble();
    _userLongitude = (suggestion['longitude'] as num?)?.toDouble();

    setState(() {
      _showLocationSuggestions = false;
      _locationSuggestions = [];
    });
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
        setState(() => _selectedImage = image);
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
        setState(() => _selectedImage = photo);
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
                        fontSize: 17,
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
                    fontSize: 15,
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
                    fontSize: 15,
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
                      fontSize: 15,
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
                            child: Column(
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Profile Photo',
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' *',
                                        style: TextStyle(
                                          color: Color(0xFF007AFF),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Stack(
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
                                                File(_selectedImage!.path),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Name',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'About Me',
                        style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 14,
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
                              fontSize: 12,
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
                      fontSize: 14,
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
                    isMandatory: true,
                  ),
                  const SizedBox(height: 8),

                  // Category Dropdown
                  CompositedTransformTarget(
                    link: _categoryLayerLink,
                    child: GestureDetector(
                      key: _categoryKey,
                      onTap: _showCategoryDropdown,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                                NetworkingConstants.categoryIcons[_selectedCategory] ?? Icons.hub_rounded,
                                color: (NetworkingConstants.categoryColors[_selectedCategory] ?? [const Color(0xFF6366F1)])[0],
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
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
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
                        return GestureDetector(
                          onTap: () async {
                            final result = await _showListPicker(
                              title: 'Select Subcategory',
                              options: subs,
                              currentValue: _selectedSubcategory,
                            );
                            if (result != null && mounted) {
                              setState(() {
                                _selectedSubcategory = result;
                                _categoryFilterValues.clear();
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSubcategory ?? 'Select Subcategory',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: _selectedSubcategory != null
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                              ],
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final label = (filter['label'] ?? '').toString();
                          final options = (filter['options'] as List?)
                              ?.map((e) => e.toString()).toList() ?? <String>[];
                          final catColor =
                              (NetworkingConstants.categoryColors[_selectedCategory] ??
                              [const Color(0xFF6366F1)])[0];
                          return GestureDetector(
                            onTap: () async {
                              final result = await _showListPicker(
                                title: 'Select $label',
                                options: options,
                                currentValue: _categoryFilterValues[label],
                              );
                              if (result != null && mounted) {
                                setState(() => _categoryFilterValues[label] = result);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _categoryFilterValues[label] ?? 'Select $label',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: _categoryFilterValues[label] != null
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
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

                  // ── Date of Birth (Calendar Picker) ──
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Date of Birth',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(1940),
                        lastDate: DateTime(now.year - 13, now.month, now.day),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF007AFF),
                                onPrimary: Colors.white,
                                surface: Color(0xFF2A2A2A),
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF2A2A2A),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _dateOfBirth = picked;
                        });
                      }
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
                              _dateOfBirth != null
                                  ? '${_dateOfBirth!.day.toString().padLeft(2, '0')} / ${_dateOfBirth!.month.toString().padLeft(2, '0')} / ${_dateOfBirth!.year}'
                                  : 'Select your date of birth',
                              style: TextStyle(fontFamily: 'Poppins',
                                color: _dateOfBirth != null
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Gender (Popup with Icons) ──
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Gender',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final result = await _showListPicker(
                        title: 'Select Gender',
                        options: NetworkingConstants.genderOptions,
                        currentValue: _selectedGender,
                      );
                      if (result != null && mounted) setState(() => _selectedGender = result);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
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
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: _selectedGender != null
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Location (Text Field with Auto-Detect & Search) ──
                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Location',
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isSearchingLocation)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white38,
                            strokeWidth: 1.5,
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (_isDetectingLocation)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _autoDetectLocation,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  color: Color(0xFF016CFF),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Detect',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF016CFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _locationController,
                    label: '',
                    hint: _isDetectingLocation
                        ? 'Detecting location...'
                        : 'e.g. Mumbai, Delhi...',
                  ),

                  // Location suggestions dropdown
                  if (_showLocationSuggestions && _locationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(64, 64, 64, 1),
                            Color.fromRGBO(0, 0, 0, 1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _showLocationSuggestions = false;
                                  _locationSuggestions = [];
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6, right: 10),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(bottom: 2),
                                itemCount: _locationSuggestions.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 40,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final s = _locationSuggestions[index];
                                  final city = (s['city'] ?? '').toString();
                                  final state = (s['state'] ?? '').toString();
                                  final area = (s['area'] ?? '').toString();
                                  final title = area.isNotEmpty ? area : city;
                                  String subtitle = '';
                                  if (city.isNotEmpty && city != title) subtitle = city;
                                  if (state.isNotEmpty) {
                                    subtitle = subtitle.isNotEmpty
                                        ? '$subtitle, $state'
                                        : state;
                                  }

                                  return InkWell(
                                    onTap: () => _selectLocationSuggestion(s),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF016CFF).withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF016CFF).withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_outlined,
                                              color: Color(0xFF016CFF),
                                              size: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (subtitle.isNotEmpty)
                                                  Text(
                                                    subtitle,
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      color: Colors.white.withValues(alpha: 0.5),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
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
                              fontSize: 15,
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
                              fontSize: 15,
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

  // ──────────────────── Generic Grid Picker ────────────────────
  Future<String?> _showListPicker({
    required String title,
    required List<String> options,
    String? currentValue,
    Widget Function(String option)? leadingBuilder,
  }) async {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(0, 0, 0, 1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = opt == currentValue;
                        // Use per-item color: maps → auto-generate from hash
                        final itemColor = NetworkingConstants.subcategoryColors[opt]
                            ?? NetworkingConstants.filterOptionColors[opt]
                            ?? HSLColor.fromAHSL(1.0, (opt.hashCode % 360).abs().toDouble(), 0.65, 0.55).toColor();
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [itemColor, itemColor.withValues(alpha: 0.7)]
                                    : [
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.white.withValues(alpha: 0.15),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? itemColor.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : itemColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : itemColor.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: leadingBuilder != null
                                      ? leadingBuilder(opt)
                                      : Icon(
                                          NetworkingConstants.subcategoryIcons[opt]
                                              ?? NetworkingConstants.filterOptionIcons[opt]
                                              ?? Icons.label_rounded,
                                          color: isSelected ? Colors.white : itemColor,
                                          size: 20,
                                        ),
                                ),
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    opt,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Category Dropdown ────────────────────
  void _showCategoryDropdown() {
    _categoryOverlay?.remove();
    _categoryOverlay = null;

    final categories = NetworkingConstants.categorySubcategories.keys.toList();

    _categoryOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeCategoryDropdown,
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.88,
                constraints: const BoxConstraints(maxHeight: 560),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(64, 64, 64, 1),
                      Color.fromRGBO(0, 0, 0, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Category',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            GestureDetector(
                              onTap: _closeCategoryDropdown,
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final catName = categories[index];
                              final icon = NetworkingConstants.categoryIcons[catName] ?? Icons.hub_rounded;
                              final colors = NetworkingConstants.categoryColors[catName] ?? [const Color(0xFF6366F1), const Color(0xFFA855F7)];
                              final isSelected = _selectedCategory == catName;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = catName;
                                    _selectedSubcategory = null;
                                    _categoryFilterValues.clear();
                                  });
                                  _closeCategoryDropdown();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                          ? colors
                                          : [
                                              Colors.white.withValues(alpha: 0.25),
                                              Colors.white.withValues(alpha: 0.15),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors[0].withValues(alpha: 0.9)
                                          : Colors.white.withValues(alpha: 0.3),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : colors[0].withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white.withValues(alpha: 0.5)
                                                : colors[0].withValues(alpha: 0.4),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: isSelected ? Colors.white : colors[0],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          catName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
    );

    Overlay.of(context).insert(_categoryOverlay!);
  }

  void _closeCategoryDropdown() {
    _categoryOverlay?.remove();
    _categoryOverlay = null;
  }

  // ──────────────────── Section Header ────────────────────
  Widget _buildSectionHeader(String title, IconData icon, List<Color> colors, {bool isMandatory = false}) {
    if (isMandatory) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
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
          fontSize: 15,
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
            fontSize: 12,
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
                              fontSize: 17,
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
