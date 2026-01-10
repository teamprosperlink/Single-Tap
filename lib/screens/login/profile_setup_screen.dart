import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/other providers/app_providers.dart';
import '../home/main_navigation_screen.dart';
import '../../res/config/app_colors.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  int _currentStep = 0;
  bool _isLoading = false;

  // Selected items
  DateTime? _selectedBirthDate;
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];

  // Total number of steps
  static const int _totalSteps = 3;

  // Connection Types grouped
  final Map<String, List<Map<String, dynamic>>> _connectionTypeGroups = {
    'Social': [
      {'name': 'Dating', 'icon': Icons.favorite},
      {'name': 'Friendship', 'icon': Icons.people},
      {'name': 'Casual Hangout', 'icon': Icons.coffee},
      {'name': 'Travel Buddy', 'icon': Icons.flight},
      {'name': 'Nightlife Partner', 'icon': Icons.nightlife},
    ],
    'Professional': [
      {'name': 'Networking', 'icon': Icons.handshake},
      {'name': 'Mentorship', 'icon': Icons.school},
      {'name': 'Business Partner', 'icon': Icons.business},
      {'name': 'Career Advice', 'icon': Icons.work},
      {'name': 'Collaboration', 'icon': Icons.group_work},
    ],
    'Activities': [
      {'name': 'Workout Partner', 'icon': Icons.fitness_center},
      {'name': 'Sports Partner', 'icon': Icons.sports_tennis},
      {'name': 'Hobby Partner', 'icon': Icons.palette},
      {'name': 'Event Companion', 'icon': Icons.event},
      {'name': 'Study Group', 'icon': Icons.menu_book},
    ],
  };

  // Activities grouped
  final Map<String, List<Map<String, dynamic>>> _activityGroups = {
    'Sports': [
      {'name': 'Tennis', 'icon': Icons.sports_tennis},
      {'name': 'Badminton', 'icon': Icons.sports_tennis},
      {'name': 'Basketball', 'icon': Icons.sports_basketball},
      {'name': 'Football', 'icon': Icons.sports_soccer},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball},
      {'name': 'Golf', 'icon': Icons.sports_golf},
    ],
    'Fitness': [
      {'name': 'Gym', 'icon': Icons.fitness_center},
      {'name': 'Running', 'icon': Icons.directions_run},
      {'name': 'Yoga', 'icon': Icons.self_improvement},
      {'name': 'Cycling', 'icon': Icons.directions_bike},
      {'name': 'Swimming', 'icon': Icons.pool},
      {'name': 'Dance', 'icon': Icons.music_note},
    ],
    'Outdoor': [
      {'name': 'Hiking', 'icon': Icons.terrain},
      {'name': 'Rock Climbing', 'icon': Icons.landscape},
      {'name': 'Camping', 'icon': Icons.cabin},
      {'name': 'Kayaking', 'icon': Icons.kayaking},
      {'name': 'Surfing', 'icon': Icons.surfing},
    ],
    'Creative': [
      {'name': 'Photography', 'icon': Icons.camera_alt},
      {'name': 'Painting', 'icon': Icons.brush},
      {'name': 'Music', 'icon': Icons.music_note},
      {'name': 'Writing', 'icon': Icons.edit},
      {'name': 'Cooking', 'icon': Icons.restaurant},
      {'name': 'Gaming', 'icon': Icons.sports_esports},
    ],
  };

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
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
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

  Future<void> _saveAndContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _currentUserId;
      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'birthDate': _selectedBirthDate?.toIso8601String(),
          'connectionTypes': _selectedConnectionTypes,
          'activities': _selectedActivities,
          'profileSetupComplete': true,
        });
      }

      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _skipSetup() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashDark1,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBirthDatePage(),
                  _buildConnectionTypesPage(),
                  _buildActivitiesPage(),
                ],
              ),
            ),

            // Bottom buttons
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
          // Skip button
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

          // Progress bar
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
                          ? AppColors.success
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

  Widget _buildBirthDatePage() {
    final now = DateTime.now();
    const minAge = 18;
    const maxAge = 100;
    final maxDate = DateTime(now.year - minAge, now.month, now.day);
    final minDate = DateTime(now.year - maxAge, now.month, now.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Title
          const Text(
            'When were you\nborn?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'This helps us show you people in your preferred age range and personalize your experience.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 48),

          // Date selector
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedBirthDate ?? maxDate,
                firstDate: minDate,
                lastDate: maxDate,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.success,
                        onPrimary: Colors.white,
                        surface: Color(0xFF2D2D44),
                        onSurface: Colors.white,
                      ),
                      dialogTheme: const DialogThemeData(
                        backgroundColor: AppColors.splashDark1,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedBirthDate = picked;
                });
                HapticFeedback.selectionClick();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedBirthDate != null
                      ? AppColors.success
                      : Colors.white.withValues(alpha: 0.2),
                  width: _selectedBirthDate != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _selectedBirthDate != null
                        ? AppColors.success
                        : Colors.white54,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBirthDate != null
                              ? _formatDate(_selectedBirthDate!)
                              : 'Select your birth date',
                          style: TextStyle(
                            color: _selectedBirthDate != null
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 18,
                            fontWeight: _selectedBirthDate != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (_selectedBirthDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_calculateAge(_selectedBirthDate!)} years old',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your birth date is private. Only your age will be visible to others.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

  Widget _buildConnectionTypesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Title
          const Text(
            'What are you\nlooking for?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Select the types of connections you\'re interested in. You can always change this later.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Connection types grouped
          ..._connectionTypeGroups.entries.map((entry) {
            return _buildGroupSection(
              title: entry.key,
              items: entry.value,
              selectedItems: _selectedConnectionTypes,
              onToggle: (name) {
                setState(() {
                  if (_selectedConnectionTypes.contains(name)) {
                    _selectedConnectionTypes.remove(name);
                  } else {
                    _selectedConnectionTypes.add(name);
                  }
                });
                HapticFeedback.selectionClick();
              },
            );
          }),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActivitiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Title
          const Text(
            'What do you\nenjoy doing?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Select activities you\'d like to do with others. This helps us find better matches.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Activities grouped
          ..._activityGroups.entries.map((entry) {
            return _buildGroupSection(
              title: entry.key,
              items: entry.value,
              selectedItems: _selectedActivities,
              onToggle: (name) {
                setState(() {
                  if (_selectedActivities.contains(name)) {
                    _selectedActivities.remove(name);
                  } else {
                    _selectedActivities.add(name);
                  }
                });
                HapticFeedback.selectionClick();
              },
            );
          }),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildGroupSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required List<String> selectedItems,
    required Function(String) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final isSelected = selectedItems.contains(item['name']);
            return GestureDetector(
              onTap: () => onToggle(item['name']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.success.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.success
                        : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? AppColors.success
                          : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['name'],
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.success
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBottomButtons() {
    // Check if current step has valid selection
    bool hasSelections;
    String selectionText = '';

    switch (_currentStep) {
      case 0: // Birthdate
        hasSelections = _selectedBirthDate != null;
        if (hasSelections) {
          selectionText = '${_calculateAge(_selectedBirthDate!)} years old';
        }
        break;
      case 1: // Connection Types
        hasSelections = _selectedConnectionTypes.isNotEmpty;
        selectionText = '${_selectedConnectionTypes.length} selected';
        break;
      case 2: // Activities
        hasSelections = _selectedActivities.isNotEmpty;
        selectionText = '${_selectedActivities.length} selected';
        break;
      default:
        hasSelections = false;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.splashDark1,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selection count
          if (hasSelections)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectionText,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelections
                    ? AppColors.success
                    : Colors.grey[700],
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
                  : Text(
                      _currentStep == _totalSteps - 1 ? 'Get Started' : 'Continue',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
