import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/profile services/profile_service.dart';
import '../other widgets/glass_text_field.dart';

class EditProfileBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentProfile;
  final Function()? onProfileUpdated;

  const EditProfileBottomSheet({
    super.key,
    required this.currentProfile,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  Uint8List? _imageBytes;
  bool _hasUnsavedChanges = false;

  // Profile data
  List<String> _selectedInterests = [];
  List<String> _selectedConnectionTypes = [];
  List<String> _selectedActivities = [];

  // Initial values to track changes
  List<String> _initialInterests = [];
  List<String> _initialConnectionTypes = [];
  List<String> _initialActivities = [];

  // Expanded state
  bool _interestsExpanded = false;
  bool _connectionTypesExpanded = false;
  bool _activitiesExpanded = false;

  // Popular items (most commonly used)
  final List<String> _popularInterests = [
    'Fitness',
    'Travel',
    'Music',
    'Movies',
    'Food Photography',
    'Tech',
    'Business',
    'Cooking',
    'Reading',
    'Photography',
  ];

  final List<String> _popularConnectionTypes = [
    'Dating',
    'Friendship',
    'Networking',
    'Activity Partner',
    'Travel Buddy',
    'Workout Partner',
    'Career Advice',
    'Mentorship',
  ];

  final List<String> _popularActivities = [
    'Gym',
    'Running',
    'Tennis',
    'Badminton',
    'Yoga',
    'Swimming',
    'Cycling',
    'Hiking',
    'Basketball',
    'Football',
  ];

  // All available options
  final List<String> _availableInterests = [
    'Fitness',
    'Hiking',
    'Nutrition',
    'Wellness',
    'Running',
    'Tech',
    'Business',
    'Travel',
    'Music',
    'Movies',
    'Cooking',
    'Wine',
    'Food Photography',
    'Culture',
    'Design',
    'Art',
    'Photography',
    'Gaming',
    'Sports',
    'Reading',
    'Writing',
    'Dancing',
    'Yoga',
    'Meditation',
  ];

  final List<String> _connectionTypeOptions = [
    'Dating',
    'Friendship',
    'Casual Hangout',
    'Travel Buddy',
    'Nightlife Partner',
    'Networking',
    'Mentorship',
    'Business Partner',
    'Career Advice',
    'Collaboration',
    'Workout Partner',
    'Sports Partner',
    'Hobby Partner',
    'Event Companion',
    'Study Group',
    'Language Exchange',
    'Skill Sharing',
    'Book Club',
    'Learning Partner',
    'Creative Workshop',
    'Music Jam',
    'Art Collaboration',
    'Photography',
    'Content Creation',
    'Performance',
    'Roommate',
    'Pet Playdate',
    'Community Service',
    'Gaming',
    'Online Friends',
  ];

  final List<String> _activityOptions = [
    'Tennis',
    'Badminton',
    'Basketball',
    'Football',
    'Volleyball',
    'Golf',
    'Table Tennis',
    'Squash',
    'Running',
    'Gym',
    'Yoga',
    'Pilates',
    'CrossFit',
    'Cycling',
    'Swimming',
    'Dance',
    'Hiking',
    'Rock Climbing',
    'Camping',
    'Kayaking',
    'Surfing',
    'Mountain Biking',
    'Trail Running',
    'Photography',
    'Painting',
    'Music',
    'Writing',
    'Cooking',
    'Crafts',
    'Gaming',
  ];

  String? _getPhotoUrl() {
    try {
      final photoUrl = widget.currentProfile['photoUrl'];
      if (photoUrl is String && photoUrl.isNotEmpty) {
        return photoUrl;
      }
      final profileImageUrl = widget.currentProfile['profileImageUrl'];
      if (profileImageUrl is String && profileImageUrl.isNotEmpty) {
        return profileImageUrl;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    try {
      // Load text fields
      final name = widget.currentProfile['name'];
      if (name != null) _nameController.text = name.toString();

      final bio = widget.currentProfile['bio'];
      if (bio != null) _bioController.text = bio.toString();

      final location = widget.currentProfile['location'];
      if (location != null) _locationController.text = location.toString();

      // Load selections
      final interests = widget.currentProfile['interests'];
      if (interests is List) {
        _selectedInterests = interests.map((e) => e.toString()).toList();
        _initialInterests = List.from(_selectedInterests);
      }

      final connectionTypes = widget.currentProfile['connectionTypes'];
      if (connectionTypes is List) {
        _selectedConnectionTypes = connectionTypes
            .map((e) => e.toString())
            .toList();
        _initialConnectionTypes = List.from(_selectedConnectionTypes);
      }

      final activities = widget.currentProfile['activities'];
      if (activities is List) {
        _selectedActivities = activities.map((e) {
          if (e is String) return e;
          if (e is Map) return e['name']?.toString() ?? 'Unknown';
          return e.toString();
        }).toList();
        _initialActivities = List.from(_selectedActivities);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

  void _checkForChanges() {
    final hasChanges =
        !_listsEqual(_selectedInterests, _initialInterests) ||
        !_listsEqual(_selectedConnectionTypes, _initialConnectionTypes) ||
        !_listsEqual(_selectedActivities, _initialActivities) ||
        _imageBytes != null;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      // Upload photo if changed
      String? photoUrl = _getPhotoUrl();
      if (_imageBytes != null) {
        photoUrl = await _profileService.updateProfilePhoto(
          userId: userId,
          imageBytes: _imageBytes,
        );
      }

      // Update profile
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'interests': _selectedInterests,
        'connectionTypes': _selectedConnectionTypes,
        'activities': _selectedActivities,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(String item, List<String> selectedList) {
    HapticFeedback.lightImpact(); // Haptic feedback
    setState(() {
      if (selectedList.contains(item)) {
        selectedList.remove(item);
      } else {
        selectedList.add(item);
      }
      _checkForChanges();
    });
  }

  void _removeSelected(String item, List<String> selectedList) {
    HapticFeedback.lightImpact();
    setState(() {
      selectedList.remove(item);
      _checkForChanges();
    });
  }

  void _showAddCustomDialog(
    String title,
    List<String> targetList,
    List<String> existingOptions,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Custom $title'),
        content: GlassTextField(
          controller: controller,
          hintText: 'Enter custom $title',
          textCapitalization: TextCapitalization.words,
          borderRadius: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty && !targetList.contains(value)) {
                setState(() {
                  targetList.add(value);
                  if (!existingOptions.contains(value)) {
                    existingOptions.add(value);
                  }
                  _checkForChanges();
                });
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _onWillPop();
      },
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Photo
                      _buildProfilePhoto(),
                      const SizedBox(height: 24),

                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bio
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.edit,
                        hint: 'Tell us about yourself...',
                        maxLines: 3,
                        maxLength: 150,
                      ),
                      const SizedBox(height: 16),

                      // Location (Read-only, shows city only)
                      _buildLocationField(),
                      const SizedBox(height: 32),

                      // Interests Section
                      _buildSection(
                        title: 'Interests & Hobbies',
                        selectedItems: _selectedInterests,
                        popularItems: _popularInterests,
                        allItems: _availableInterests,
                        isExpanded: _interestsExpanded,
                        onExpandToggle: () {
                          setState(() {
                            _interestsExpanded = !_interestsExpanded;
                          });
                        },
                        onToggle: (item) =>
                            _toggleSelection(item, _selectedInterests),
                        onRemove: (item) =>
                            _removeSelected(item, _selectedInterests),
                        onAddCustom: () => _showAddCustomDialog(
                          'Interest',
                          _selectedInterests,
                          _availableInterests,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Connection Types Section
                      _buildSection(
                        title: 'Connection Types',
                        selectedItems: _selectedConnectionTypes,
                        popularItems: _popularConnectionTypes,
                        allItems: _connectionTypeOptions,
                        isExpanded: _connectionTypesExpanded,
                        onExpandToggle: () {
                          setState(() {
                            _connectionTypesExpanded =
                                !_connectionTypesExpanded;
                          });
                        },
                        onToggle: (item) =>
                            _toggleSelection(item, _selectedConnectionTypes),
                        onRemove: (item) =>
                            _removeSelected(item, _selectedConnectionTypes),
                        onAddCustom: () => _showAddCustomDialog(
                          'Connection Type',
                          _selectedConnectionTypes,
                          _connectionTypeOptions,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Activities Section
                      _buildSection(
                        title: 'Activities',
                        selectedItems: _selectedActivities,
                        popularItems: _popularActivities,
                        allItems: _activityOptions,
                        isExpanded: _activitiesExpanded,
                        onExpandToggle: () {
                          setState(() {
                            _activitiesExpanded = !_activitiesExpanded;
                          });
                        },
                        onToggle: (item) =>
                            _toggleSelection(item, _selectedActivities),
                        onRemove: (item) =>
                            _removeSelected(item, _selectedActivities),
                        onAddCustom: () => _showAddCustomDialog(
                          'Activity',
                          _selectedActivities,
                          _activityOptions,
                        ),
                      ),
                      const SizedBox(height: 100), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ),

            // Save Button (Sticky at bottom)
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Back button on left
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final canPop = await _onWillPop();
            if (canPop && mounted) {
              Navigator.pop(context);
            }
          },
        ),
        // Title
        const Expanded(
          child: Text(
            'Edit Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        // Unsaved badge and close button on right
        if (_hasUnsavedChanges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Unsaved',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final canPop = await _onWillPop();
            if (canPop && mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _imageBytes != null
                ? MemoryImage(_imageBytes!)
                : _getPhotoUrl() != null
                ? NetworkImage(_getPhotoUrl()!)
                : null,
            child: _getPhotoUrl() == null && _imageBytes == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _pickImage,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: (value) => _checkForChanges(),
    );
  }

  Widget _buildLocationField() {
    // Extract city from full address
    String displayLocation = _locationController.text;
    if (displayLocation.isNotEmpty) {
      // Try to extract city (assuming format: "Street, City - Zipcode, State")
      final parts = displayLocation.split(',');
      if (parts.length > 1) {
        // Take the second part which is usually the city
        displayLocation = parts[1].trim();
        // Remove zipcode if present
        displayLocation = displayLocation.split('-')[0].trim();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  displayLocation.isEmpty ? 'Not set' : displayLocation,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> selectedItems,
    required List<String> popularItems,
    required List<String> allItems,
    required bool isExpanded,
    required VoidCallback onExpandToggle,
    required Function(String) onToggle,
    required Function(String) onRemove,
    required VoidCallback onAddCustom,
  }) {
    // Remove already selected items from lists
    final filteredPopular = popularItems
        .where((item) => !selectedItems.contains(item))
        .toList();
    final filteredAll = allItems
        .where((item) => !selectedItems.contains(item))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Selected Items Section
        if (selectedItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF00D67D),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SELECTED (${selectedItems.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00D67D),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedItems.map((item) {
                    return _buildSelectedChip(item, () => onRemove(item));
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Popular Items Section
        if (filteredPopular.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.local_fire_department, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'POPULAR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filteredPopular.map((item) {
              final isSelected = selectedItems.contains(item);
              return _buildOptionChip(
                item,
                isSelected,
                () => onToggle(item),
                isPopular: true,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Show More Button / All Items
        if (!isExpanded) ...[
          TextButton.icon(
            onPressed: onExpandToggle,
            icon: const Icon(Icons.expand_more),
            label: const Text('Show More'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ALL OPTIONS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton.icon(
                onPressed: onExpandToggle,
                icon: const Icon(Icons.expand_less),
                label: const Text('Show Less'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filteredAll.map((item) {
              final isSelected = selectedItems.contains(item);
              return _buildOptionChip(item, isSelected, () => onToggle(item));
            }).toList(),
          ),
        ],

        // Add Custom Button (Icon only)
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onAddCustom,
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 40,
            color: Theme.of(context).primaryColor,
            tooltip: 'Add custom',
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedChip(String text, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00D67D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D67D).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    bool isPopular = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D)
              : isPopular
              ? const Color(0xFF4A5FE8).withValues(
                  alpha: 0.3,
                ) // Blue tint for popular
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : isPopular
                ? const Color(0xFF4A5FE8) // Blue border for popular
                : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, size: 18, color: Colors.white),
            if (isSelected) const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFF00D67D),
            disabledBackgroundColor: Colors.grey,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
