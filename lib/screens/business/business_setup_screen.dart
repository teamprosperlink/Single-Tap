import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/business_model.dart';
import '../../models/business_category_config.dart';
import '../../services/business_service.dart';
import '../../services/location_services/geocoding_service.dart';
import '../home/main_navigation_screen.dart';

/// Multi-step wizard for setting up or editing a business profile
/// Clean, modern UI design with light theme
class BusinessSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final BusinessModel? existingBusiness;

  const BusinessSetupScreen({
    super.key,
    this.onComplete,
    this.onSkip,
    this.existingBusiness,
  });

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Category Selection
  BusinessCategory? _selectedCategory;
  final _categorySearchController = TextEditingController();
  String _categorySearchQuery = '';

  // Step 2: Sub-type Selection
  String? _selectedSubType;

  // Step 3: Basic Info
  final _businessNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  File? _logoFile;

  // Step 4: Location
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _locationSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  double? _latitude;
  double? _longitude;

  // Step 5: Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _whatsappController = TextEditingController();

  // Country code for phone
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  // Common country codes list
  static const List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'country': 'United States', 'flag': '🇺🇸'},
    {'code': '+1', 'country': 'Canada', 'flag': '🇨🇦'},
    {'code': '+44', 'country': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': '+91', 'country': 'India', 'flag': '🇮🇳'},
    {'code': '+61', 'country': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'country': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'country': 'France', 'flag': '🇫🇷'},
    {'code': '+81', 'country': 'Japan', 'flag': '🇯🇵'},
    {'code': '+86', 'country': 'China', 'flag': '🇨🇳'},
    {'code': '+55', 'country': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'country': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+34', 'country': 'Spain', 'flag': '🇪🇸'},
    {'code': '+39', 'country': 'Italy', 'flag': '🇮🇹'},
    {'code': '+7', 'country': 'Russia', 'flag': '🇷🇺'},
    {'code': '+82', 'country': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+31', 'country': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+46', 'country': 'Sweden', 'flag': '🇸🇪'},
    {'code': '+41', 'country': 'Switzerland', 'flag': '🇨🇭'},
    {'code': '+65', 'country': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'country': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+27', 'country': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'country': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+254', 'country': 'Kenya', 'flag': '🇰🇪'},
    {'code': '+62', 'country': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+60', 'country': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+63', 'country': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+66', 'country': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+84', 'country': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+92', 'country': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'country': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+94', 'country': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+977', 'country': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+20', 'country': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+90', 'country': 'Turkey', 'flag': '🇹🇷'},
    {'code': '+48', 'country': 'Poland', 'flag': '🇵🇱'},
    {'code': '+47', 'country': 'Norway', 'flag': '🇳🇴'},
    {'code': '+45', 'country': 'Denmark', 'flag': '🇩🇰'},
    {'code': '+358', 'country': 'Finland', 'flag': '🇫🇮'},
    {'code': '+353', 'country': 'Ireland', 'flag': '🇮🇪'},
    {'code': '+64', 'country': 'New Zealand', 'flag': '🇳🇿'},
    {'code': '+54', 'country': 'Argentina', 'flag': '🇦🇷'},
    {'code': '+56', 'country': 'Chile', 'flag': '🇨🇱'},
    {'code': '+57', 'country': 'Colombia', 'flag': '🇨🇴'},
    {'code': '+51', 'country': 'Peru', 'flag': '🇵🇪'},
  ];

  // Step 6: Review (no additional fields)
  bool _acceptedTerms = false;

  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  static const int _totalSteps = 6;

  bool get _isEditing => widget.existingBusiness != null;

  // Colors - Using blue accent instead of green
  static const _primaryColor = Color(0xFF1E3A5F); // Deep blue
  static const _accentColor = Color(0xFF2563EB); // Bright blue
  static const _lightAccent = Color(0xFF3B82F6); // Light blue

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final business = widget.existingBusiness!;

    _selectedCategory = business.category;
    _selectedSubType = business.subType;

    _businessNameController.text = business.businessName;
    _legalNameController.text = business.legalName ?? '';

    // Parse phone number to extract country code and number separately
    final phoneStr = business.contact.phone ?? '';
    if (phoneStr.isNotEmpty) {
      // Phone may be saved as "+91 9876543210" or corrupted as "+91 +91 +91 9876543210"
      // We need to extract the country code and clean the phone number

      // First, extract the first valid country code
      final countryCodeMatch = RegExp(
        r'^\+\d{1,4}',
      ).firstMatch(phoneStr.trim());
      if (countryCodeMatch != null) {
        final countryCode = countryCodeMatch.group(0)!; // e.g., "+91"

        // Remove ALL country codes from the phone string to get clean number
        final phoneNumber = phoneStr
            .replaceAll(RegExp(r'\+\d{1,4}\s*'), '') // Remove all +XX patterns
            .trim();

        // Find matching country in our list
        final countryData = _countryCodes.firstWhere(
          (country) => country['code'] == countryCode,
          orElse: () => _countryCodes[0], // Default to India if not found
        );

        _selectedCountryCode = countryData['code']!;
        _selectedCountryFlag = countryData['flag']!;
        _phoneController.text = phoneNumber;
      } else {
        // If no country code found, treat entire string as phone number
        _phoneController.text = phoneStr.trim();
      }
    }

    _emailController.text = business.contact.email ?? '';
    _websiteController.text = business.contact.website ?? '';
    _whatsappController.text = business.contact.whatsapp ?? '';

    if (business.address != null) {
      _streetController.text = business.address!.street ?? '';
      _cityController.text = business.address!.city ?? '';
      _stateController.text = business.address!.state ?? '';
      _countryController.text = business.address!.country ?? '';
      _postalCodeController.text = business.address!.postalCode ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _categorySearchController.dispose();
    _businessNameController.dispose();
    _legalNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _whatsappController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _locationSearchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (!_validateCurrentStep()) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _saveAndContinue();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedCategory == null) {
          _showError('Please select a business category');
          return false;
        }
        return true;
      case 1:
        if (_selectedSubType == null) {
          _showError('Please select your business specialty');
          return false;
        }
        return true;
      case 2:
        if (_businessNameController.text.trim().isEmpty) {
          _showError('Please enter your business name');
          return false;
        }
        return true;
      case 3:
        return true; // Location is optional
      case 4:
        if (_phoneController.text.trim().isEmpty) {
          _showError('Please enter a phone number');
          return false;
        }
        return true;
      case 5:
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _logoFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking logo: $e');
    }
  }

  void _searchLocation(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await GeocodingService.searchLocation(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching location: $e');
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    HapticFeedback.selectionClick();

    setState(() {
      _streetController.text = location['area'] ?? '';
      _cityController.text = location['city'] ?? '';
      _stateController.text = location['state'] ?? '';
      _countryController.text = location['country'] ?? '';
      _postalCodeController.text = location['pincode'] ?? '';

      // Save coordinates for map display
      if (location['latitude'] != null) {
        _latitude = (location['latitude'] as num).toDouble();
      }
      if (location['longitude'] != null) {
        _longitude = (location['longitude'] as num).toDouble();
      }

      _locationSearchController.clear();
      _searchResults = [];
    });
  }

  void _useCurrentLocation() async {
    HapticFeedback.selectionClick();

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Getting your location...'),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied'),
                backgroundColor: Colors.red[400],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location in settings'),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get address
      final address = await GeocodingService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;

          if (address != null) {
            _streetController.text = address['area'] ?? '';
            _cityController.text = address['city'] ?? '';
            _stateController.text = address['state'] ?? '';
            _countryController.text = address['country'] ?? '';
            _postalCodeController.text = address['pincode'] ?? '';
          }
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get location: ${e.toString().split(':').last.trim()}',
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _showError('No internet connection. Please connect and try again.');
        setState(() => _isLoading = false);
        return;
      }

      try {
        final result = await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw const SocketException('No internet');
        }
      } on SocketException catch (_) {
        _showError('No internet connection. Please check your network.');
        setState(() => _isLoading = false);
        return;
      } on TimeoutException catch (_) {
        _showError('Network is slow. Please check your connection.');
        setState(() => _isLoading = false);
        return;
      }

      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await _businessService
            .uploadLogo(_logoFile!)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Logo upload timed out'),
            );
      } else if (_isEditing) {
        logoUrl = widget.existingBusiness!.logo;
      }

      // Clean phone number to ensure no duplicate country codes
      String? cleanedPhone;
      if (_phoneController.text.trim().isNotEmpty) {
        final phoneNumber = _phoneController.text.trim();
        // Remove any existing country codes from the phone number before adding the selected one
        final phoneWithoutCode = phoneNumber.replaceAll(
          RegExp(r'^\+\d{1,4}\s*'),
          '',
        );
        cleanedPhone = '$_selectedCountryCode $phoneWithoutCode';
      }

      final contact = BusinessContact(
        phone: cleanedPhone,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        whatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
      );

      BusinessAddress? address;
      if (_cityController.text.trim().isNotEmpty ||
          _streetController.text.trim().isNotEmpty) {
        address = BusinessAddress(
          street: _streetController.text.trim().isEmpty
              ? null
              : _streetController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
        );
      }

      final business = BusinessModel(
        id: _isEditing ? widget.existingBusiness!.id : '',
        userId: _isEditing ? widget.existingBusiness!.userId : '',
        businessName: _businessNameController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
        businessType: _selectedSubType ?? 'Other',
        category: _selectedCategory,
        subType: _selectedSubType,
        logo: logoUrl,
        contact: contact,
        address: address,
        hours: BusinessHours.defaultHours(),
        coverImage: _isEditing ? widget.existingBusiness!.coverImage : null,
        rating: _isEditing ? widget.existingBusiness!.rating : 0.0,
        reviewCount: _isEditing ? widget.existingBusiness!.reviewCount : 0,
        followerCount: _isEditing ? widget.existingBusiness!.followerCount : 0,
        isVerified: _isEditing ? widget.existingBusiness!.isVerified : false,
        isActive: _isEditing ? widget.existingBusiness!.isActive : true,
      );

      bool success;
      if (_isEditing) {
        success = await _businessService
            .updateBusiness(widget.existingBusiness!.id, business)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('Update timed out.'),
            );
      } else {
        final businessId = await _businessService
            .createBusiness(business)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('Creation timed out.'),
            );
        success = businessId != null;
      }

      if (success) {
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Business updated successfully'
                    : 'Business created successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (widget.onComplete != null) {
          widget.onComplete!();
        } else if (_isEditing) {
          if (mounted) Navigator.pop(context, true);
        } else {
          _navigateToMainScreen();
        }
      } else {
        _showError(
          _isEditing
              ? 'Failed to update business. Please try again.'
              : 'Failed to create business. Please try again.',
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout saving business: $e');
      _showError('Connection timed out. Please check your internet.');
    } on SocketException catch (_) {
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      debugPrint('Error saving business: $e');
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const MainNavigationScreen(loginAccountType: 'Business Account'),
      ),
      (route) => false,
    );
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep = step;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BusinessType(),
                  _buildStep2Category(),
                  _buildStep3BasicInfo(),
                  _buildStep4Location(),
                  _buildStep5Contact(),
                  _buildStep6Review(),
                ],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = (_currentStep + 1) / _totalSteps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                onPressed: _currentStep > 0
                    ? _previousStep
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              // Step indicator
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Progress percentage
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ============ STEP 1: BUSINESS TYPE ============
  Widget _buildStep1BusinessType() {
    final filteredCategories = BusinessCategoryConfig.all.where((config) {
      if (_categorySearchQuery.isEmpty) return true;
      return config.displayName.toLowerCase().contains(
        _categorySearchQuery.toLowerCase(),
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What type of business\ndo you have?',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the category that best describes your business',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 24),

          // Search bar
          TextField(
            controller: _categorySearchController,
            onChanged: (value) {
              setState(() {
                _categorySearchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accentColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final config = filteredCategories[index];
              final isSelected = _selectedCategory == config.category;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategory = config.category;
                    _selectedSubType = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _accentColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _accentColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        config.icon,
                        color: isSelected ? _accentColor : Colors.grey[600],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        config.displayName,
                        style: TextStyle(
                          color: isSelected ? _accentColor : Colors.grey[800],
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 2: CATEGORY SELECTION ============
  Widget _buildStep2Category() {
    final config = _selectedCategory != null
        ? BusinessCategoryConfig.getConfig(_selectedCategory!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What's your specialty?",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your specific category',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 32),

          // Category chips
          if (config != null)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: config.subTypes.map((subType) {
                final isSelected = _selectedSubType == subType;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedSubType = subType;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentColor : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? _accentColor : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      subType,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 3: BASIC INFO ============
  Widget _buildStep3BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about your\nbusiness',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll use this information to set up your official profile.",
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 32),

          // Business Name
          _buildInputField(
            controller: _businessNameController,
            label: 'Business Name',
            hint: "e.g. Joe's Coffee Shop",
            prefixIcon: Icons.store_outlined,
            isRequired: true,
          ),
          const SizedBox(height: 20),

          // Legal Name
          _buildInputField(
            controller: _legalNameController,
            label: 'Legal Name',
            hint: "e.g. Joe's Coffee LLC",
            prefixIcon: Icons.badge_outlined,
            helperText: 'Only required if different from your business name.',
          ),
          const SizedBox(height: 24),

          // Logo Upload
          Text(
            'Business Logo',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _logoFile != null ? _accentColor : Colors.grey[300]!,
                  width: _logoFile != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  if (_logoFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _logoFile!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Change'),
                          style: TextButton.styleFrom(
                            foregroundColor: _accentColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _logoFile = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to upload your logo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PNG, JPG up to 5MB',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Text(
            'A good logo helps customers recognize your business.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 4: LOCATION ============
  Widget _buildStep4Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where is your business\nlocated?',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This address will be visible to your customers.',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 24),

          // Search Address
          Text(
            'Search Address',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              TextField(
                controller: _locationSearchController,
                onChanged: _searchLocation,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search for your business address...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _accentColor,
                              ),
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final location = _searchResults[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: _accentColor,
                        ),
                        title: Text(
                          location['display'] ?? location['formatted'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        onTap: () => _selectLocation(location),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Use current location button
          GestureDetector(
            onTap: _useCurrentLocation,
            child: const Row(
              children: [
                Icon(Icons.my_location, color: _lightAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Use current location',
                  style: TextStyle(
                    color: _lightAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Map display
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            clipBehavior: Clip.antiAlias,
            child: _latitude != null && _longitude != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // Static map image from OpenStreetMap
                      Image.network(
                        'https://staticmap.openstreetmap.de/staticmap.php?center=$_latitude,$_longitude&zoom=15&size=600x300&maptype=mapnik&markers=$_latitude,$_longitude,red-pushpin',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: _accentColor,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildMapPlaceholder();
                        },
                      ),
                      // Location pin overlay
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Address label
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: _accentColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _cityController.text.isNotEmpty
                                      ? '${_cityController.text}, ${_stateController.text}'
                                      : 'Location selected',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildMapPlaceholder(),
          ),
          const SizedBox(height: 24),

          // Street Address
          _buildInputField(
            controller: _streetController,
            label: 'Street Address',
            hint: '123 Main St',
          ),
          const SizedBox(height: 16),

          // City & State
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'City',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _stateController,
                  label: 'State/Province',
                  hint: 'State',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Postal Code & Country
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _postalCodeController,
                  label: 'Zip/Postal',
                  hint: 'Zip/Postal',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Country',
                  value: _countryController.text.isEmpty
                      ? null
                      : _countryController.text,
                  items: [
                    'India',
                    'United States',
                    'United Kingdom',
                    'Canada',
                    'Australia',
                  ],
                  onChanged: (value) {
                    setState(() {
                      _countryController.text = value ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 5: CONTACT ============
  Widget _buildStep5Contact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How can customers\nreach you?',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your business contact info so clients can easily get in touch with you.',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 32),

          // Phone with country code
          _buildPhoneFieldWithCountryCode(),
          const SizedBox(height: 20),

          // Email
          _buildInputField(
            controller: _emailController,
            label: 'Business Email',
            hint: 'contact@yourbusiness.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // Website
          _buildInputField(
            controller: _websiteController,
            label: 'Website',
            hint: 'https://www.yourbusiness.com',
            prefixIcon: Icons.language_outlined,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 32),

          // Social Profiles Section
          Row(
            children: [
              Text(
                'Social Profiles',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Instagram
          _buildSocialField(
            controller: _instagramController,
            hint: 'Instagram username',
            icon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 12),

          // Facebook
          _buildSocialField(
            controller: _facebookController,
            hint: 'Facebook profile URL',
            icon: Icons.facebook,
          ),
          const SizedBox(height: 12),

          // Twitter/X
          _buildSocialFieldWithCustomIcon(
            controller: _twitterController,
            hint: 'Twitter/X handle',
            customIcon: Text(
              '𝕏',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // WhatsApp
          _buildSocialField(
            controller: _whatsappController,
            hint: 'WhatsApp number',
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ============ STEP 6: REVIEW ============
  Widget _buildStep6Review() {
    final config = _selectedCategory != null
        ? BusinessCategoryConfig.getConfig(_selectedCategory!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_back, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Review Details',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Final Review',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'Review your business profile',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please verify your information below.',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 32),

          // Business Identity Section
          _buildReviewSection(
            icon: Icons.business,
            title: 'Business Identity',
            onEdit: () => _goToStep(2),
            children: [
              _buildReviewRow('Name', _businessNameController.text),
              if (_legalNameController.text.isNotEmpty)
                _buildReviewRow('Description', _legalNameController.text),
            ],
          ),
          const SizedBox(height: 16),

          // Logo Preview Section
          _buildReviewSection(
            icon: Icons.image,
            title: 'Logo Preview',
            onEdit: () => _goToStep(2),
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _logoFile != null
                        ? DecorationImage(
                            image: FileImage(_logoFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _logoFile == null
                      ? Icon(Icons.store, size: 40, color: Colors.grey[400])
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type & Category Section
          _buildReviewSection(
            icon: Icons.category,
            title: 'Type & Category',
            onEdit: () => _goToStep(0),
            children: [
              if (config != null) _buildReviewRow('Type', config.displayName),
              if (_selectedSubType != null)
                _buildReviewRow('Category', _selectedSubType!),
            ],
          ),
          const SizedBox(height: 16),

          // Location Section
          _buildReviewSection(
            icon: Icons.location_on,
            title: 'Location',
            onEdit: () => _goToStep(3),
            children: [
              if (_streetController.text.isNotEmpty)
                _buildReviewRow('Address', _streetController.text),
              if (_cityController.text.isNotEmpty ||
                  _stateController.text.isNotEmpty)
                _buildReviewRow(
                  'City',
                  '${_cityController.text}, ${_stateController.text}',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact Section
          _buildReviewSection(
            icon: Icons.phone,
            title: 'Contact',
            onEdit: () => _goToStep(4),
            children: [
              if (_phoneController.text.isNotEmpty)
                _buildReviewRow(
                  'Phone',
                  '$_selectedCountryCode ${_phoneController.text}',
                ),
              if (_emailController.text.isNotEmpty)
                _buildReviewRow('Email', _emailController.text),
              if (_websiteController.text.isNotEmpty)
                _buildReviewRow('Website', _websiteController.text),
            ],
          ),
          const SizedBox(height: 24),

          // Terms acceptance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: (value) {
                  setState(() {
                    _acceptedTerms = value ?? false;
                  });
                },
                activeColor: _accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      text: 'I accept the ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      children: const [
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: _lightAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: _lightAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildReviewSection({
    required IconData icon,
    required String title,
    required VoidCallback onEdit,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: _lightAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.map_outlined, size: 40, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Text(
            'Search for an address to see the map',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    String? helperText,
    TextInputType? keyboardType,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[500], size: 20)
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text('Select', style: TextStyle(color: Colors.grey[400])),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneFieldWithCountryCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Business Phone',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Country code picker
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountryFlag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountryCode,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Phone number field
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '000 000 0000',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCountries = _countryCodes.where((country) {
              if (searchQuery.isEmpty) return true;
              return country['country']!.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  country['code']!.contains(searchQuery);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Select Country',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (value) {
                        setModalState(() {
                          searchQuery = value;
                        });
                      },
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search country...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Country list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, index) {
                        final country = filteredCountries[index];
                        final isSelected =
                            country['code'] == _selectedCountryCode &&
                            country['flag'] == _selectedCountryFlag;
                        return ListTile(
                          leading: Text(
                            country['flag']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            country['country']!,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: Text(
                            country['code']!,
                            style: TextStyle(
                              color: isSelected
                                  ? _accentColor
                                  : Colors.grey[600],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: _accentColor.withValues(
                            alpha: 0.1,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = country['code']!;
                              _selectedCountryFlag = country['flag']!;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[700], size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSocialFieldWithCustomIcon({
    required TextEditingController controller,
    required String hint,
    required Widget customIcon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: SizedBox(width: 48, child: Center(child: customIcon)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    bool canContinue;
    String nextButtonText;

    switch (_currentStep) {
      case 0:
        canContinue = _selectedCategory != null;
        nextButtonText = 'Next';
        break;
      case 1:
        canContinue = _selectedSubType != null;
        nextButtonText = 'Next';
        break;
      case 2:
        canContinue = _businessNameController.text.trim().isNotEmpty;
        nextButtonText = 'Next';
        break;
      case 3:
        canContinue = true;
        nextButtonText = 'Next';
        break;
      case 4:
        canContinue = _phoneController.text.trim().isNotEmpty;
        nextButtonText = 'Next';
        break;
      case 5:
        canContinue = true;
        nextButtonText = 'Complete Setup';
        break;
      default:
        canContinue = false;
        nextButtonText = 'Next';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),

          // Next button
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading || !canContinue ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: canContinue ? _accentColor : Colors.grey[300],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nextButtonText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: canContinue
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                        if (_currentStep < _totalSteps - 1) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: canContinue
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check,
                            size: 18,
                            color: canContinue
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
