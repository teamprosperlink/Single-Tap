import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/location_services/location_service.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/config/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_edit_screen.dart';
import 'main_navigation_screen.dart';

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
  bool _isLoading = true;
  String? _error;

  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  // Profile data
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
          _aboutMe = userData?['aboutMe'] ?? '';
          _aboutMeController.text = _aboutMe;
          // Load active status preference
          _showOnlineStatus = userData?['showOnlineStatus'] ?? true;
        });

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
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(64, 64, 64, 1),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
              ),
              child: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    // Open drawer after returning
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
                    });
                  },
                ),
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
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(64, 64, 64, 1),
                  Color.fromRGBO(0, 0, 0, 1),
                ],
              ),
            ),
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

                          // Active Status Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
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
                                      : Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Active Status',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
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

                          // Edit Profile Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
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
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
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

                          // Account Type Card (non-interactive)
                          IgnorePointer(
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.white.withValues(alpha: 0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
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
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
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
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            'Account Type',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isBusiness ? 'Business' : 'Personal',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Invite Friends Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
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
                                  Icons.person_add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Invite Friends',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Share SingleTap with friends',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              onTap: () {
                                Share.share(
                                  'Check out SingleTap - the AI-powered matching app that connects you with the right people! Download now: https://supper.app',
                                  subject: 'Join me on SingleTap!',
                                );
                              },
                            ),
                          ),

                          // Settings Card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
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
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Settings',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
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
