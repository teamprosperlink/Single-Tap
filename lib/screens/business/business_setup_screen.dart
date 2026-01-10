import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../home/main_navigation_screen.dart';

/// Multi-step wizard for setting up or editing a business profile
class BusinessSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final BusinessModel? existingBusiness; // For editing mode

  const BusinessSetupScreen({
    super.key,
    this.onComplete,
    this.onSkip,
    this.existingBusiness,
  });

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basic Info
  final _businessNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedBusinessType;
  String? _selectedIndustry;
  File? _logoFile;

  // Step 2: Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _whatsappController = TextEditingController();

  // Step 3: Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Step 4: Hours (simplified - default hours)
  bool _useDefaultHours = true;

  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  static const int _totalSteps = 4;

  // Check if we're in editing mode
  bool get _isEditing => widget.existingBusiness != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Pre-populate fields if editing
    if (_isEditing) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final business = widget.existingBusiness!;

    // Basic Info
    _businessNameController.text = business.businessName;
    _legalNameController.text = business.legalName ?? '';
    _descriptionController.text = business.description ?? '';
    _selectedBusinessType = business.businessType;
    _selectedIndustry = business.industry;

    // Contact Info
    _phoneController.text = business.contact.phone ?? '';
    _emailController.text = business.contact.email ?? '';
    _websiteController.text = business.contact.website ?? '';
    _whatsappController.text = business.contact.whatsapp ?? '';

    // Address
    if (business.address != null) {
      _streetController.text = business.address!.street ?? '';
      _cityController.text = business.address!.city ?? '';
      _stateController.text = business.address!.state ?? '';
      _countryController.text = business.address!.country ?? '';
      _postalCodeController.text = business.address!.postalCode ?? '';
    }

    // Hours
    _useDefaultHours = business.hours != null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _businessNameController.dispose();
    _legalNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _whatsappController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (!_validateCurrentStep()) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Info
        if (_businessNameController.text.trim().isEmpty) {
          _showError('Please enter your business name');
          return false;
        }
        if (_selectedBusinessType == null) {
          _showError('Please select your business type');
          return false;
        }
        return true;
      case 1: // Contact
        if (_phoneController.text.trim().isEmpty &&
            _emailController.text.trim().isEmpty) {
          _showError('Please provide at least a phone or email');
          return false;
        }
        return true;
      case 2: // Address
        // Address is optional
        return true;
      case 3: // Hours
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

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      // Upload logo if selected
      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await _businessService.uploadLogo(_logoFile!);
      } else if (_isEditing) {
        // Keep existing logo if no new one selected
        logoUrl = widget.existingBusiness!.logo;
      }

      // Build contact
      final contact = BusinessContact(
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
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

      // Build address
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

      // Build business model
      final business = BusinessModel(
        id: _isEditing ? widget.existingBusiness!.id : '',
        userId: _isEditing ? widget.existingBusiness!.userId : '',
        businessName: _businessNameController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
        businessType: _selectedBusinessType!,
        industry: _selectedIndustry,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        logo: logoUrl,
        contact: contact,
        address: address,
        hours: _useDefaultHours ? BusinessHours.defaultHours() : null,
        // Preserve existing values when editing
        coverImage: _isEditing ? widget.existingBusiness!.coverImage : null,
        rating: _isEditing ? widget.existingBusiness!.rating : 0.0,
        reviewCount: _isEditing ? widget.existingBusiness!.reviewCount : 0,
        followerCount: _isEditing ? widget.existingBusiness!.followerCount : 0,
        isVerified: _isEditing ? widget.existingBusiness!.isVerified : false,
        isActive: _isEditing ? widget.existingBusiness!.isActive : true,
      );

      bool success;
      if (_isEditing) {
        // Update existing business
        success = await _businessService.updateBusiness(
          widget.existingBusiness!.id,
          business,
        );
      } else {
        // Create new business
        final businessId = await _businessService.createBusiness(business);
        success = businessId != null;
      }

      if (success) {
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Business updated successfully'
                  : 'Business created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (widget.onComplete != null) {
          widget.onComplete!();
        } else if (_isEditing) {
          // Go back to dashboard when editing
          if (mounted) Navigator.pop(context, true);
        } else {
          _navigateToMainScreen();
        }
      } else {
        _showError(_isEditing
            ? 'Failed to update business. Please try again.'
            : 'Failed to create business. Please try again.');
      }
    } catch (e) {
      debugPrint('Error saving business: $e');
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipSetup() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoPage(),
                  _buildContactPage(),
                  _buildAddressPage(),
                  _buildHoursPage(),
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                IconButton(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                )
              else
                const SizedBox(width: 48),
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: _isEditing ? () => Navigator.pop(context) : _skipSetup,
                child: Text(
                  _isEditing ? 'Cancel' : 'Skip',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_totalSteps, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index > 0 ? 4 : 0,
                    right: index < _totalSteps - 1 ? 4 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentStep >= index
                          ? const Color(0xFF00D67D)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          Text(
            _isEditing ? 'Edit your\nbusiness' : 'Tell us about\nyour business',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _isEditing
                ? 'Update your business profile information.'
                : 'This information will be displayed on your business profile.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Logo picker
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white24,
                        width: 2,
                      ),
                      image: _logoFile != null
                          ? DecorationImage(
                              image: FileImage(_logoFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _logoFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white54,
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Logo',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  if (_logoFile != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00D67D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Business Name
          _buildTextField(
            controller: _businessNameController,
            label: 'Business Name *',
            hint: 'e.g., Acme Corporation',
            icon: Icons.store,
          ),

          const SizedBox(height: 16),

          // Legal Name
          _buildTextField(
            controller: _legalNameController,
            label: 'Legal/Registered Name (Optional)',
            hint: 'If different from business name',
            icon: Icons.badge_outlined,
          ),

          const SizedBox(height: 16),

          // Business Type
          _buildDropdown(
            label: 'Business Type *',
            value: _selectedBusinessType,
            items: BusinessTypes.all,
            icon: Icons.category_outlined,
            onChanged: (v) {
              setState(() {
                _selectedBusinessType = v;
                _selectedIndustry = null;
              });
            },
          ),

          const SizedBox(height: 16),

          // Industry
          if (_selectedBusinessType != null &&
              Industries.getForType(_selectedBusinessType).isNotEmpty)
            _buildDropdown(
              label: 'Industry (Optional)',
              value: _selectedIndustry,
              items: Industries.getForType(_selectedBusinessType),
              icon: Icons.business_center_outlined,
              onChanged: (v) {
                setState(() {
                  _selectedIndustry = v;
                });
              },
            ),

          const SizedBox(height: 16),

          // Description
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Tell customers about your business...',
            icon: Icons.description_outlined,
            maxLines: 4,
            maxLength: 500,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Contact\ninformation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'How can customers reach you?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Phone
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+1 234 567 8900',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'business@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          // Website
          _buildTextField(
            controller: _websiteController,
            label: 'Website (Optional)',
            hint: 'https://www.example.com',
            icon: Icons.language_outlined,
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 16),

          // WhatsApp
          _buildTextField(
            controller: _whatsappController,
            label: 'WhatsApp (Optional)',
            hint: '+1 234 567 8900',
            icon: Icons.chat_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'At least one contact method is required so customers can reach you.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Business\nlocation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Where is your business located? (Optional)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Street
          _buildTextField(
            controller: _streetController,
            label: 'Street Address',
            hint: '123 Main Street',
            icon: Icons.location_on_outlined,
          ),

          const SizedBox(height: 16),

          // City & State row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'New York',
                  icon: Icons.location_city_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _stateController,
                  label: 'State',
                  hint: 'NY',
                  icon: Icons.map_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Country & Postal Code row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'USA',
                  icon: Icons.flag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _postalCodeController,
                  label: 'Postal Code',
                  hint: '10001',
                  icon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHoursPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Operating\nhours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'When is your business open? You can customize this later.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Default hours option
          GestureDetector(
            onTap: () {
              setState(() => _useDefaultHours = true);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _useDefaultHours
                    ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _useDefaultHours
                      ? const Color(0xFF00D67D)
                      : Colors.white24,
                  width: _useDefaultHours ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _useDefaultHours
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _useDefaultHours
                            ? const Color(0xFF00D67D)
                            : Colors.white54,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Use standard business hours',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mon-Fri: 9:00 AM - 6:00 PM\nSat: 10:00 AM - 4:00 PM\nSun: Closed',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Skip hours option
          GestureDetector(
            onTap: () {
              setState(() => _useDefaultHours = false);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: !_useDefaultHours
                    ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !_useDefaultHours
                      ? const Color(0xFF00D67D)
                      : Colors.white24,
                  width: !_useDefaultHours ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_useDefaultHours
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: !_useDefaultHours
                        ? const Color(0xFF00D67D)
                        : Colors.white54,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Set up hours later',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // What's next card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.15),
                  const Color(0xFF00D67D).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      color: Color(0xFF00D67D),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'After setup, you can:',
                      style: TextStyle(
                        color: Color(0xFF00D67D),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(Icons.inventory_2, 'Add products & services'),
                _buildFeatureItem(Icons.photo_library, 'Upload photos & gallery'),
                _buildFeatureItem(Icons.star, 'Collect customer reviews'),
                _buildFeatureItem(Icons.analytics, 'Track your performance'),
                _buildFeatureItem(Icons.share, 'Share on social media'),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D67D), width: 2),
        ),
        counterStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D67D), width: 2),
        ),
      ),
      dropdownColor: const Color(0xFF2D2D44),
      style: const TextStyle(color: Colors.white),
      hint: Text('Select $label', style: const TextStyle(color: Colors.white38)),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButtons() {
    bool canContinue;
    String buttonText;

    switch (_currentStep) {
      case 0:
        canContinue = _businessNameController.text.trim().isNotEmpty &&
            _selectedBusinessType != null;
        buttonText = 'Continue';
        break;
      case 1:
        canContinue = _phoneController.text.trim().isNotEmpty ||
            _emailController.text.trim().isNotEmpty;
        buttonText = 'Continue';
        break;
      case 2:
        canContinue = true;
        buttonText = 'Continue';
        break;
      case 3:
        canContinue = true;
        buttonText = _isEditing ? 'Update Business' : 'Create Business';
        break;
      default:
        canContinue = false;
        buttonText = 'Continue';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canContinue ? const Color(0xFF00D67D) : Colors.grey[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_currentStep == _totalSteps - 1) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.store, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
