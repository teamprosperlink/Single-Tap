import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/location services/location_service.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../../services/data_fix_service.dart';

class ProfileWithHistoryScreen extends ConsumerStatefulWidget {
  const ProfileWithHistoryScreen({super.key});

  @override
  ConsumerState<ProfileWithHistoryScreen> createState() =>
      _ProfileWithHistoryScreenState();
}

class _ProfileWithHistoryScreenState
    extends ConsumerState<ProfileWithHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _searchHistory = [];
  List<String> _selectedInterests = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  bool _isLoading = true;
  bool _isLoadingPeople = false;
  String? _error;

  // Filter options
  bool _filterByExactLocation = false;
  bool _filterByInterests = false;

  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  // Profile data
  List<String> _selectedConnectionTypes = [];
  List<String> _selectedActivities = [];
  String _aboutMe = '';
  final TextEditingController _aboutMeController = TextEditingController();

  // Active status
  bool _showOnlineStatus = true;
  bool _isStatusLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupProfileListener(); // Listen for real-time profile updates

    // Use addPostFrameCallback to defer location update until after initial frame
    // This prevents blocking the UI during widget initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateLocationIfNeeded();
      }
    });
  }

  void _setupProfileListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Listen for real-time profile changes (like location updates from background service)
    // Use distinct() to prevent unnecessary rebuilds when data hasn't actually changed
    _profileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          if (snapshot.exists) {
            final userData = snapshot.data();

            // OPTIMIZATION: Only call setState if data actually changed
            // This prevents unnecessary rebuilds that cause frame drops
            final newCity = userData?['city'];
            final newLocation = userData?['location'];
            final newInterests = List<String>.from(
              userData?['interests'] ?? [],
            );

            final oldCity = _userProfile?['city'];
            final oldLocation = _userProfile?['location'];

            // Check if anything meaningful changed
            final cityChanged = newCity != oldCity;
            final locationChanged = newLocation != oldLocation;
            final interestsChanged = !_listEquals(
              newInterests,
              _selectedInterests,
            );

            if (cityChanged ||
                locationChanged ||
                interestsChanged ||
                _userProfile == null) {
              setState(() {
                _userProfile = userData;
                _selectedInterests = newInterests;
              });

              // Only log in debug mode
              // debugPrint('ProfileScreen: Profile updated - city=$newCity');
            }
          }
        });
  }

  // Helper to compare lists
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _aboutMeController.dispose();
    super.dispose();
  }

  Future<void> _updateLocationIfNeeded() async {
    try {
      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Check if user's location needs updating
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();

      // Check mounted again after async operation
      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data();

        // Update location if it's not set or if it says generic location
        if (data?['displayLocation'] == null ||
            data?['displayLocation'] == 'Location detected' ||
            data?['displayLocation'] == 'Location detected (Web)' ||
            (data?['city'] == null ||
                data?['city'] == 'Location not set' ||
                data?['city'] == '' ||
                data?['city'] == 'Location detected' ||
                data?['city'] == 'Location detected (Web)')) {
          // Update location SILENTLY in background without blocking UI
          // Run this as fire-and-forget to prevent blocking
          _locationService
              .updateUserLocation(silent: true)
              .then((success) {
                if (!mounted) return; // Check mounted before continuing

                if (success) {
                  // Short delay to let Firestore propagate, then reload
                  Future.delayed(const Duration(milliseconds: 500)).then((_) {
                    if (mounted) {
                      _loadUserData();
                    }
                  });
                }
              })
              .catchError((error) {
                debugPrint('ProfileScreen: Location update error: $error');
              });
        }
      } else {
        // Document doesn't exist, create it with location
        // Update location SILENTLY in background
        _locationService
            .updateUserLocation(silent: true)
            .then((success) {
              if (!mounted) return;

              if (success) {
                Future.delayed(const Duration(milliseconds: 500)).then((_) {
                  if (mounted) {
                    _loadUserData();
                  }
                });
              }
            })
            .catchError((error) {
              debugPrint('ProfileScreen: Location creation error: $error');
            });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error updating location: $e');
      // Don't crash the app, just log the error
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userProfile = userData;
          // Load user's saved interests
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
          // Load connection types, activities, and about me
          _selectedConnectionTypes = List<String>.from(
            userData?['connectionTypes'] ?? [],
          );
          _aboutMe = userData?['aboutMe'] ?? '';
          _aboutMeController.text = _aboutMe;
          // Load active status preference
          _showOnlineStatus = userData?['showOnlineStatus'] ?? true;

          // Load activities
          final activitiesData = userData?['activities'] as List<dynamic>?;
          if (activitiesData != null) {
            _selectedActivities = activitiesData.map((item) {
              // Extract only the activity name
              if (item is Map) {
                return item['name']?.toString() ?? '';
              } else if (item is String) {
                return item;
              } else {
                return item.toString();
              }
            }).toList();
          }
        });

        // Debug logging disabled for production
        // debugPrint('User profile loaded: city=${userData?['city']}, location=${userData?['location']}, interests=$_selectedInterests');

        // Always load nearby people (filters can be applied via filter dialog)
        _loadNearbyPeople();
      }

      // Load search history
      try {
        final intentsQuery = _firestore
            .collection('user_intents')
            .where('userId', isEqualTo: userId);

        final intents = await intentsQuery.limit(20).get();

        if (mounted) {
          setState(() {
            _searchHistory = intents.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();

            // Sort by createdAt if available
            _searchHistory.sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return (bTime as Timestamp).compareTo(aTime as Timestamp);
            });
          });
        }
      } catch (e) {
        debugPrint('Error loading search history: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading profile data';
          _isLoading = false;
        });
      }
    }
  }

  // Common interests for users to choose from
  final List<String> _availableInterests = [
    'Dating',
    'Friendship',
    'Business',
    'Roommate',
    'Job Seeker',
    'Hiring',
    'Selling',
    'Buying',
    'Lost & Found',
    'Events',
    'Sports',
    'Travel',
    'Food',
    'Music',
    'Movies',
    'Gaming',
    'Fitness',
    'Art',
    'Technology',
    'Photography',
    'Fashion',
  ];

  Future<void> _loadNearbyPeople() async {
    if (!mounted) return;

    // If interest filter is on but no interests selected, return early
    if (_filterByInterests && _selectedInterests.isEmpty) return;

    setState(() {
      _isLoadingPeople = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userCity = _userProfile?['city'];
      // userLocation available for future geo-filtering

      // Build query based on filters
      Query<Map<String, dynamic>> usersQuery = _firestore.collection('users');

      // Apply interest filter if enabled
      if (_filterByInterests && _selectedInterests.isNotEmpty) {
        usersQuery = usersQuery.where(
          'interests',
          arrayContainsAny: _selectedInterests,
        );
      }

      // Apply exact location filter if enabled
      if (_filterByExactLocation && userCity != null && userCity.isNotEmpty) {
        usersQuery = usersQuery.where('city', isEqualTo: userCity);
      }

      usersQuery = usersQuery.limit(50);
      final usersSnapshot = await usersQuery.get();

      List<Map<String, dynamic>> people = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.id == userId) continue; // Skip current user

        final userData = doc.data();
        final userInterests = List<String>.from(userData['interests'] ?? []);
        final otherUserCity = userData['city'];

        // Additional location check if filter is enabled (for cases where query didn't filter)
        if (_filterByExactLocation) {
          if (userCity != null && userCity.isNotEmpty) {
            if (otherUserCity == null || otherUserCity != userCity) {
              continue; // Skip if not in same city
            }
          }
        }

        // Calculate common interests
        List<String> commonInterests = [];
        double matchScore =
            1.0; // Default match score when interest filter is off

        if (_filterByInterests && _selectedInterests.isNotEmpty) {
          commonInterests = _selectedInterests
              .where((interest) => userInterests.contains(interest))
              .toList();

          // Skip if no common interests when filter is on
          if (commonInterests.isEmpty) continue;

          matchScore = commonInterests.length / _selectedInterests.length;
        } else {
          // When interest filter is off, show all their interests as "common"
          commonInterests = userInterests;
        }

        // Add user with match data
        people.add({
          'userId': doc.id,
          'userData': userData,
          'commonInterests': commonInterests,
          'matchScore': matchScore,
        });
      }

      // Sort by match score (highest first)
      people.sort(
        (a, b) =>
            (b['matchScore'] as double).compareTo(a['matchScore'] as double),
      );

      if (mounted) {
        setState(() {
          _nearbyPeople = people;
          _isLoadingPeople = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby people: $e');
      if (mounted) {
        setState(() {
          _isLoadingPeople = false;
        });
      }
    }
  }

  Future<void> _updateInterests() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'interests': _selectedInterests,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interests updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload nearby people
      _loadNearbyPeople();
    } catch (e) {
      debugPrint('Error updating interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update interests'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOnlineStatusPreference(bool value) async {
    setState(() {
      _isStatusLoading = true;
    });

    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'showOnlineStatus': value,
          'isOnline': value ? true : false,
        });
        if (mounted) {
          setState(() {
            _showOnlineStatus = value;
            _isStatusLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: value
                            ? [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.greenAccent.withValues(alpha: 0.15),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.orangeAccent.withValues(alpha: 0.15),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          value ? Icons.visibility : Icons.visibility_off,
                          color: value
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value
                                ? 'Your active status is now visible to others'
                                : 'Your active status is now hidden',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isStatusLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 🔧 TEMPORARY DEBUG METHOD - Remove after data is fixed
  Future<void> _runDataFix() async {
    if (!mounted) return;

    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Conversation Data'),
        content: const Text(
          'This will fix the isGroup field in all conversations to ensure:\n\n'
          '• Group call messages appear only in group chats\n'
          '• 1-on-1 call messages appear only in 1-on-1 chats\n\n'
          'This is a one-time fix and is safe to run.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Fix'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Fixing conversation data...'),
          ],
        ),
      ),
    );

    try {
      final dataFixService = DataFixService();
      final result = await dataFixService.fixConversationIsGroupField();

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show result
      if (result['success'] == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success!'),
              ],
            ),
            content: Text(
              'Fixed ${result['fixedConversations']} out of ${result['totalConversations']} conversations.\n\n'
              '${result['message']}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text('Failed to fix data:\n\n${result['error']}'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('  Error running data fix: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text('An error occurred:\n\n$e'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  //   TEMPORARY DEBUG METHOD - Cleanup broken conversations
  Future<void> _runCleanup() async {
    if (!mounted) return;

    // First run diagnostics to show what will be deleted
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Scanning conversations...'),
          ],
        ),
      ),
    );

    try {
      final dataFixService = DataFixService();
      final diagnostics = await dataFixService.diagnoseConversations();

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (diagnostics['error'] != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text('Failed to scan:\n\n${diagnostics['error']}'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final totalIssues = diagnostics['totalIssues'] ?? 0;

      if (totalIssues == 0) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('All Good!'),
              ],
            ),
            content: const Text('No broken conversations found.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show confirmation with details
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cleanup Broken Conversations'),
          content: Text(
            'Found $totalIssues broken conversation(s).\n\n'
            'These conversations have:\n'
            '• Wrong ID format\n'
            '• Mismatched isGroup field\n'
            '• Group messages in 1-on-1 chats\n\n'
            'Delete these broken conversations?\n\n'
            '⚠️ This cannot be undone!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      // Show deleting dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting broken conversations...'),
            ],
          ),
        ),
      );

      final result = await dataFixService.cleanupBrokenConversations();

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show result
      if (result['success'] == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success!'),
              ],
            ),
            content: Text(
              'Deleted ${result['deletedCount']} broken conversation(s).\n\n'
              'Please restart the app for changes to take effect.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text('Failed to cleanup:\n\n${result['error']}'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('  Error running cleanup: $e');

      if (!mounted) return;

      // Close any open dialogs
      Navigator.pop(context);

      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text('An error occurred:\n\n$e'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showInterestsDialog() {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedInterests);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Interests'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _availableInterests[index];
                    final isSelected = tempSelected.contains(interest);

                    return CheckboxListTile(
                      title: Text(interest),
                      value: isSelected,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(interest);
                          } else {
                            tempSelected.remove(interest);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests = tempSelected;
                    });
                    Navigator.pop(context);
                    _updateInterests();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Filter by Exact Location'),
                      subtitle: Text(
                        'Only show people in your exact city/area',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _filterByExactLocation,
                      onChanged: (value) {
                        setDialogState(() {
                          _filterByExactLocation = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Filter by Interests'),
                      subtitle: Text(
                        'Only show people with common interests',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _filterByInterests,
                      onChanged: (value) {
                        setDialogState(() {
                          _filterByInterests = value;
                        });
                      },
                    ),
                    // Show selected interests
                    if (_filterByInterests) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected Interests:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showInterestsDialog();
                                  },
                                  icon: Icon(
                                    _selectedInterests.isEmpty
                                        ? Icons.add
                                        : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _selectedInterests.isEmpty
                                        ? 'Select'
                                        : 'Change',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedInterests.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Select interests to find matching people',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _selectedInterests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // State is already updated from setDialogState
                    });
                    Navigator.pop(context);
                    // Reload nearby people with new filters
                    _loadNearbyPeople();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Available connection types
  final List<String> _availableConnectionTypes = [
    'Friendship',
    'Dating',
    'Professional Networking',
    'Activity Partner',
    'Event Companion',
  ];

  // Available activities
  final List<String> _availableActivities = [
    'Gym',
    'Hiking',
    'Coding',
    'Running',
    'Swimming',
    'Cycling',
    'Yoga',
    'Reading',
    'Photography',
    'Cooking',
    'Dancing',
    'Music',
    'Gaming',
    'Travel',
    'gaming',
  ];

  @override
  Widget build(BuildContext context) {
    // Theme state watched for reactivity
    ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image (same as Feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: kToolbarHeight + 60),
                          // Profile Header - Card with glassmorphism
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      // Profile Photo - Centered
                                      UserAvatar(
                                        profileImageUrl:
                                            _userProfile?['profileImageUrl'] ??
                                            _userProfile?['photoUrl'],
                                        radius: 60,
                                        fallbackText:
                                            _userProfile?['name'] ?? 'User',
                                      ),
                                      const SizedBox(height: 20),

                                      // Name - Centered
                                      Text(
                                        _userProfile?['name'] ?? 'Unknown User',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      const SizedBox(height: 8),

                                      // Email - Centered
                                      Text(
                                        _userProfile?['email'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      const SizedBox(height: 12),

                                      // Location - Centered
                                      GestureDetector(
                                        onTap: () async {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Updating location...',
                                              ),
                                            ),
                                          );
                                          try {
                                            final success =
                                                await _locationService
                                                    .updateUserLocation(
                                                      silent: false,
                                                    );
                                            if (!mounted) return;
                                            if (success) {
                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 500,
                                                ),
                                              );
                                              if (!mounted) return;
                                              _loadUserData();
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Location updated successfully',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } else {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not update location',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            debugPrint(
                                              'Error during manual location update: $e',
                                            );
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Location update failed',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _userProfile?['displayLocation'] ??
                                                    _userProfile?['city'] ??
                                                    _userProfile?['location'] ??
                                                    'Tap to set location',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Edit Profile Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ProfileEditScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Account Type Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final accountType =
                                        _userProfile?['accountType']
                                            ?.toString()
                                            .toLowerCase() ??
                                        'personal';
                                    final isBusiness =
                                        accountType == 'business';
                                    debugPrint(
                                      'Account Type from Firestore: ${_userProfile?['accountType']} -> isBusiness: $isBusiness',
                                    );
                                    return ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          isBusiness
                                              ? Icons.business
                                              : Icons.person,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      title: const Text(
                                        'Account Type',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          isBusiness ? 'Business' : 'Personal',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Settings Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Settings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Active Status Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _showOnlineStatus
                                          ? AppColors.iosGreen.withValues(
                                              alpha: 0.2,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _showOnlineStatus
                                          ? CupertinoIcons.circle_fill
                                          : CupertinoIcons.circle,
                                      color: _showOnlineStatus
                                          ? AppColors.iosGreen
                                          : Colors.white.withValues(alpha: 0.7),
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Active Status',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Transform.scale(
                                    scale: 0.9,
                                    child: CupertinoSwitch(
                                      value: _showOnlineStatus,
                                      onChanged: _isStatusLoading
                                          ? null
                                          : _updateOnlineStatusPreference,
                                      activeTrackColor: AppColors.iosGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 🔧 TEMPORARY DEBUG BUTTON - Fix Conversation Data
                          // TODO: Remove this button after running the fix once
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.withValues(alpha: 0.3),
                                  Colors.red.withValues(alpha: 0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.build_circle,
                                      color: Colors.orange,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    '🔧 Fix Conversation Data',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Run once to fix group/1-on-1 chat messages',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.play_arrow,
                                    color: Colors.orange.withValues(alpha: 0.9),
                                    size: 28,
                                  ),
                                  onTap: _runDataFix,
                                ),
                              ),
                            ),
                          ),

                          //   TEMPORARY DEBUG BUTTON - Cleanup Broken Conversations
                          // TODO: Remove this button after running the fix once
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.withValues(alpha: 0.3),
                                  Colors.purple.withValues(alpha: 0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_sweep,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    '  Cleanup Broken Chats',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Delete conversations with wrong structure',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.play_arrow,
                                    color: Colors.red.withValues(alpha: 0.9),
                                    size: 28,
                                  ),
                                  onTap: _runCleanup,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
