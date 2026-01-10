import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/portfolio_item_model.dart';
import '../../services/professional_service.dart';
import '../home/main_navigation_screen.dart';

/// 3-step wizard for setting up a professional profile
class ProfessionalSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const ProfessionalSetupScreen({
    super.key,
    this.onComplete,
    this.onSkip,
  });

  @override
  ConsumerState<ProfessionalSetupScreen> createState() =>
      _ProfessionalSetupScreenState();
}

class _ProfessionalSetupScreenState
    extends ConsumerState<ProfessionalSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  int _currentStep = 0;
  bool _isLoading = false;

  // Form controllers
  final _businessNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _yearsExpController = TextEditingController();

  // Selected values
  String? _selectedCategory;
  List<String> _selectedSpecializations = [];
  String _selectedCurrency = 'USD';

  final ProfessionalService _professionalService = ProfessionalService();

  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _businessNameController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    _yearsExpController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Validate current step
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
          _showError('Please enter your business/professional name');
          return false;
        }
        if (_selectedCategory == null) {
          _showError('Please select your category');
          return false;
        }
        return true;
      case 1: // Specializations
        if (_selectedSpecializations.isEmpty) {
          _showError('Please select at least one specialization');
          return false;
        }
        return true;
      case 2: // Rates (optional)
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

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      final success = await _professionalService.updateProfessionalProfile(
        businessName: _businessNameController.text.trim(),
        category: _selectedCategory!,
        specializations: _selectedSpecializations,
        yearsOfExperience: int.tryParse(_yearsExpController.text),
        hourlyRate: double.tryParse(_hourlyRateController.text),
        currency: _selectedCurrency,
      );

      if (success) {
        HapticFeedback.heavyImpact();

        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          _navigateToMainScreen();
        }
      } else {
        _showError('Failed to save profile. Please try again.');
      }
    } catch (e) {
      debugPrint('Error saving professional profile: $e');
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
                  _buildSpecializationsPage(),
                  _buildRatesPage(),
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
                onPressed: _skipSetup,
                child: const Text(
                  'Skip',
                  style: TextStyle(
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

          // Title
          const Text(
            'Tell us about\nyour business',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'This information will be displayed on your professional profile.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Business/Professional Name
          _buildTextField(
            controller: _businessNameController,
            label: 'Business / Professional Name',
            hint: 'e.g., John\'s Design Studio',
            icon: Icons.business,
          ),

          const SizedBox(height: 20),

          // Category Dropdown
          _buildCategoryDropdown(),

          const SizedBox(height: 20),

          // Bio
          _buildTextField(
            controller: _bioController,
            label: 'Short Bio (Optional)',
            hint: 'Tell clients about yourself and your expertise...',
            icon: Icons.edit_note,
            maxLines: 4,
            maxLength: 300,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSpecializationsPage() {
    final availableSpecs = Specializations.getForCategory(_selectedCategory);
    final hasSpecs = availableSpecs.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'What do you\nspecialize in?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Select the services and skills you offer. This helps clients find you.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          if (hasSpecs) ...[
            // Specializations for selected category
            _buildSectionTitle('${_selectedCategory ?? "Your"} Specializations'),
            const SizedBox(height: 12),
            _buildSpecializationChips(availableSpecs),
            const SizedBox(height: 24),
          ],

          // Popular specializations
          _buildSectionTitle('Popular Skills'),
          const SizedBox(height: 12),
          _buildSpecializationChips(
            Specializations.popular.where((s) => !availableSpecs.contains(s)).toList(),
          ),

          const SizedBox(height: 24),

          // Selected count
          if (_selectedSpecializations.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF00D67D),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedSpecializations.length} specialization${_selectedSpecializations.length > 1 ? 's' : ''} selected',
                      style: const TextStyle(
                        color: Color(0xFF00D67D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRatesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Set your rates',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'This is optional. You can also set specific prices for each service later.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Hourly Rate
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Currency selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedCurrency = v);
                      }
                    },
                    dropdownColor: const Color(0xFF2D2D44),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                      DropdownMenuItem(value: 'EUR', child: Text('\u20ac EUR')),
                      DropdownMenuItem(value: 'GBP', child: Text('\u00a3 GBP')),
                      DropdownMenuItem(value: 'INR', child: Text('\u20b9 INR')),
                      DropdownMenuItem(value: 'CAD', child: Text('\$ CAD')),
                      DropdownMenuItem(value: 'AUD', child: Text('\$ AUD')),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Rate input
              Expanded(
                child: _buildTextField(
                  controller: _hourlyRateController,
                  label: 'Hourly Rate',
                  hint: '0.00',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Years of Experience
          _buildTextField(
            controller: _yearsExpController,
            label: 'Years of Experience',
            hint: 'e.g., 5',
            icon: Icons.work_history,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),

          const SizedBox(height: 32),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pro tip: You can add detailed services with specific pricing after setup.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What's next
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
                _buildFeatureItem(Icons.work, 'Add services with pricing'),
                _buildFeatureItem(Icons.photo_library, 'Build your portfolio'),
                _buildFeatureItem(Icons.message, 'Receive inquiries'),
                _buildFeatureItem(Icons.analytics, 'Track your performance'),
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      onChanged: (v) {
        setState(() {
          _selectedCategory = v;
          // Clear specializations when category changes
          _selectedSpecializations = [];
        });
      },
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category, color: Colors.white54),
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
      hint: const Text('Select your category', style: TextStyle(color: Colors.white38)),
      items: ProfessionalCategories.all.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSpecializationChips(List<String> specs) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: specs.map((spec) {
        final isSelected = _selectedSpecializations.contains(spec);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedSpecializations.remove(spec);
              } else {
                if (_selectedSpecializations.length < 10) {
                  _selectedSpecializations.add(spec);
                } else {
                  _showError('Maximum 10 specializations allowed');
                }
              }
            });
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF00D67D) : Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Color(0xFF00D67D),
                  ),
                ],
              ],
            ),
          ),
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
            _selectedCategory != null;
        buttonText = 'Continue';
        break;
      case 1:
        canContinue = _selectedSpecializations.isNotEmpty;
        buttonText = 'Continue';
        break;
      case 2:
        canContinue = true;
        buttonText = 'Complete Setup';
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
                      const Icon(Icons.rocket_launch, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
